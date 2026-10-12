CREATE TABLE outbox_events (id UUID PRIMARY KEY, aggregate_id VARCHAR(255) NOT NULL, topic VARCHAR(255) NOT NULL, payload TEXT NOT NULL, created_at TIMESTAMP WITH TIME ZONE NOT NULL, published_at TIMESTAMP WITH TIME ZONE, attempts INTEGER NOT NULL DEFAULT 0);
CREATE INDEX outbox_pending ON outbox_events(published_at,created_at);
