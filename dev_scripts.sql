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
-------------------------------
-- 2024-05-25: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/290
-------------------------------
ALTER TABLE quick_search_query_logs
DROP COLUMN datetime_of_request;
-------------------------------
-- 2024-07-02: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/345
-------------------------------
--Create typeahead_type enum for typeahead_suggestions
CREATE TYPE typeahead_type AS ENUM ('State', 'County', 'Locality');
--Create typeahead_suggestions materialized view
CREATE MATERIALIZED VIEW typeahead_suggestions AS
SELECT
    state_name AS display_name,
    'State'::typeahead_type AS type,
    state_name AS state,
    NULL AS county,
    NULL AS locality
FROM
    state_names
UNION ALL
SELECT DISTINCT
    counties.name AS display_name,
    'County'::typeahead_type AS type,
    state_names.state_name AS state,
    counties.name AS county,
    NULL AS locality
FROM
    counties
JOIN
    state_names ON counties.state_iso = state_names.state_iso
UNION ALL
SELECT DISTINCT
    agencies.municipality AS display_name,
    'Locality'::typeahead_type AS type,
    state_names.state_name AS state,
    counties.name AS county,
    agencies.municipality AS locality
FROM
    agencies
JOIN
    counties ON agencies.county_fips = counties.fips
JOIN
    state_names ON counties.state_iso = state_names.state_iso
WHERE 
    agencies.municipality is not NULL;
-- refresh_typeahead_suggestions() procedure for refreshing view
CREATE OR REPLACE PROCEDURE refresh_typeahead_suggestions()
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW typeahead_suggestions;
END;
$$;
-------------------------------
-- 2024-07-02: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/352
-------------------------------
-- Start a transaction
BEGIN;

-- Insert statements for categories and storing their IDs in variables
DO $$
DECLARE
    police_public_interactions_id INT;
    info_about_officers_id INT;
    info_about_agencies_id INT;
    agency_published_resources_id INT;
    jails_courts_specific_id INT;
