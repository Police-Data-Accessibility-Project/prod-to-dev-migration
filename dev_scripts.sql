-- This script contains all scripts to update the schema in the Dev database

------------------------
-- TEST UPDATE
------------------------
CREATE TABLE test_table (
    id SERIAL PRIMARY KEY,     -- Serial ID that auto-increments
    name VARCHAR(255),         -- Example varchar field for names
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Timestamp of row creation
    is_active BOOLEAN DEFAULT TRUE  -- Example boolean field
);
