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

---------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 2024-05-07: Remove `UPDATED_AT` column from QUICK_SEARCH_QUERY_LOGS, per https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/270
---------------------------------------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE PUBLIC.QUICK_SEARCH_QUERY_LOGS
DROP COLUMN UPDATED_AT;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 2024-05-08: Create new requests table along with enums and triggers to enforce it, per https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/256
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create ENUM types for request_status and record_type
CREATE TYPE request_status AS ENUM (
    'Intake', 
    'Active', 
    'Complete', 
    'Request withdrawn', 
    'Waiting for scraper', 
    'Archived'
);

CREATE TYPE record_type AS ENUM (
    'Dispatch Recordings', 'Arrest Records', 'Citations', 'Incarceration Records',
    'Booking Reports', 'Budgets & Finances', 'Misc Police Activity', 'Geographic',
    'Crime Maps & Reports', 'Other', 'Annual & Monthly Reports', 'Resources',
    'Dispatch Logs', 'Sex Offender Registry', 'Officer Involved Shootings',
    'Daily Activity Logs', 'Crime Statistics', 'Records Request Info',
    'Policies & Contracts', 'Stops', 'Media Bulletins', 'Training & Hiring Info',
    'Personnel Records', 'Contact Info & Agency Meta', 'Incident Reports',
    'Calls for Service', 'Accident Reports', 'Use of Force Reports', 
    'Complaints & Misconduct', 'Vehicle Pursuits', 'Court Cases', 'Surveys',
    'Field Contacts', 'Wanted Persons', 'List of Data Sources'
);

-- Create the table
CREATE TABLE requests_v2 (
    id BIGSERIAL PRIMARY KEY,
    submission_notes TEXT NOT NULL,
    request_status request_status NOT NULL DEFAULT 'Intake',
    submitter_contact_info TEXT,
    submitter_user_id BIGINT REFERENCES users(id),
    agency_described_submitted TEXT,
    record_type record_type,
    archive_reason TEXT,
    date_created TIMESTAMP NOT NULL DEFAULT NOW(),
    date_status_last_changed TIMESTAMP NOT NULL DEFAULT NOW(),
    github_issue_url TEXT CHECK (github_issue_url IS NULL OR github_issue_url ~* '^https?://[^\s/$.?#].[^\s]*$')
);

-- Create a trigger to update Date_status_last_changed when Request_status changes
CREATE OR REPLACE FUNCTION update_status_change_date() RETURNS TRIGGER AS $$
BEGIN
    NEW.Date_status_last_changed = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER status_change
BEFORE UPDATE ON requests_v2
FOR EACH ROW
WHEN (OLD.request_status IS DISTINCT FROM NEW.request_status)
EXECUTE FUNCTION update_status_change_date();
