CREATE TABLE IF NOT EXISTS api_keys (
    key BYTEA PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS observations (
    id UUID PRIMARY KEY,
    key BYTEA NOT NULL REFERENCES api_keys(key) ON DELETE CASCADE,
    obs BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_observations_key_created_at ON observations (key, created_at DESC);
