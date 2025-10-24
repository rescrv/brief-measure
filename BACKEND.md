# Backend

Everything revolves around an API key, two SQL tables, and four HTTP routes (note the exponent) to
log the answers to a series of ten questions.  The answers are termed "observations" and are a
string of ten digits 1-4.

An API key is 256 bits.  Find a suitable representation.  Generate them by reading 256 bits of data
from /dev/urandom.

The SQL tables are (pseudo-code):

API_KEY {
    key: [u8; 32],
}

OBSERVATIONS {
    id: UUIDv7,
    key: [u8; 32],
    obs: [u8; 10],
}

POST /api/v1/keys to generate a new key
- Returns 201 Created on success.
- Ignores the body.
POST /api/v1/observations to generate a new observation
- Returns 201 Created on success.
- Attempting to create more than 2 observations in 24 hours shall return 429.
- Body example: {"uuidv7": "019a133c-d8c1-71f0-9745-bd9a39fd4e96", "observation": "1234123413"}
- Rejects any observation that doesn't match "^[1-4]{4}$".
- Uses `.iter().char().all(pred)` and `.len()` to validate the observation.
POST /api/v1/forget-me-now to erase all data associated with the api key.
- Deletes the authenticated API key from the API_KEY table and cascade-deletes from the OBSERVATIONS table.
GET /api/v1/observations to list the last N observations for limited N.
- Returns in the style of [{"uuidv7": "019a133c-d8c1-71f0-9745-bd9a39fd4e96", "observation": "1234123413"}, ...]
- Returns in descending timestamp order the last 90 observations by default.

# Technical Choices
- Rust
- crate: brief-measure
- axum
- tokio
- serde_json
- uuid
- sqlx
- put the migration under migrations/ and include a down path
- create three binaries: brief-measure-migrate-up and brief-measure-migrate-down to apply and un-apply migrations, and brief-measure-serve to serve the HTTP api against $DATABASE_URL
