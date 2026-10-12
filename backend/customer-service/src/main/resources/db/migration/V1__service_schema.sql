CREATE TABLE outbox_events (id UUID PRIMARY KEY, aggregate_id VARCHAR(255) NOT NULL, topic VARCHAR(255) NOT NULL, payload TEXT NOT NULL, created_at TIMESTAMP WITH TIME ZONE NOT NULL, published_at TIMESTAMP WITH TIME ZONE, attempts INTEGER NOT NULL DEFAULT 0);
CREATE INDEX outbox_pending ON outbox_events(published_at,created_at);
CREATE TABLE customers(id VARCHAR(255) PRIMARY KEY,name VARCHAR(255),status VARCHAR(255),segment VARCHAR(255),plan VARCHAR(255),channel VARCHAR(255),region VARCHAR(255),spend NUMERIC(19,2),new_customer BOOLEAN NOT NULL,excluded BOOLEAN NOT NULL,consent BOOLEAN NOT NULL,updated_at TIMESTAMPTZ);
CREATE INDEX customer_segment ON customers(segment);
