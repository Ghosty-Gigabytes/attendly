ALTER TABLE accounts ALTER COLUMN email DROP NOT NULL;
CREATE TABLE ims_credentials (
 owner_id VARCHAR(36) PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
 student_id VARCHAR(40) NOT NULL UNIQUE,
 password_hash VARCHAR(255) NOT NULL,
 password_cipher TEXT,
 verified_at VARCHAR(40) NOT NULL
);