BEGIN
    CREATE TABLE record_categories (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) UNIQUE NOT NULL,
        description TEXT
    );

    CREATE TABLE record_types (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) UNIQUE NOT NULL,
        category_id INT NOT NULL,
        description TEXT,
        FOREIGN KEY (category_id) REFERENCES record_categories(id)
    );


    INSERT INTO record_categories (name) VALUES ('Police & Public Interactions') RETURNING id INTO police_public_interactions_id;
    INSERT INTO record_categories (name) VALUES ('Info about Officers') RETURNING id INTO info_about_officers_id;
    INSERT INTO record_categories (name) VALUES ('Info about Agencies') RETURNING id INTO info_about_agencies_id;
    INSERT INTO record_categories (name) VALUES ('Agency-published Resources') RETURNING id INTO agency_published_resources_id;
    INSERT INTO record_categories (name) VALUES ('Jails & Courts') RETURNING id INTO jails_courts_specific_id;

    -- Insert statements for record_types using stored category IDs
    INSERT INTO record_types (name, category_id, description) VALUES
        ('Accident Reports', police_public_interactions_id, 'Records of vehicle accidents, sometimes published so that people involved in an accident can look up the police report.'),
        ('Arrest Records', police_public_interactions_id, 'Records of each arrest made in the agency''s jurisdiction.'),
        ('Calls for Service', police_public_interactions_id, 'Records of officers initiating activity or responding to requests for police response. Often called "Dispatch Logs" or "Incident Reports" when published.'),
        ('Car GPS', police_public_interactions_id, 'Records of police car location. Not generally posted online.'),
        ('Citations', police_public_interactions_id, 'Records of low-level criminal offenses where a police officer issued a citation instead of an arrest.'),
        ('Dispatch Logs', police_public_interactions_id, 'Records of calls or orders made by police dispatchers.'),
        ('Dispatch Recordings', police_public_interactions_id, 'Audio feeds and/or archives of municipal dispatch channels.'),
        ('Field Contacts', police_public_interactions_id, 'Reports of contact between police and civilians. May include uses of force, incidents, arrests, or contacts where nothing notable happened.'),
        ('Incident Reports', police_public_interactions_id, 'Reports made by police officers after responding to a call which may or may not be criminal in nature. Not generally posted online.'),
        ('Misc Police Activity', police_public_interactions_id, 'Records or descriptions of police activity not covered by other record types.'),
        ('Officer Involved Shootings', police_public_interactions_id, 'Case files of gun violence where a police officer was involved, typically as the shooter. Detailed, often containing references to records like Media Bulletins and Use of Force Reports.'),
        ('Stops', police_public_interactions_id, 'Records of pedestrian or traffic stops made by police.'),
        ('Surveys', police_public_interactions_id, 'Information captured from a sample of some population, like incarcerated people or magistrate judges. Often generated independently.'),
        ('Use of Force Reports', police_public_interactions_id, 'Records of use of force against civilians by police officers.'),
        ('Vehicle Pursuits', police_public_interactions_id, 'Records of cases where police pursued a person fleeing in a vehicle.'),
        ('Complaints & Misconduct', info_about_officers_id, 'Records, statistics, or summaries of complaints and misconduct investigations into law enforcement officers.'),
        ('Daily Activity Logs', info_about_officers_id, 'Officer-created reports or time sheets of what happened on a shift. Not generally posted online.'),
        ('Training & Hiring Info', info_about_officers_id, 'Records and descriptions of additional training for police officers.'),
        ('Personnel Records', info_about_officers_id, 'Records of hiring and firing, certification, discipline, and other officer-specific events. Not generally posted online.'),
        ('Annual & Monthly Reports', info_about_agencies_id, 'Often in PDF form, featuring summaries or high-level updates about the police force. Can contain versions of other record types, especially summaries.'),
        ('Budgets & Finances', info_about_agencies_id, 'Budgets, finances, grants, or other financial documents.'),
        ('Contact Info & Agency Meta', info_about_agencies_id, 'Information about organizational structure, including department structure and contact info.'),
        ('Geographic', info_about_agencies_id, 'Maps or geographic data about how land is divided up into municipal sectors, zones, and jurisdictions.'),
        ('List of Data Sources', info_about_agencies_id, 'Places on the internet, often data portal homepages, where many links to potential data sources can be found.'),
        ('Policies & Contracts', info_about_agencies_id, 'Policies or contracts related to agency procedure.'),
        ('Crime Maps & Reports', agency_published_resources_id, 'Records of individual crimes in map or table form for a given jurisdiction.'),
        ('Crime Statistics', agency_published_resources_id, 'Summarized information about crime in a given jurisdiction.'),
        ('Media Bulletins', agency_published_resources_id, 'Press releases, blotters, or blogs intended to broadly communicate alerts, requests, or other timely information.'),
        ('Records Request Info', agency_published_resources_id, 'Portals, forms, policies, or other resources for making public records requests.'),
        ('Resources', agency_published_resources_id, 'Agency-provided information or guidance about services, prices, best practices, etc.'),
        ('Sex Offender Registry', agency_published_resources_id, 'Index of people registered, usually by law, with the government as sex offenders.'),
        ('Wanted Persons', agency_published_resources_id, 'Names, descriptions, images, and associated information about people with outstanding arrest warrants.'),
        ('Booking Reports', jails_courts_specific_id, 'Records of booking or intake into corrections institutions.'),
        ('Court Cases', jails_courts_specific_id, 'Records such as dockets about individual court cases.'),
        ('Incarceration Records', jails_courts_specific_id, 'Records of current inmates, often with full names and features for notification upon inmate release.');

    -- Delete test rows from data_sources
    DELETE
    FROM data_sources ds
    WHERE ds.record_type = 'test';

    -- Add record_type_id to data_sources
    ALTER TABLE data_sources
    ADD COLUMN record_type_id INT;

    -- Update record_type_id to match record_types
    UPDATE data_sources ds
    SET record_type_id = rt.id
    FROM record_types rt
    WHERE ds.record_type = rt.name;

    -- Add foreign key constraint
    ALTER TABLE data_sources
    ADD CONSTRAINT fk_record_type
    FOREIGN KEY (record_type_id) REFERENCES record_types(id);

END $$;

-- Commit the transaction
COMMIT;
-------------------------------
-- 2024-07-22: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/309
-------------------------------
SET timezone TO 'EST';

-- Create new table for archive info
CREATE TABLE IF NOT EXISTS public.data_sources_archive_info
(
    airtable_uid character varying COLLATE pg_catalog."default" NOT NULL,
    update_frequency character varying COLLATE pg_catalog."default",
    last_cached date,
    next_cache timestamp,
    CONSTRAINT airtable_uid_pk PRIMARY KEY (airtable_uid),
    CONSTRAINT airtale_uid_fk FOREIGN KEY (airtable_uid)
        REFERENCES public.data_sources (airtable_uid) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
)

TABLESPACE pg_default;


ALTER TABLE IF EXISTS public.data_sources_archive_info
    OWNER to data_sources_app_dev;

-- Migrate data to the new table
INSERT INTO data_sources_archive_info (airtable_uid, update_frequency, last_cached)
SELECT airtable_uid, update_frequency, last_cached from data_sources;

