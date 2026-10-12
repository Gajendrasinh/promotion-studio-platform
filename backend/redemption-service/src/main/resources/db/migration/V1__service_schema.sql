CREATE TABLE outbox_events (id UUID PRIMARY KEY, aggregate_id VARCHAR(255) NOT NULL, topic VARCHAR(255) NOT NULL, payload TEXT NOT NULL, created_at TIMESTAMP WITH TIME ZONE NOT NULL, published_at TIMESTAMP WITH TIME ZONE, attempts INTEGER NOT NULL DEFAULT 0);
CREATE INDEX outbox_pending ON outbox_events(published_at,created_at);
CREATE TABLE campaign_ledgers(promotion_id UUID PRIMARY KEY,redeemed BIGINT NOT NULL DEFAULT 0,spent NUMERIC(19,2) NOT NULL DEFAULT 0,CONSTRAINT capacity_nonnegative CHECK(redeemed>=0 AND spent>=0));
CREATE TABLE redemptions(id UUID PRIMARY KEY,promotion_id UUID NOT NULL REFERENCES campaign_ledgers(promotion_id),customer_id VARCHAR(255) NOT NULL,idempotency_key VARCHAR(128) NOT NULL,actor VARCHAR(255) NOT NULL,status VARCHAR(255) NOT NULL,discount_amount NUMERIC(19,2) NOT NULL,currency VARCHAR(3) NOT NULL,redeemed_at TIMESTAMPTZ NOT NULL,correlation_id VARCHAR(255),cancelled_at TIMESTAMPTZ,CONSTRAINT redemption_idempotency UNIQUE(actor,idempotency_key));
CREATE INDEX redemption_customer_promotion ON redemptions(customer_id,promotion_id,status);
CREATE INDEX redemption_date ON redemptions(redeemed_at);
