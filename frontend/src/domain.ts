export type Status='DRAFT'|'PENDING_APPROVAL'|'APPROVED'|'SCHEDULED'|'ACTIVE'|'PAUSED'|'EXPIRED'|'RETIRED';
export type Role='MANAGER'|'APPROVER'|'ANALYST'|'ADMIN';
export type Condition={op:'AND'|'OR'|'NOT'|'EQ'|'IN'|'GTE';field?:string;value?:string;children?:Condition[]};
export type Promotion={id:string;code:string;name:string;description:string;status:Status;discountType:'PERCENTAGE'|'FIXED'|'BENEFIT';discountValue:number;currency:string;startAt:string;endAt:string;budgetLimit:number;totalRedemptionLimit:number;perCustomerLimit:number;ruleVersionId:string;segment:string;channel:string;createdBy:string;approvedBy?:string;version:number;createdAt:string;history:{status:Status;at:string;actor:string}[]};
export type Customer={id:string;name:string;segment:string;plan:string;channel:string;region:string;spend:number;newCustomer:boolean;excluded:boolean;consent:boolean;status:string};
export type Redemption={id:string;promotionId:string;customerId:string;idempotencyKey:string;status:'REDEEMED'|'CANCELLED';discountAmount:number;currency:string;redeemedAt:string};
export type RuleVersion={id:string;name:string;version:number;expression:Condition;publishedAt:string;checksum:string};
export type Store={promotions:Promotion[];customers:Customer[];redemptions:Redemption[];rules:RuleVersion[]};
export const transitions:Record<Status,Status[]>={DRAFT:['PENDING_APPROVAL'],PENDING_APPROVAL:['APPROVED','DRAFT'],APPROVED:['SCHEDULED','ACTIVE'],SCHEDULED:['ACTIVE','RETIRED'],ACTIVE:['PAUSED','EXPIRED'],PAUSED:['ACTIVE','RETIRED'],EXPIRED:['RETIRED'],RETIRED:[]};
export function evaluate(rule:Condition,customer:Customer,depth=0):{eligible:boolean;reasons:string[]}{
 if(depth>8) throw new Error('Rules cannot exceed 8 nesting levels');
 if(['AND','OR','NOT'].includes(rule.op)){const children=rule.children??[];if(!children.length||children.length>20||(rule.op==='NOT'&&children.length!==1))throw new Error('Invalid condition group');const results=children.map(c=>evaluate(c,customer,depth+1));return {eligible:rule.op==='AND'?results.every(r=>r.eligible):rule.op==='OR'?results.some(r=>r.eligible):!results[0].eligible,reasons:results.flatMap(r=>r.reasons)}}
 const fields:Record<string,unknown>={segment:customer.segment,plan:customer.plan,channel:customer.channel,region:customer.region,spend:customer.spend,newCustomer:customer.newCustomer,excluded:customer.excluded};if(!rule.field||!(rule.field in fields))throw new Error('Unsupported customer attribute');const actual=fields[rule.field];const matched=rule.op==='EQ'?String(actual)===rule.value:rule.op==='IN'?String(rule.value).split(',').map(s=>s.trim()).includes(String(actual)):rule.field==='spend'&&Number(actual)>=Number(rule.value);return{eligible:matched,reasons:[`${matched?'Matched':'Failed'}: ${rule.field} ${rule.op.toLowerCase()} ${rule.value}`]};
}
export function discount(p:Promotion,spend:number){if(p.discountType==='BENEFIT')return 0;return Math.round(Math.min(spend,p.discountType==='PERCENTAGE'?spend*p.discountValue/100:p.discountValue)*100)/100}
export function canTransition(p:Promotion,next:Status,actor:string,role:Role,now=new Date()){
 if(!transitions[p.status].includes(next))throw new Error(`Cannot move from ${p.status} to ${next}`);
 if(next==='APPROVED'&&(!['APPROVER','ADMIN'].includes(role)||p.createdBy===actor))throw new Error('An independent approver must approve this campaign');
 if(next!=='APPROVED'&&!['MANAGER','ADMIN'].includes(role))throw new Error('Campaign manager permission required');
 if(next==='ACTIVE'&&(now<new Date(p.startAt)||now>=new Date(p.endAt)))throw new Error('Campaign is outside its validity window');
 if(next==='SCHEDULED'&&now>=new Date(p.startAt))throw new Error('Start date must be in the future to schedule');
}
