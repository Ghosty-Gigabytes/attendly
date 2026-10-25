CREATE TABLE accounts (
 id VARCHAR(36) PRIMARY KEY, email VARCHAR(254) NOT NULL UNIQUE,
 display_name VARCHAR(100) NOT NULL, password_hash VARCHAR(255),
 google_subject VARCHAR(255) UNIQUE, created_at VARCHAR(40) NOT NULL
);
CREATE TABLE attendance_snapshots (
 owner_id VARCHAR(36) PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
 student_id VARCHAR(40) NOT NULL UNIQUE, scope VARCHAR(160) NOT NULL,
 payload TEXT NOT NULL, fetched_at VARCHAR(40) NOT NULL
);
CREATE TABLE user_records (
 owner_id VARCHAR(36) NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 scope VARCHAR(160) NOT NULL, kind VARCHAR(20) NOT NULL, record_id VARCHAR(200) NOT NULL,
 revision BIGINT NOT NULL, deleted BOOLEAN NOT NULL, payload TEXT NOT NULL,
 PRIMARY KEY(owner_id, scope, kind, record_id)
);
CREATE TABLE mutations (
 owner_id VARCHAR(36) NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 mutation_id VARCHAR(36) NOT NULL, fingerprint VARCHAR(64) NOT NULL, response TEXT NOT NULL,
 PRIMARY KEY(owner_id, mutation_id)
);
