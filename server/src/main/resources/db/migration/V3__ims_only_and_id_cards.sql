ALTER TABLE accounts DROP COLUMN email;
ALTER TABLE accounts DROP COLUMN password_hash;
ALTER TABLE accounts DROP COLUMN google_subject;
CREATE TABLE id_card_snapshots (
 owner_id VARCHAR(36) PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
 cipher TEXT NOT NULL,
 fetched_at VARCHAR(40) NOT NULL
);
