#!/usr/bin/env python3
"""Real HTTP vertical-slice acceptance smoke; no mocks or fixed success responses."""
import json,urllib.request,uuid,datetime,os
base=os.environ.get('API_URL','http://127.0.0.1:8080/api/v1')
def call(path,body=None,role='MANAGER',key=None):
 headers={'Content-Type':'application/json','X-Demo-Role':role,'X-Correlation-ID':str(uuid.uuid4())}
 if key:headers['Idempotency-Key']=key
 request=urllib.request.Request(base+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method='GET' if body is None else 'POST')
 with urllib.request.urlopen(request,timeout=20) as response:return json.load(response)
rule=call('/rules',{'name':'Smoke postpaid','expression':{'op':'AND','children':[{'op':'EQ','field':'segment','value':'Postpaid'},{'op':'GTE','field':'spend','value':'40'}]}})
now=datetime.datetime.now(datetime.timezone.utc)
p=call('/promotions',{'code':'SMOKE_'+uuid.uuid4().hex[:8].upper(),'name':'Smoke campaign','description':'Synthetic postpaid offer acceptance workflow','discountType':'PERCENTAGE','discountValue':10,'currency':'SGD','startAt':(now-datetime.timedelta(minutes=5)).isoformat(),'endAt':(now+datetime.timedelta(days=1)).isoformat(),'totalRedemptionLimit':3,'perCustomerLimit':1,'budgetLimit':100,'ruleVersionId':rule['id'],'segment':'Postpaid','channel':'My Singtel'})
for action,role in [('submit','MANAGER'),('approve','APPROVER'),('activate','MANAGER')]:p=call('/promotions/'+p['id']+'/'+action,{'version':p['version']},role)
assert p['status']=='ACTIVE'
offers=call('/customers/C00002/eligible-promotions')
assert next(o for o in offers if o['promotion']['id']==p['id'])['eligible']
key=str(uuid.uuid4());payload={'promotionId':p['id'],'customerId':'C00002'}
r=call('/redemptions',payload,key=key);retry=call('/redemptions',payload,key=key)
assert r['id']==retry['id'] and r['status']=='REDEEMED'
assert str(r['discountAmount']) in ('4.3','4.30')
for _ in range(2):assert call('/redemptions/'+r['id']+'/cancel',{})['status']=='CANCELLED'
print('PASS: rule publication → draft → submit → independent approval → activation → eligibility → idempotent redemption → repeated cancellation')