-- Create a fuction to validate that the data migration was successful
CREATE OR REPLACE FUNCTION validate_data() RETURNS void AS $$
    DECLARE
        query_result RECORD;
    BEGIN
        -- Select any rows where the migrated data is mismatched
        SELECT
            data_sources.airtable_uid,
            data_sources_archive_info.airtable_uid,
            data_sources.update_frequency,
            data_sources_archive_info.update_frequency,
            data_sources.last_cached,
            data_sources_archive_info.last_cached
        INTO 	query_result
        FROM    data_sources
        FULL JOIN
                data_sources_archive_info
        ON      data_sources.airtable_uid = data_sources_archive_info.airtable_uid
        WHERE   data_sources.update_frequency IS DISTINCT FROM data_sources_archive_info.update_frequency
                OR data_sources.last_cached IS DISTINCT FROM data_sources_archive_info.last_cached
		LIMIT 1;

        -- If any rows are found, that means there is mismatched data. Raise an exception in this case
        IF FOUND THEN
            RAISE EXCEPTION 'Mismatched data found, data_sources id: %, data_sources_archive_info id: %', query_result.data_sources.airtable_uid, query_result.data_sources_archive_info.airtable_uid;
        end if;
    END
    $$ LANGUAGE plpgsql;


DO $$ BEGIN
    PERFORM "validate_data"();
END $$;


DROP FUNCTION IF EXISTS validate_data;


UPDATE data_sources_archive_info
SET last_cached = NULL
WHERE last_cached = '0001-01-01';


ALTER TABLE data_sources_archive_info
ALTER COLUMN last_cached
TYPE timestamp;

-- Create trigger to insert a linked row into the archive info table when a new row is added to data_sources
CREATE OR REPLACE FUNCTION insert_new_archive_info() RETURNS TRIGGER AS $$
BEGIN
   INSERT INTO data_sources_archive_info (airtable_uid)
   VALUES (NEW.airtable_uid);
   RETURN NEW;
END
$$ LANGUAGE plpgsql;


CREATE TRIGGER insert_new_archive_info_trigger
AFTER INSERT
ON data_sources
FOR EACH ROW
EXECUTE FUNCTION insert_new_archive_info();

-- Drop old data
ALTER TABLE data_sources
DROP COLUMN update_frequency,
DROP COLUMN last_cached;

-------------------------------
-- 2024-07-27: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/296
-------------------------------
CREATE TYPE account_type AS ENUM ('github');
-- It might seem silly to have an enum with only one value,
-- but this will make it easier for us if we want to expand the number of linked accounts in the future

CREATE TABLE external_accounts (
    row_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    account_type account_type NOT NULL,
    account_identifier VARCHAR(255) NOT NULL,
    linked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE (user_id, account_type)  -- Ensures a user can only have one account of each type
);

CREATE VIEW user_external_accounts AS
SELECT
    u.id,
    u.email,
    ea.account_type,
    ea.account_identifier,
    ea.linked_at
FROM
    users u
LEFT JOIN
    external_accounts ea ON u.id = ea.user_id;
-------------------------------
-- 2024-08-05: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/162
-------------------------------
CREATE TABLE Permissions (
    permission_id SERIAL PRIMARY KEY,
    permission_name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT
);

-- Add a comment to the Permissions table
COMMENT ON TABLE Permissions IS 'This table stores the permissions available in the system, defining various access roles and their descriptions.';
-- Add comments to individual columns in the Permissions table
COMMENT ON COLUMN Permissions.permission_id IS 'Primary key of the Permissions table, automatically generated';
COMMENT ON COLUMN Permissions.permission_name IS 'Unique name of the permission role';
COMMENT ON COLUMN Permissions.description IS 'Detailed description of what the permission allows';

INSERT INTO Permissions (permission_name, description) VALUES
('db_write', 'Child apps and human maintainers can use this'),
('read_all_user_info', 'Enables viewing of user data; for admin use only');

CREATE TABLE User_Permissions (
    user_id INT REFERENCES Users(id),
    permission_id INT REFERENCES Permissions(permission_id),
    PRIMARY KEY (user_id, permission_id)
);

-- Add a comment to the User_Permissions table
COMMENT ON TABLE User_Permissions IS 'This table links users to their assigned permissions, indicating which permissions each user has.';
-- Add comments to individual columns in the User_Permissions table
COMMENT ON COLUMN User_Permissions.user_id IS 'Foreign key referencing the Users table, indicating the user who has the permission.';
COMMENT ON COLUMN User_Permissions.permission_id IS 'Foreign key referencing the Permissions table, indicating the permission assigned to the user.';
