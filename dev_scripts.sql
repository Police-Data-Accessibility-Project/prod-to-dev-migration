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
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
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
-----------
-- 2024-08-08: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/386
-----------
BEGIN;

-- Insert statements for categories and storing their IDs in variables
DO $$
DECLARE
    other_id INT;
BEGIN
    INSERT INTO record_categories (name) VALUES ('Other') RETURNING id INTO other_id;

    -- Insert statements for record_types using stored category IDs
    INSERT INTO record_types (name, category_id, description) VALUES
        ('Other', other_id, 'Other record types not otherwise described.');

	UPDATE data_sources ds
    SET record_type_id = rt.id
    FROM record_types rt
    WHERE ds.record_type = rt.name;
END $$;

-- Commit the transaction
COMMIT;



-------------------------------
-- 2024-08-09: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/162
-------------------------------

CREATE OR REPLACE FUNCTION generate_api_key() RETURNS text AS $$
BEGIN
    RETURN gen_random_uuid();
END;
$$ LANGUAGE plpgsql;

ALTER TABLE public.users ALTER COLUMN api_key SET DEFAULT generate_api_key();

-- Add API keys to all users not currently with API keys
UPDATE users
SET api_key = generate_api_key()
WHERE api_key IS NULL;

--- Add permissions logic.
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

---
--ALTER TABLE public.users DROP COLUMN role;
DROP TABLE session_tokens;
DROP TABLE access_tokens;

-------------------------------
-- 2024-08-18: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/391
-------------------------------

CREATE TYPE relation_role AS ENUM ('STANDARD', 'OWNER', 'ADMIN');
CREATE TYPE access_permission AS ENUM ('READ', 'WRITE', 'NONE');

-- Create the RelationColumn table
CREATE TABLE relation_column (
    id SERIAL PRIMARY KEY, -- Autogenerated primary key
    relation TEXT NOT NULL, -- The relation in question
    associated_column TEXT NOT NULL,  -- A column of the relation

    CONSTRAINT unique_relation_column UNIQUE (relation, associated_column)
);

COMMENT ON TABLE relation_column IS 'Stores the relation and corresponding columns';
COMMENT ON COLUMN relation_column.id IS 'Primary key, autogenerated';
COMMENT ON COLUMN relation_column.relation IS 'The relation (table or view) name';
COMMENT ON COLUMN relation_column.associated_column IS 'The column within the specified relation';

CREATE TABLE column_permission (
    id SERIAL PRIMARY KEY, -- Autogenerated primary key
    rc_id INT NOT NULL REFERENCES relation_column(id) ON DELETE CASCADE, -- Foreign key to RelationColumn table
    relation_role relation_role NOT NULL, -- Role to which the permission applies
    access_permission access_permission NOT NULL, -- Access permission level

    CONSTRAINT unique_column_permission UNIQUE (rc_id, relation_role)
);

COMMENT ON TABLE column_permission IS 'Stores the permissions for columns in relations based on role';
COMMENT ON COLUMN column_permission.id IS 'Primary key, autogenerated';
COMMENT ON COLUMN column_permission.rc_id IS 'Foreign key referencing the RelationColumn table';
COMMENT ON COLUMN column_permission.relation_role IS 'The role to which the permission applies';
COMMENT ON COLUMN column_permission.access_permission IS 'The level of access permission (READ, WRITE)';

-------------------------------
-- 2024-08-21: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/355
-------------------------------
ALTER TYPE public.request_status ADD VALUE 'Ready to start';
ALTER TYPE public.request_status ADD VALUE 'Waiting for FOIA';
ALTER TYPE public.request_status ADD VALUE 'Waiting for requestor';

-- MODIFY REQUEST STATUS TO MATCH ENUM VALUES

UPDATE data_requests
SET request_status = 'Request withdrawn'
WHERE request_status = 'Withdrawn';

-- ADD COLUMNS
ALTER TABLE data_requests
ADD COLUMN creator_user_id BIGINT,
ADD COLUMN github_issue_url TEXT,
ADD COLUMN internal_notes TEXT,
ADD COLUMN record_types_required record_type[],
ADD COLUMN pdap_response TEXT,
ADD COLUMN coverage_range DATERANGE,
ADD COLUMN volunteers_can_contact_requestor BOOLEAN,
ADD COLUMN data_requirements TEXT;

-- REMOVE COLUMNS
ALTER TABLE data_requests
DROP COLUMN record_type;

-- RENAME COLUMNS
ALTER TABLE data_requests
RENAME COLUMN agency_described_submitted to location_described_submitted;

ALTER TABLE data_requests
RENAME COLUMN submitter_contact_info to submitter_email;

ALTER TABLE data_requests
RENAME COLUMN status_last_changed to date_status_last_changed;

-- ALTER COLUMNS
ALTER TABLE data_requests
ALTER COLUMN request_status SET NOT NULL;

ALTER TABLE data_requests
ALTER COLUMN request_status TYPE request_status USING request_status::request_status;

ALTER TABLE public.data_requests
ALTER COLUMN date_created TYPE timestamp with time zone;

ALTER TABLE public.data_requests
ALTER COLUMN date_status_last_changed TYPE timestamp with time zone;

ALTER TABLE data_requests
ALTER COLUMN request_status SET DEFAULT 'Intake'::request_status;

ALTER TABLE public.data_requests
ALTER COLUMN date_created SET DEFAULT NOW();

ALTER TABLE public.data_requests
ALTER COLUMN date_status_last_changed SET DEFAULT NOW();

-- ADD CONSTRAINTS
ALTER TABLE public.data_requests
ADD CONSTRAINT data_requests_github_issue_url_check CHECK (github_issue_url IS NULL OR github_issue_url ~* '^https?://[^\s/$.?#].[^\s]*$'::text);

ALTER TABLE public.data_requests
ADD CONSTRAINT data_requests_creator_user_id_fc FOREIGN KEY (creator_user_id) REFERENCES users (id);

-- ADD TRIGGER
CREATE OR REPLACE TRIGGER data_requests_status_change
    BEFORE UPDATE
    ON public.data_requests
    FOR EACH ROW
    WHEN (old.request_status IS DISTINCT FROM new.request_status)
    EXECUTE FUNCTION public.update_status_change_date();

-- ADD COMMENTS

COMMENT ON TABLE public.data_requests IS 'Stores information related to data requests, including submission details, status, and related metadata.';

COMMENT ON COLUMN public.data_requests.id IS 'Primary key, automatically generated as a unique identifier.';
COMMENT ON COLUMN public.data_requests.submission_notes IS 'Optional notes provided by the submitter during the request submission.';
COMMENT ON COLUMN public.data_requests.request_status IS 'The status of the request, using a custom enum type request_status, defaults to Intake.';
COMMENT ON COLUMN public.data_requests.submitter_email IS 'Email for the person who submitted the request.';
COMMENT ON COLUMN public.data_requests.location_described_submitted IS 'Description of the location relevant to the request, if applicable.';
COMMENT ON COLUMN public.data_requests.archive_reason IS 'Reason for archiving the request, if applicable.';
COMMENT ON COLUMN public.data_requests.date_created IS 'The date and time when the request was created.';
COMMENT ON COLUMN public.data_requests.date_status_last_changed IS 'The date and time when the status of the request was last changed.';
COMMENT ON COLUMN public.data_requests.coverage_range IS 'The date range covered by the request, if applicable.';
COMMENT ON COLUMN public.data_requests.data_requirements IS 'Detailed requirements for the data being requested.';
COMMENT ON COLUMN public.data_requests.record_types_required IS 'Multi-select of record types from record_types taxonomy.';
COMMENT ON COLUMN public.data_requests.github_issue_url IS 'URL for relevant Github Issue.';
COMMENT ON COLUMN public.data_requests.internal_notes IS 'Internal notes by PDAP staff about the request.';
COMMENT ON COLUMN public.data_requests.pdap_response IS 'Public notes by PDAP about the request.';
COMMENT ON COLUMN public.data_requests.volunteers_can_contact_requestor IS 'The requestor has given a member of staff permission to connect them with volunteers.';
COMMENT ON COLUMN public.data_requests.creator_user_id IS 'The user id of the creator of the data request.';

COMMENT ON TRIGGER data_requests_status_change ON public.data_requests IS 'Updates date_status_last_changed whenever request_status changes.';

COMMENT ON CONSTRAINT data_requests_github_issue_url_check ON public.data_requests IS 'Checks that github_issue_url column is in a recognizable URL format.';

COMMENT ON TYPE public.request_status IS '
Represents the different stages or statuses a request can have in the system:

- ''Intake'': The initial phase where the request is being gathered or evaluated.
- ''Active'': The request is currently being processed or worked on.
- ''Complete'': The request has been successfully completed and fulfilled.
- ''Request withdrawn'': The request has been withdrawn or canceled by the requester.
- ''Waiting for scraper'': The request is on hold, awaiting data collection by a web scraper.
- ''Archived'': The request has been archived, likely for long-term storage or future reference.
- ''Waiting for requestor'': The request is on hold, awaiting further information or action from the requester.
- ''Ready to Start'': The request is ready to be worked on.
- ''Waiting for FOIA'': The request is on hold, awaiting the results of a Freedom of Information Act request.
';


-------------------------------
-- 2024-08-22: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/411
-------------------------------
ALTER TABLE public.data_requests
DROP COLUMN volunteers_can_contact_requestor;

-- Correct bug in data requests sequence.
SELECT setval('data_requests_request_id_seq', (SELECT MAX(id) from "data_requests") + 1);

------------------
-- 2024-08-27: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/427
------------------
-- Drop the id column
ALTER TABLE public.state_names
DROP COLUMN id;

-- Set state_iso as the primary key
ALTER TABLE public.state_names
ADD PRIMARY KEY (state_iso);

------------------
-- 2024-08-28: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/417
------------------
CREATE OR REPLACE FUNCTION set_agency_name()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.submitted_name IS NOT NULL THEN
        IF NEW.state_iso IS NOT NULL THEN
            NEW.name := NEW.submitted_name || ' - ' || NEW.state_iso;
        ELSE
            NEW.name := NEW.submitted_name;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_agency_name
BEFORE INSERT OR UPDATE ON public.Agencies
FOR EACH ROW
EXECUTE FUNCTION set_agency_name();

COMMENT ON TRIGGER trigger_set_agency_name ON public.Agencies IS 'Calls `set_agency_name()` on inserts or updates to an Agency Row';

COMMENT ON FUNCTION set_agency_name IS 'Updates `name` based on contents of `submitted_name` and `state_iso`';


--------------------
-- 2024-08-31: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/429
--------------------
CREATE OR REPLACE VIEW relation_column_permission_view
 AS
 SELECT rc.relation,
    rc.associated_column,
    cp.relation_role,
    cp.access_permission
   FROM relation_column rc
     LEFT JOIN column_permission cp ON cp.rc_id = rc.id;


COMMENT ON VIEW relation_column_permission_view is 'A combined view of the non-id columns in `relation_column` and `column_permission` tables';

-- Drop previous test table

DROP TABLE public.test_table;

-- Create new test table
CREATE TABLE IF NOT EXISTS public.test_table
(
    id bigint NOT NULL GENERATED BY DEFAULT AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
    pet_name character varying(255),
	species character varying(255),
    CONSTRAINT test_table_pkey PRIMARY KEY (id)
);

COMMENT ON TABLE public.test_table is 'A test table for testing various database queries.';

-- Modify agency_source_link foreign keys to cascade on update and delete (i.e., when the parent row is updated or deleted, the child row is also updated or deleted)
ALTER TABLE agency_source_link
DROP CONSTRAINT agency_source_link_agency_described_linked_uid_fkey;

ALTER TABLE agency_source_link
DROP CONSTRAINT agency_source_link_airtable_uid_fkey;

ALTER TABLE agency_source_link
ADD CONSTRAINT agency_source_link_agency_described_linked_uid_fkey FOREIGN KEY (agency_described_linked_uid)
        REFERENCES public.agencies (airtable_uid) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

ALTER TABLE agency_source_link
ADD CONSTRAINT agency_source_link_airtable_uid_fkey FOREIGN KEY (airtable_uid)
        REFERENCES public.data_sources (airtable_uid) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

-------------------------
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/432
-------------------------
CREATE TABLE IF NOT EXISTS public.link_data_sources_data_requests
(
	id SERIAL PRIMARY KEY,
    source_id TEXT NOT NULL,
    request_id INT NOT NULL,
    FOREIGN KEY (source_id) REFERENCES data_sources(airtable_uid) ON DELETE CASCADE,
    FOREIGN KEY (request_id) REFERENCES data_requests(id) ON DELETE CASCADE,
    CONSTRAINT unique_source_request UNIQUE (source_id, request_id)
);

COMMENT ON TABLE link_data_sources_data_requests IS
'A link table associating data sources with related data requests.';

COMMENT ON COLUMN link_data_sources_data_requests.id IS 'Primary key, auto-incrementing';
COMMENT ON COLUMN link_data_sources_data_requests.source_id IS 'Foreign key referencing data_sources';
COMMENT ON COLUMN link_data_sources_data_requests.request_id IS 'Foreign key referencing data_requests';
-------------------------
--https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/433
-------------------------

-- Rename Materialized view and associated methods.
ALTER MATERIALIZED VIEW typeahead_suggestions RENAME TO typeahead_locations;

CREATE OR REPLACE PROCEDURE refresh_typeahead_locations()
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW typeahead_locations;
END;
$$;

DROP PROCEDURE IF EXISTS refresh_typeahead_suggestions();

-- Create new `typeahead_agencies` materialized view.
CREATE MATERIALIZED VIEW IF NOT EXISTS public.typeahead_agencies
TABLESPACE pg_default
AS
	SELECT
	    a.ID,
		a.NAME,
		a.JURISDICTION_TYPE,
		a.STATE_ISO, -- State
		a.MUNICIPALITY,
		c.name county_name
	FROM
		AGENCIES a
	JOIN counties c ON a.county_fips::text = c.fips::text;

CREATE OR REPLACE PROCEDURE refresh_typeahead_agencies()
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW typeahead_agencies;
END;
$$;
-------------------------
--https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/434
-------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS public.distinct_source_urls
TABLESPACE pg_default
AS
	SELECT DISTINCT
		-- Remove trailing '/'
		RTRIM(
			-- Remove beginning https://, http://, and www.
			LTRIM(
				LTRIM(
					LTRIM(SOURCE_URL, 'https://'),
				'http://'
				),
			'www.'
			),
		'/'
		) base_url,
		source_url original_url,
		rejection_note,
		approval_status
	FROM data_sources
	WHERE
		source_url is not NULL;

CREATE OR REPLACE PROCEDURE refresh_distinct_source_urls()
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW distinct_source_urls;
END;
$$;

COMMENT ON MATERIALIZED VIEW public.distinct_source_urls IS 'A materialized view of distinct source URLs.';

------------------------------------------------------------
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/448
------------------------------------------------------------
-- Rename `typeahead_type`
ALTER TYPE typeahead_type RENAME TO location_type;

-- Rename `state_names` to `us_states`
ALTER TABLE state_names RENAME TO us_states;

-- Add ID keys
ALTER TABLE public.us_states ADD COLUMN id BIGINT GENERATED ALWAYS AS IDENTITY;

ALTER TABLE public.counties ADD COLUMN id BIGINT GENERATED ALWAYS AS IDENTITY;

-- Add new foreign key to counties referencing us_states
ALTER TABLE public.counties ADD COLUMN state_id INT;
ALTER TABLE counties ADD UNIQUE(fips, state_id);

-- Populate new foreign key
UPDATE COUNTIES
SET state_id = (
	SELECT id from us_states
	WHERE us_states.state_iso = counties.state_iso
);

-- Drop dependent constraints in other tables to prevent foreign key errors
ALTER TABLE public.agencies DROP CONSTRAINT agencies_county_fips_fkey;

-- Drop previous primary key constraint
ALTER TABLE public.us_states DROP CONSTRAINT state_names_pkey;
ALTER TABLE public.counties DROP CONSTRAINT counties_pkey;

-- Add unique constraint to former primary key
ALTER TABLE public.us_states ADD CONSTRAINT unique_state_iso UNIQUE (state_iso);
ALTER TABLE public.counties ADD CONSTRAINT unique_fips UNIQUE (fips);

-- Add new primary key constraint for id
ALTER TABLE public.us_states ADD PRIMARY KEY (id);
ALTER TABLE public.counties ADD PRIMARY KEY (id);
ALTER TABLE public.counties ADD FOREIGN KEY (state_id) REFERENCES public.us_states (id);

-- Create `localities` table
CREATE TABLE localities (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    county_id INT NOT NULL,
    FOREIGN KEY (county_id) REFERENCES counties (id),
    UNIQUE(name, county_id)
);


-- Add comments to the `localities` table and columns
COMMENT ON TABLE localities IS 'Table containing information about localities including name, state, and county.';
COMMENT ON COLUMN localities.id IS 'Primary key for the locality table.';
COMMENT ON COLUMN localities.name IS 'Name of the locality (e.g., city, town, etc.).';
COMMENT ON COLUMN localities.county_id IS 'ID of the county to which the locality belongs.';

-- Populate `locality` with results from `agencies`
INSERT INTO localities (name, county_id)
SELECT DISTINCT
    a.MUNICIPALITY,
    c.id
FROM
    PUBLIC.AGENCIES a
    JOIN PUBLIC.COUNTIES c ON a.COUNTY_FIPS = c.FIPS
WHERE MUNICIPALITY IS NOT NULL;



-- Create locations tables
CREATE TABLE locations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type location_type NOT NULL,
    state_id BIGINT references us_states(id) ON DELETE CASCADE NOT NULL,
    county_id BIGINT references counties(id) ON DELETE CASCADE,
    locality_id BIGINT references localities(id) ON DELETE CASCADE,

    -- Ensure that county_id and locality_id values match the type
    CHECK (
        (type = 'State' AND county_id IS NULL AND locality_id IS NULL) OR
        (type = 'County' AND county_id IS NOT NULL AND locality_id IS NULL) OR
        (type = 'Locality' AND county_id IS NOT NULL AND locality_id IS NOT NULL)
    ),

    UNIQUE (id, type, state_id, county_id, locality_id)
);

COMMENT ON TABLE locations IS 'Base table for storing common information for all location types.';
COMMENT ON COLUMN locations.id IS 'Unique identifier for each location.';
COMMENT ON COLUMN locations.type IS 'Specifies the type of location (e.g., state, county, locality).';
COMMENT ON COLUMN locations.state_id IS 'Foreign key to `us_states` table';
COMMENT ON COLUMN locations.county_id IS 'Foreign key to `counties` table, if applicable';
COMMENT ON COLUMN locations.locality_id IS 'Foreign key to `localities` table, if applicable';


-- Insert us state locations
INSERT INTO locations (type, state_id)
SELECT 'State'::location_type, id
FROM us_states;

-- Insert counties
INSERT INTO locations(type, state_id, county_id)
SELECT 'County'::location_type, state_id, id
FROM counties
WHERE state_id is not null;

-- Insert localities
INSERT INTO locations(type, state_id, county_id, locality_id)
SELECT 'Locality'::location_type, c.state_id, l.county_id, l.id
FROM localities l
INNER JOIN counties c on l.county_id = c.id
where l.county_id is not null
and c.state_id is not null;

-- Add triggers so that when new state, county, or locality is added,
    -- a new locations entry is added for it.

CREATE OR REPLACE FUNCTION insert_state_location() RETURNS TRIGGER AS $$
BEGIN
    -- Insert a new location of type 'State' when a new state is added
    INSERT INTO locations (type, state_id)
    VALUES ('State', NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_state_insert
AFTER INSERT ON us_states
FOR EACH ROW
EXECUTE FUNCTION insert_state_location();

CREATE OR REPLACE FUNCTION insert_county_location() RETURNS TRIGGER AS $$
BEGIN
    -- Insert a new location of type 'County' when a new county is added
    INSERT INTO locations (type, state_id, county_id)
    VALUES ('County', NEW.state_id, NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_county_insert
AFTER INSERT ON counties
FOR EACH ROW
EXECUTE FUNCTION insert_county_location();

CREATE OR REPLACE FUNCTION insert_locality_location() RETURNS TRIGGER AS $$
DECLARE
    v_state_id BIGINT;
BEGIN
    -- Get the state_id from the associated county
    SELECT c.state_id INTO v_state_id
    FROM counties c
    WHERE c.id = NEW.county_id;

    -- Insert a new location of type 'Locality' when a new locality is added
    INSERT INTO locations (type, state_id, county_id, locality_id)
    VALUES ('Locality', v_state_id, NEW.county_id, NEW.id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_locality_insert
AFTER INSERT ON localities
FOR EACH ROW
EXECUTE FUNCTION insert_locality_location();

COMMENT ON TRIGGER after_state_insert ON us_states IS 'Inserts a new location of type "State" when a new state is added';
COMMENT ON TRIGGER after_county_insert ON counties IS 'Inserts a new location of type "County" when a new county is added';
COMMENT ON TRIGGER after_locality_insert ON localities IS 'Inserts a new location of type "Locality" when a new locality is added';

-- Add `location_id` column to `agencies` table as a foreign key
ALTER TABLE agencies ADD COLUMN location_id BIGINT REFERENCES locations(id);

-- Update Data

-- Here, I'm doing this piecemeal, adding columns which I will later remove,
-- just to simplify the process computationally and remove room for error
ALTER TABLE AGENCIES ADD COLUMN state_id BIGINT REFERENCES US_STATES(ID);
ALTER TABLE AGENCIES ADD COLUMN county_id BIGINT REFERENCES COUNTIES(ID);
ALTER TABLE AGENCIES ADD COLUMN locality_id BIGINT REFERENCES LOCALITIES(ID);

UPDATE AGENCIES
SET STATE_ID = US.ID
FROM US_STATES US
WHERE AGENCIES.STATE_ISO = US.STATE_ISO;

UPDATE AGENCIES
SET COUNTY_ID = C.ID
FROM COUNTIES C
WHERE AGENCIES.COUNTY_FIPS = C.FIPS;

UPDATE AGENCIES
SET LOCALITY_ID = L.ID
FROM LOCALITIES L
WHERE AGENCIES.MUNICIPALITY = L.NAME
AND AGENCIES.COUNTY_ID = L.COUNTY_ID;

-- Localities
UPDATE AGENCIES
SET
	LOCATION_ID = LOC.ID
FROM
	LOCATIONS LOC
WHERE
	AGENCIES.STATE_ID = LOC.STATE_ID
	AND AGENCIES.COUNTY_ID = LOC.COUNTY_ID
	AND AGENCIES.LOCALITY_ID = LOC.LOCALITY_ID;

-- Counties
UPDATE AGENCIES
SET
	LOCATION_ID = LOC.ID
FROM
	LOCATIONS LOC
WHERE
	AGENCIES.STATE_ID = LOC.STATE_ID
	AND AGENCIES.COUNTY_ID = LOC.COUNTY_ID
	AND AGENCIES.LOCALITY_ID is NULL AND LOC.LOCALITY_ID is NULL;

-- STATES
UPDATE AGENCIES
SET
	LOCATION_ID = LOC.ID
FROM
	LOCATIONS LOC
WHERE
	AGENCIES.STATE_ID = LOC.STATE_ID
	AND AGENCIES.COUNTY_ID is NULL AND LOC.COUNTY_ID is NULL
	AND AGENCIES.LOCALITY_ID is NULL AND LOC.LOCALITY_ID is NULL;

-- Set agencies which do not have valid/county_fips state_iso combinations to their state,
-- unapprove them, and indicate that their state and county information do not match
-- UPDATE AGENCIES
-- SET
-- 	LOCATION_ID = LOC.ID,
-- 	APPROVED = FALSE,
-- 	REJECTION_REASON = 'State and County Information Do Not Match'
-- FROM
-- 	LOCATIONS LOC
-- WHERE
-- 	AGENCIES.STATE_ID = LOC.STATE_ID
-- 	AND AGENCIES.LOCATION_ID IS NULL
-- 	AND COUNTY_FIPS IS NOT NULL
-- 	AND STATE_ISO IS NOT NULL;


ALTER TABLE AGENCIES DROP COLUMN state_id;
ALTER TABLE AGENCIES DROP COLUMN county_id;
ALTER TABLE AGENCIES DROP COLUMN locality_id;


-- Create Jurisdiction_type Enum
CREATE TYPE PUBLIC.JURISDICTION_TYPE AS ENUM(
	'school',
	'county',
	'local',
	'port',
	'tribal',
	'transit',
	'state',
	'federal'
);


-- Drop typeahead_locations (to be recreated later after jurisdiction_type is updated)
DROP MATERIALIZED VIEW typeahead_locations;

-- Update typeahead_agencies
DROP MATERIALIZED VIEW TYPEAHEAD_AGENCIES; -- to be recreated later


-- Set all jurisdiction types to their lowercase version
UPDATE agencies
SET jurisdiction_type = CASE
    WHEN jurisdiction_type ILIKE '%school%' THEN 'school'
    WHEN jurisdiction_type ILIKE '%county%' THEN 'county'
    WHEN jurisdiction_type ILIKE '%local%' THEN 'local'
    WHEN jurisdiction_type ILIKE '%port%' THEN 'port'
    WHEN jurisdiction_type ILIKE '%tribal%' THEN 'tribal'
    WHEN jurisdiction_type ILIKE '%transit%' THEN 'transit'
    WHEN jurisdiction_type ILIKE '%state%' THEN 'state'
    WHEN jurisdiction_type ILIKE '%federal%' THEN 'federal'
    ELSE jurisdiction_type
END
WHERE jurisdiction_type ILIKE ANY (ARRAY[
    '%school%',
    '%county%',
    '%local%',
    '%port%',
    '%tribal%',
    '%transit%',
    '%state%',
    '%federal%'
]);


-- Update `jurisdiction_type` column to accept enum
ALTER TABLE AGENCIES
ALTER COLUMN jurisdiction_type TYPE jurisdiction_type USING jurisdiction_type::jurisdiction_type;




-- Create Locations expanded view

CREATE OR REPLACE VIEW locations_expanded as (
    SELECT
        LOCATIONS.ID,
        LOCATIONS.TYPE,
        US_STATES.STATE_NAME,
        US_STATES.STATE_ISO,
        COUNTIES.NAME AS COUNTY_NAME,
        COUNTIES.FIPS AS COUNTY_FIPS,
        LOCALITIES.NAME AS LOCALITY_NAME,
        LOCALITIES.ID AS LOCALITY_ID,
        US_STATES.ID AS STATE_ID,
        COUNTIES.ID AS COUNTY_ID
    FROM LOCATIONS
        LEFT JOIN US_STATES ON LOCATIONS.STATE_ID = US_STATES.ID
        LEFT JOIN COUNTIES ON LOCATIONS.COUNTY_ID = COUNTIES.ID
        LEFT JOIN LOCALITIES ON LOCATIONS.LOCALITY_ID = LOCALITIES.ID
    );

COMMENT ON VIEW locations_expanded IS 'View containing information about locations as well as limited information from other tables connected by foreign keys.';


CREATE MATERIALIZED VIEW typeahead_locations as
    SELECT
        ID AS LOCATION_ID,
        CASE WHEN
            TYPE = 'Locality' THEN LOCALITY_NAME
            WHEN TYPE = 'County' THEN COUNTY_NAME
            WHEN TYPE = 'State' THEN STATE_NAME
        END AS display_name,
        TYPE,
        STATE_NAME,
        COUNTY_NAME,
        LOCALITY_NAME
    FROM locations_expanded;

-- Create agencies_expanded view
CREATE OR REPLACE VIEW agencies_expanded as (
	SELECT
		a.NAME,
		a.SUBMITTED_NAME,
		a.HOMEPAGE_URL,
		a.JURISDICTION_TYPE,
		l.STATE_ISO,
		l.STATE_NAME,
		l.COUNTY_FIPS,
		l.COUNTY_NAME,
		a.LAT,
		a.LNG,
		a.DEFUNCT_YEAR,
		a.AIRTABLE_UID,
		a.COUNT_DATA_SOURCES,
		a.AGENCY_TYPE,
		a.MULTI_AGENCY,
		a.ZIP_CODE,
		a.DATA_SOURCES,
		a.NO_WEB_PRESENCE,
		a.AIRTABLE_AGENCY_LAST_MODIFIED,
		a.DATA_SOURCES_LAST_UPDATED,
		a.APPROVED,
		a.REJECTION_REASON,
		a.LAST_APPROVAL_EDITOR,
		a.SUBMITTER_CONTACT,
		a.AGENCY_CREATED,
		l.LOCALITY_NAME LOCALITY_NAME
	FROM
		PUBLIC.AGENCIES A
	LEFT JOIN LOCATIONS_EXPANDED L ON A.LOCATION_ID = L.ID
);

COMMENT ON VIEW agencies_expanded IS 'View containing information about agencies as well as limited information from other tables connected by foreign keys.';


CREATE MATERIALIZED VIEW TYPEAHEAD_AGENCIES AS
SELECT
	A.NAME,
	A.JURISDICTION_TYPE,
	A.STATE_ISO,
	A.LOCALITY_NAME MUNICIPALITY,
	A.COUNTY_NAME
FROM
	AGENCIES_EXPANDED A;

-- Add unique constraint to test table for testing purposes
ALTER TABLE test_table ADD UNIQUE(pet_name, species);


ALTER TABLE AGENCIES
ALTER COLUMN JURISDICTION_TYPE SET NOT NULL;

-- Data cleaning: Replace change whose agency_type is 'law enforcement/police' to 'police'
UPDATE AGENCIES
SET
	AGENCY_TYPE = 'police'
WHERE
	AGENCY_TYPE = 'law enforcement/police';

-- Data cleaning: Set all agencies whose approved is `null` to `False`
UPDATE AGENCIES
SET
    APPROVED = FALSE
WHERE
    APPROVED IS NULL;

-- Set constraint so that approved cannot be null; defaults to false
ALTER TABLE AGENCIES
ALTER COLUMN APPROVED SET NOT NULL;

ALTER TABLE AGENCIES
ALTER COLUMN APPROVED SET DEFAULT FALSE;

-- Data cleaning: Set all agencies who `multi_agency` is `null` to `False`

UPDATE AGENCIES
SET
    MULTI_AGENCY = FALSE
WHERE
    MULTI_AGENCY IS NULL;

-- Set constraint so that `multi_agency` cannot be null; defaults to false
ALTER TABLE AGENCIES
ALTER COLUMN MULTI_AGENCY SET NOT NULL;

ALTER TABLE AGENCIES
ALTER COLUMN MULTI_AGENCY SET DEFAULT FALSE;

-- Data cleaning: Set all null values of `NO_WEB_PRESENCE` to `False`
UPDATE AGENCIES
SET
    NO_WEB_PRESENCE = FALSE
WHERE
    NO_WEB_PRESENCE IS NULL;

-- Set constraint so that `NO_WEB_PRESENCE` cannot be null; defaults to false
ALTER TABLE AGENCIES
ALTER COLUMN NO_WEB_PRESENCE SET NOT NULL;

ALTER TABLE AGENCIES
ALTER COLUMN NO_WEB_PRESENCE SET DEFAULT FALSE;

-- Set default datetime for agency_created to time of creation
ALTER TABLE AGENCIES
ALTER COLUMN agency_created SET DEFAULT Current_timestamp;

UPDATE AGENCIES
SET AGENCY_CREATED = CURRENT_TIMESTAMP
WHERE AGENCY_CREATED IS NULL;

ALTER TABLE AGENCIES
ALTER COLUMN agency_created SET NOT NULL;

-- Set default datetime for `AIRTABLE_AGENCY_LAST_MODIFIED` to time of creation
-- And add trigger to update on updates to the row

ALTER TABLE AGENCIES
ALTER COLUMN AIRTABLE_AGENCY_LAST_MODIFIED SET DEFAULT CURRENT_TIMESTAMP;

UPDATE AGENCIES
SET AIRTABLE_AGENCY_LAST_MODIFIED = CURRENT_TIMESTAMP
WHERE AIRTABLE_AGENCY_LAST_MODIFIED IS NULL;

ALTER TABLE AGENCIES
ALTER COLUMN AIRTABLE_AGENCY_LAST_MODIFIED SET NOT NULL;

CREATE OR REPLACE FUNCTION update_airtable_agency_last_modified_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.AIRTABLE_AGENCY_LAST_MODIFIED = current_timestamp;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER SET_AGENCY_UPDATED_AT
BEFORE UPDATE ON AGENCIES
FOR EACH ROW
EXECUTE PROCEDURE update_airtable_agency_last_modified_column();

----------------------------------------
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/457
----------------------------------------

ALTER TABLE AGENCY_SOURCE_LINK
RENAME COLUMN airtable_uid to data_source_uid;

ALTER TABLE AGENCY_SOURCE_LINK
RENAME COLUMN agency_described_linked_uid TO agency_uid;

-- Remove all existing rows.
DELETE FROM AGENCY_SOURCE_LINK;

-- Re-insert rows
INSERT INTO AGENCY_SOURCE_LINK(data_source_uid, agency_uid)
SELECT
	UNNEST(
		STRING_TO_ARRAY(
			REGEXP_REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(REPLACE(DATA_SOURCES, ']', ''), '[', ''),
						'"',
						''
					),
					'\',
					''
				),
				'\s',
				'',
				'g'
			),
			','
		)
	) DATA_SOURCE_AIRTABLE_UID,
	AIRTABLE_UID AGENCY_AIRTABLE_UID
FROM
	AGENCIES
WHERE
	DATA_SOURCES IS NOT NULL;

COMMENT ON TABLE AGENCY_SOURCE_LINK IS 'A link table between data sources and their related agencies.';
COMMENT ON COLUMN AGENCY_SOURCE_LINK.data_source_uid IS 'Foreign key referencing data_sources';
COMMENT ON COLUMN AGENCY_SOURCE_LINK.agency_uid IS 'Foreign key referencing agencies';

-- Recreate agencies_expanded view without the DATA_SOURCES column

DROP MATERIALIZED VIEW TYPEAHEAD_AGENCIES;

DROP VIEW agencies_expanded;

ALTER TABLE AGENCIES DROP COLUMN DATA_SOURCES;
ALTER TABLE AGENCIES DROP COLUMN DATA_SOURCES_LAST_UPDATED;
ALTER TABLE AGENCIES DROP COLUMN COUNT_DATA_SOURCES;

-- recreate agencies_expanded view
CREATE OR REPLACE VIEW agencies_expanded as (
	SELECT
		a.NAME,
		a.SUBMITTED_NAME,
		a.HOMEPAGE_URL,
		a.JURISDICTION_TYPE,
		l.STATE_ISO,
		l.STATE_NAME,
		l.COUNTY_FIPS,
		l.COUNTY_NAME,
		a.LAT,
		a.LNG,
		a.DEFUNCT_YEAR,
		a.AIRTABLE_UID,
		a.AGENCY_TYPE,
		a.MULTI_AGENCY,
		a.ZIP_CODE,
		a.NO_WEB_PRESENCE,
		a.AIRTABLE_AGENCY_LAST_MODIFIED,
		a.APPROVED,
		a.REJECTION_REASON,
		a.LAST_APPROVAL_EDITOR,
		a.SUBMITTER_CONTACT,
		a.AGENCY_CREATED,
		l.LOCALITY_NAME LOCALITY_NAME
	FROM
		PUBLIC.AGENCIES A
	LEFT JOIN LOCATIONS_EXPANDED L ON A.LOCATION_ID = L.ID
);

COMMENT ON VIEW agencies_expanded IS 'View containing information about agencies as well as limited information from other tables connected by foreign keys.';

-- Recreate typeahead agencies
CREATE MATERIALIZED VIEW TYPEAHEAD_AGENCIES AS
SELECT
	A.NAME,
	A.JURISDICTION_TYPE,
	A.STATE_ISO,
	A.LOCALITY_NAME MUNICIPALITY,
	A.COUNTY_NAME
FROM
	AGENCIES_EXPANDED A;

-- Create supporting utility views for getting the number of data sources per agency
-- and vice versa
CREATE OR REPLACE VIEW NUM_DATA_SOURCES_PER_AGENCY as
SELECT
	COUNT(L.DATA_SOURCE_UID) DATA_SOURCE_COUNT,
	L.AGENCY_UID
FROM AGENCY_SOURCE_LINK L
GROUP BY L.AGENCY_UID;

COMMENT ON VIEW NUM_DATA_SOURCES_PER_AGENCY IS 'View containing the number of data sources associated with each agency';

CREATE OR REPLACE VIEW NUM_AGENCIES_PER_DATA_SOURCE as
SELECT
    COUNT(L.AGENCY_UID) AGENCY_COUNT,
    L.DATA_SOURCE_UID
FROM AGENCY_SOURCE_LINK L
GROUP BY L.DATA_SOURCE_UID;

COMMENT ON VIEW NUM_AGENCIES_PER_DATA_SOURCE IS 'View containing the number of agencies associated with each data source';

----------------------------------------------------
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/462
----------------------------------------------------
-- Create `link_user_followed_location` table
CREATE TABLE IF NOT EXISTS public.link_user_followed_location (
    id BIGINT PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
    user_id integer NOT NULL,
    location_id integer NOT NULL,
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE CASCADE,
    CONSTRAINT unique_user_location UNIQUE (user_id, location_id)
);

-- Add comments
COMMENT ON TABLE public.link_user_followed_location IS 'A link table between users and their followed locations.';
COMMENT ON COLUMN public.link_user_followed_location.id IS 'Primary key, auto-incrementing';
COMMENT ON COLUMN public.link_user_followed_location.user_id IS 'Foreign key referencing users';
COMMENT ON COLUMN public.link_user_followed_location.location_id IS 'Foreign key referencing locations';

------------------------------------------------------
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/446
------------------------------------------------------
ALTER TABLE data_requests
DROP COLUMN submitter_email;
------------------------------------------------------
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/430
------------------------------------------------------
-- Remove columns
ALTER TABLE data_sources
DROP COLUMN url_broken, -- Replaced by `url_status`
DROP COLUMN approved, -- Replaced by `approval_status`
DROP COLUMN records_not_online, -- Not used
DROP COLUMN record_type, -- replaced by record_type_id,
DROP COLUMN number_of_records_available, -- Not used
DROP COLUMN size, -- Not used
DROP COLUMN RECORD_TYPE_OTHER, -- Not used
DROP COLUMN airtable_source_last_modified, -- Not used
DROP COLUMN URL_BUTTON, -- Not used
DROP COLUMN tags_other, -- Not used
DROP COLUMN PRIVATE_ACCESS_INSTRUCTIONS; -- Not used

ALTER TABLE data_sources
RENAME data_source_created to created_at;

ALTER TABLE data_sources
ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE;

ALTER TABLE data_sources
ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE data_sources
ALTER COLUMN created_at SET NOT NULL;

ALTER TABLE data_sources
RENAME source_last_updated to updated_at;

ALTER TABLE data_sources
ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE;

ALTER TABLE data_sources
ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;

UPDATE data_sources
SET updated_at = CURRENT_TIMESTAMP
WHERE updated_at IS NULL;

ALTER TABLE data_sources
ALTER COLUMN updated_at SET NOT NULL;

CREATE OR REPLACE FUNCTION update_data_source_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = current_timestamp;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER SET_DATA_SOURCE_UPDATED_AT
BEFORE UPDATE ON data_sources
FOR EACH ROW
EXECUTE PROCEDURE update_data_source_updated_at_column();

CREATE TYPE URL_STATUS as enum('ok', 'none found', 'broken', 'available');

-- Update URL_STATUS column
UPDATE DATA_SOURCES
SET URL_STATUS = 'ok'
WHERE URL_STATUS IS NULL;

ALTER TABLE DATA_SOURCES
ALTER COLUMN URL_STATUS SET NOT NULL;

ALTER TABLE DATA_SOURCES
ALTER COLUMN URL_STATUS type URL_STATUS using URL_STATUS::URL_STATUS;

ALTER TABLE DATA_SOURCES
ALTER COLUMN URL_STATUS SET DEFAULT 'ok';

CREATE TYPE retention_schedule AS ENUM (
    '< 1 day',
    '1 day',
    '< 1 week',
    '1 week',
    '1 month',
    '< 1 year',
    '1-10 years',
    '> 10 years',
    'Future only'
);

ALTER TABLE data_sources
ALTER COLUMN retention_schedule type retention_schedule USING retention_schedule::retention_schedule;

-- Update approval_status column to enum and set to not-null with default of 'pending'
CREATE TYPE approval_status as enum ('approved', 'rejected', 'pending', 'needs identification');

DROP MATERIALIZED VIEW distinct_source_urls;

ALTER TABLE data_sources
ALTER COLUMN approval_status type approval_status USING approval_status::approval_status;

UPDATE DATA_SOURCES
SET approval_status = 'pending'
WHERE approval_status IS NULL;

ALTER TABLE DATA_SOURCES
ALTER COLUMN approval_status SET NOT NULL;

ALTER TABLE DATA_SOURCES
ALTER COLUMN approval_status SET DEFAULT 'pending';

CREATE MATERIALIZED VIEW IF NOT EXISTS public.distinct_source_urls
TABLESPACE pg_default
AS
	SELECT DISTINCT
		-- Remove trailing '/'
		RTRIM(
			-- Remove beginning https://, http://, and www.
			LTRIM(
				LTRIM(
					LTRIM(SOURCE_URL, 'https://'),
				'http://'
				),
			'www.'
			),
		'/'
		) base_url,
		source_url original_url,
		rejection_note,
		approval_status
	FROM data_sources
	WHERE
		source_url is not NULL;

-- Create `record_types_expanded` view
CREATE VIEW RECORD_TYPES_EXPANDED AS
SELECT
	RT.ID RECORD_TYPE_ID,
	RT.NAME RECORD_TYPE_NAME,
	RC.ID RECORD_CATEGORY_ID,
	RC.NAME RECORD_CATEGORY_NAME
FROM
	RECORD_TYPES RT
INNER JOIN RECORD_CATEGORIES RC ON RT.CATEGORY_ID = RC.ID;

-- Set Agencies `submitted_name` column to not be null
ALTER TABLE AGENCIES
ALTER COLUMN SUBMITTED_NAME SET NOT NULL;

-- Convert `detail_level` column to enum
CREATE TYPE detail_level AS ENUM(
	'Individual record',
	'Aggregated records',
	'Summarized totals'
);

ALTER TABLE DATA_SOURCES
ALTER COLUMN detail_level type detail_level USING detail_level::detail_level;

-- Update access_type column, changing to `access_types`
CREATE TYPE access_type as ENUM(
    'Download',
    'Webpage',
    'API'
);

ALTER TABLE data_sources
ADD COLUMN ACCESS_TYPES access_type[];

UPDATE DATA_SOURCES
SET ACCESS_TYPES =
    STRING_TO_ARRAY(
			REGEXP_REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(REPLACE(access_type, ']', ''), '[', ''),
						'"',
						''
					),
					'\',
					''
				),
				'\s',
				'',
				'g'
			),
			','
		)::access_type[];

ALTER TABLE DATA_SOURCES
DROP COLUMN ACCESS_TYPE;

-- Convert `tags` column to array
ALTER TABLE DATA_SOURCES
ADD COLUMN TAGS_NEW TEXT[];

UPDATE DATA_SOURCES
SET TAGS_NEW =
    STRING_TO_ARRAY(
            REGEXP_REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(REPLACE(tags, ']', ''), '[', ''),
                        '"',
                        ''
                    ),
                    '\',
                    ''
                ),
                '\s',
                '',
                'g'
            ),
            ','
        );

ALTER TABLE DATA_SOURCES
DROP COLUMN TAGS;

ALTER TABLE DATA_SOURCES
RENAME COLUMN TAGS_NEW TO TAGS;

-- convert record_format column to array
ALTER TABLE DATA_SOURCES
ADD COLUMN RECORD_FORMATS TEXT[];

UPDATE DATA_SOURCES
SET RECORD_FORMATS =
    STRING_TO_ARRAY(
            REGEXP_REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(REPLACE(record_format, ']', ''), '[', ''),
                        '"',
                        ''
                    ),
                    '\',
                    ''
                ),
                '\s',
                '',
                'g'
            ),
            ','
        );

ALTER TABLE DATA_SOURCES
DROP COLUMN RECORD_FORMAT;

-- Convert `update_method` column to enum
CREATE TYPE update_method AS ENUM(
    'Insert',
    'No updates',
    'Overwrite'
);

ALTER TABLE DATA_SOURCES
ALTER COLUMN update_method TYPE update_method USING update_method::update_method;

-- Create `agency_aggregation` enum
CREATE TYPE agency_aggregation AS ENUM(
    'county',
    'local',
    'state',
    'federal'
);

ALTER TABLE DATA_SOURCES
ALTER COLUMN agency_aggregation TYPE agency_aggregation USING agency_aggregation::agency_aggregation;

-- Create `data_sources_expanded` view
CREATE OR REPLACE VIEW DATA_SOURCES_EXPANDED AS
SELECT
	DS.NAME,
	DS.SUBMITTED_NAME,
	DS.DESCRIPTION,
	DS.SOURCE_URL,
	DS.AGENCY_SUPPLIED,
	DS.SUPPLYING_ENTITY,
	DS.AGENCY_ORIGINATED,
	DS.AGENCY_AGGREGATION,
	DS.COVERAGE_START,
	DS.COVERAGE_END,
	DS.UPDATED_AT,
	DS.DETAIL_LEVEL,
	DS.RECORD_DOWNLOAD_OPTION_PROVIDED,
	DS.DATA_PORTAL_TYPE,
	DS.UPDATE_METHOD,
	DS.README_URL,
	DS.ORIGINATING_ENTITY,
	DS.RETENTION_SCHEDULE,
	DS.AIRTABLE_UID,
	DS.SCRAPER_URL,
	DS.CREATED_AT,
	DS.SUBMISSION_NOTES,
	DS.REJECTION_NOTE,
	DS.LAST_APPROVAL_EDITOR,
	DS.SUBMITTER_CONTACT_INFO,
	DS.AGENCY_DESCRIBED_SUBMITTED,
	DS.AGENCY_DESCRIBED_NOT_IN_DATABASE,
	DS.DATA_PORTAL_TYPE_OTHER,
	DS.DATA_SOURCE_REQUEST,
	DS.BROKEN_SOURCE_URL_AS_OF,
	DS.ACCESS_NOTES,
	DS.URL_STATUS,
	DS.APPROVAL_STATUS,
	DS.RECORD_TYPE_ID,
	RT.NAME AS RECORD_TYPE_NAME,
	DS.ACCESS_TYPES,
	DS.TAGS,
	DS.RECORD_FORMATS
FROM
	PUBLIC.DATA_SOURCES DS
	LEFT JOIN RECORD_TYPES RT ON DS.RECORD_TYPE_ID = RT.ID;

--------------------------
-- 2024-10-06: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/432
--------------------------

-- Set all null `data_requests.request_status` to `Intake`
UPDATE DATA_REQUESTS
SET request_status = 'Intake'
WHERE request_status is null;

-- Make `data_requests.request_status` NOT NULL
ALTER TABLE DATA_REQUESTS
ALTER COLUMN request_status SET NOT NULL;

-- Update `data_requests.date_created` to NOT NULL, set all null to current timestamp

UPDATE DATA_REQUESTS
SET date_created = CURRENT_TIMESTAMP
WHERE date_created is null;

ALTER TABLE DATA_REQUESTS
ALTER COLUMN date_created SET NOT NULL;

-- Update `data_requests.date_status_last_changed` to NOT NULL, set all null to current timestamp

UPDATE DATA_REQUESTS
SET date_status_last_changed = CURRENT_TIMESTAMP
WHERE date_status_last_changed is null;

ALTER TABLE DATA_REQUESTS
ALTER COLUMN date_status_last_changed SET NOT NULL;

------------------------------------------
-- 2024-10-09: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/473
------------------------------------------
-- For DATA_SOURCES, create trigger so that name is automatically filled in with `submitted_name` if `name` is null on insert

CREATE OR REPLACE FUNCTION set_source_name()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.name IS NULL THEN
        NEW.name := NEW.submitted_name;
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_source_name
BEFORE INSERT
ON DATA_SOURCES
FOR EACH ROW
EXECUTE PROCEDURE set_source_name();

-------------------------------------
-- 2024-10-09: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/475
-------------------------------------

-- Create `request_urgency_level` enum
CREATE TYPE request_urgency_level AS ENUM (
    'urgent', -- less than a week
    'somewhat_urgent', -- less than a month
    'not_urgent', -- a few months
    'long_term', -- long-term
    'indefinite_unknown'
);

-- Add `request_urgency` to `data_requests`
ALTER TABLE DATA_REQUESTS
ADD COLUMN request_urgency request_urgency_level DEFAULT 'indefinite_unknown';

COMMENT ON TYPE public.request_urgency_level IS '
Represents the urgency of the given request:

- ''urgent'': Less than a week.
- ''somewhat_urgent'': Less than a month.
- ''not_urgent'': A few months.
- ''Long-term'': A year or more.
- ''indefinite_unknown'': The request is indefinite, or its urgency level is not known
';

-------------------------------------
-- 2024-10-10: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/465
-------------------------------------
-- Create `data_requests_github_issue_info` table
CREATE TABLE DATA_REQUESTS_GITHUB_ISSUE_INFO (
    id SERIAL PRIMARY KEY,
    data_request_id INTEGER NOT NULL REFERENCES DATA_REQUESTS(id) ON DELETE CASCADE,
    github_issue_url TEXT NOT NULL,
    github_issue_number INTEGER NOT NULL,
    UNIQUE(data_request_id), -- Each data request should have at most one entry
    UNIQUE(github_issue_number), -- Each issue should have at most one entry
    UNIQUE(github_issue_url) -- Each issue should have at most one entry
);

-- Drop `data_requests.github_issue_url`
ALTER TABLE DATA_REQUESTS DROP COLUMN github_issue_url;

-- Create `data_requests_expanded` view that includes `data_requests_github_issue_info`
CREATE OR REPLACE VIEW DATA_REQUESTS_EXPANDED AS
SELECT
    DR.ID,
	DR.SUBMISSION_NOTES,
	DR.REQUEST_STATUS,
	DR.LOCATION_DESCRIBED_SUBMITTED,
	DR.ARCHIVE_REASON,
	DR.DATE_CREATED,
    DR.DATE_STATUS_LAST_CHANGED,
    DR.CREATOR_USER_ID,
	DR.INTERNAL_NOTES,
	DR.RECORD_TYPES_REQUIRED,
	DR.PDAP_RESPONSE,
	DR.COVERAGE_RANGE,
	DR.DATA_REQUIREMENTS,
	DR.REQUEST_URGENCY,
	DRGI.GITHUB_ISSUE_URL,
    DRGI.GITHUB_ISSUE_NUMBER
FROM
    DATA_REQUESTS DR
    LEFT JOIN DATA_REQUESTS_GITHUB_ISSUE_INFO DRGI ON DR.ID = DRGI.DATA_REQUEST_ID;

------------------------------------------
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/480
------------------------------------------

-- Remove `airtable_uid` from `counties`
ALTER TABLE COUNTIES
DROP COLUMN airtable_uid;

-- Convert Airtable UIDs to Integer IDs

ALTER TABLE DATA_SOURCES
    ADD COLUMN ID INTEGER GENERATED BY DEFAULT AS IDENTITY,
    ADD CONSTRAINT DATA_SOURCES_ID_UNIQUE UNIQUE (ID);

ALTER TABLE AGENCIES
    ADD COLUMN ID INTEGER GENERATED BY DEFAULT AS IDENTITY,
    ADD CONSTRAINT AGENCIES_ID_UNIQUE UNIQUE (ID);

-- DATA SOURCES ARCHIVE INFO
-- Add new column
ALTER TABLE DATA_SOURCES_ARCHIVE_INFO
    ADD COLUMN DATA_SOURCE_ID INTEGER GENERATED BY DEFAULT AS IDENTITY;

-- Set link table ids to be same as those linked via airtable
UPDATE data_sources_archive_info
SET data_source_id = data_sources.id
FROM data_sources
WHERE data_sources_archive_info.airtable_uid = data_sources.airtable_uid;

-- Drop old foreign key constraint and add new one

ALTER TABLE DATA_SOURCES_ARCHIVE_INFO
    DROP CONSTRAINT airtale_uid_fk,
    ADD CONSTRAINT data_sources_archive_info_data_source_id_fkey
    FOREIGN KEY (data_source_id) REFERENCES DATA_SOURCES(id) ON DELETE CASCADE;

-- Drop old primary key constraint and add new one
ALTER TABLE DATA_SOURCES_ARCHIVE_INFO
    DROP CONSTRAINT airtable_uid_pk,
    ADD CONSTRAINT data_sources_archive_info_pkey
    PRIMARY KEY (data_source_id);

-- Drop old column
ALTER TABLE DATA_SOURCES_ARCHIVE_INFO
    DROP COLUMN airtable_uid;


-- AGENCY SOURCE LINK

-- Add new columns
ALTER TABLE AGENCY_SOURCE_LINK
    ADD COLUMN DATA_SOURCE_ID INTEGER GENERATED BY DEFAULT AS IDENTITY,
    ADD COLUMN AGENCY_ID INTEGER GENERATED BY DEFAULT AS IDENTITY;

-- Set link table ids to be same as those linked via airtable
UPDATE agency_source_link
SET data_source_id = data_sources.id
FROM data_sources
WHERE agency_source_link.data_source_uid = data_sources.airtable_uid;

UPDATE agency_source_link
SET agency_id = agencies.id
FROM agencies
WHERE agency_source_link.agency_uid = agencies.airtable_uid;

-- Drop old foreign key constraints and add new ones
ALTER TABLE AGENCY_SOURCE_LINK
    DROP CONSTRAINT agency_source_link_agency_described_linked_uid_fkey,
    DROP CONSTRAINT agency_source_link_airtable_uid_fkey,
    ADD CONSTRAINT agency_source_link_agency_id_fkey
    FOREIGN KEY (agency_id) REFERENCES AGENCIES(ID) ON DELETE CASCADE,
    ADD CONSTRAINT agency_source_link_data_source_id_fkey
    FOREIGN KEY (data_source_id) REFERENCES DATA_SOURCES(ID) ON DELETE CASCADE;

-- Drop old primary key constraint and add new one
ALTER TABLE AGENCY_SOURCE_LINK
    DROP CONSTRAINT agency_source_link_pkey,
    ADD CONSTRAINT agency_source_link_pkey
    PRIMARY KEY (data_source_id, agency_id);

-- Drop dependent views to replace
DROP VIEW num_data_sources_per_agency;
DROP VIEW num_agencies_per_data_source;

-- Drop old columns

ALTER TABLE AGENCY_SOURCE_LINK
    DROP COLUMN agency_uid,
    DROP COLUMN data_source_uid;

-- Recreate views
CREATE OR REPLACE VIEW public.num_data_sources_per_agency
 AS
 SELECT count(l.data_source_id) AS data_source_count,
    l.agency_id
   FROM agency_source_link l
  GROUP BY l.agency_id;

ALTER TABLE public.num_data_sources_per_agency
    OWNER TO doadmin;
COMMENT ON VIEW public.num_data_sources_per_agency
    IS 'View containing the number of data sources associated with each agency';

CREATE OR REPLACE VIEW public.num_agencies_per_data_source
 AS
 SELECT count(l.agency_id) AS agency_count,
    l.data_source_id
   FROM agency_source_link l
  GROUP BY l.data_source_id;

ALTER TABLE public.num_agencies_per_data_source
    OWNER TO doadmin;
COMMENT ON VIEW public.num_agencies_per_data_source
    IS 'View containing the number of agencies associated with each data source';

-- AGENCY URL SEARCH CACHE

-- Add new columns
ALTER TABLE AGENCY_URL_SEARCH_CACHE
    ADD COLUMN AGENCY_ID INTEGER GENERATED BY DEFAULT AS IDENTITY;

-- Set link table ids to be same as those linked via airtable
UPDATE agency_url_search_cache
SET agency_id = agencies.id
FROM agencies
WHERE agency_url_search_cache.agency_airtable_uid = agencies.airtable_uid;

-- Drop old foreign key constraint and add new one
ALTER TABLE AGENCY_URL_SEARCH_CACHE
    DROP CONSTRAINT fk_agency_uid,
    ADD CONSTRAINT agency_url_search_cache_agency_id_fkey
    FOREIGN KEY (agency_id) REFERENCES AGENCIES(ID);

-- Remove old column
ALTER TABLE AGENCY_URL_SEARCH_CACHE
    DROP COLUMN agency_airtable_uid;

-- LINK DATA SOURCES DATA REQUESTS

-- Add new columns
ALTER TABLE LINK_DATA_SOURCES_DATA_REQUESTS
    ADD COLUMN DATA_SOURCE_ID INTEGER GENERATED BY DEFAULT AS IDENTITY;

-- Set link table ids to be same as those linked via airtable
UPDATE link_data_sources_data_requests
SET data_source_id = data_sources.id
FROM data_sources
WHERE link_data_sources_data_requests.source_id = data_sources.airtable_uid;

-- Drop old constraints and add new ones
ALTER TABLE link_data_sources_data_requests
    DROP CONSTRAINT unique_source_request,
    DROP CONSTRAINT link_data_sources_data_requests_source_id_fkey,
    ADD CONSTRAINT link_data_sources_data_requests_data_source_id_fkey
    FOREIGN KEY (data_source_id) REFERENCES DATA_SOURCES(ID) ON DELETE CASCADE,
    ADD CONSTRAINT unique_source_request UNIQUE (data_source_id, request_id);

-- Drop old column
ALTER TABLE LINK_DATA_SOURCES_DATA_REQUESTS
    DROP COLUMN source_id;

-- Update Agencies primary key constraint and remove old column
-- Drop relevant views
DROP MATERIALIZED VIEW typeahead_agencies;
DROP VIEW agencies_expanded;

-- Remove from agencies (while retaining airtable_uid column for historical purposes)
ALTER TABLE agencies
    DROP CONSTRAINT agencies_pkey,
    ADD CONSTRAINT agencies_pkey PRIMARY KEY (id);

-- recreate agencies_expanded view
CREATE OR REPLACE VIEW agencies_expanded as (
	SELECT
		a.NAME,
		a.SUBMITTED_NAME,
		a.HOMEPAGE_URL,
		a.JURISDICTION_TYPE,
		l.STATE_ISO,
		l.STATE_NAME,
		l.COUNTY_FIPS,
		l.COUNTY_NAME,
		a.LAT,
		a.LNG,
		a.DEFUNCT_YEAR,
		a.ID,
		a.AGENCY_TYPE,
		a.MULTI_AGENCY,
		a.ZIP_CODE,
		a.NO_WEB_PRESENCE,
		a.AIRTABLE_AGENCY_LAST_MODIFIED,
		a.APPROVED,
		a.REJECTION_REASON,
		a.LAST_APPROVAL_EDITOR,
		a.SUBMITTER_CONTACT,
		a.AGENCY_CREATED,
		l.LOCALITY_NAME LOCALITY_NAME
	FROM
		PUBLIC.AGENCIES A
	LEFT JOIN LOCATIONS_EXPANDED L ON A.LOCATION_ID = L.ID
);

COMMENT ON VIEW agencies_expanded IS 'View containing information about agencies as well as limited information from other tables connected by foreign keys.';

-- Recreate typeahead agencies
CREATE MATERIALIZED VIEW TYPEAHEAD_AGENCIES AS
SELECT
	A.NAME,
	A.JURISDICTION_TYPE,
	A.STATE_ISO,
	A.LOCALITY_NAME MUNICIPALITY,
	A.COUNTY_NAME
FROM
	AGENCIES_EXPANDED A;



-- Update Data Sources primary key constraint and remove old column

-- Drop unused tables
DROP TABLE user_starred_data_sources;
DROP TABLE requests_v2;

-- Drop relevant views
DROP VIEW DATA_SOURCES_EXPANDED;

-- Remove from data sources (while retaining airtable_uid column for historical purposes)
ALTER TABLE data_sources
    DROP CONSTRAINT data_sources_pkey,
    ADD CONSTRAINT data_sources_pkey PRIMARY KEY (id);


-- Recreate `data_sources_expanded` view
CREATE OR REPLACE VIEW DATA_SOURCES_EXPANDED AS
SELECT
	DS.NAME,
	DS.SUBMITTED_NAME,
	DS.DESCRIPTION,
	DS.SOURCE_URL,
	DS.AGENCY_SUPPLIED,
	DS.SUPPLYING_ENTITY,
	DS.AGENCY_ORIGINATED,
	DS.AGENCY_AGGREGATION,
	DS.COVERAGE_START,
	DS.COVERAGE_END,
	DS.UPDATED_AT,
	DS.DETAIL_LEVEL,
	DS.RECORD_DOWNLOAD_OPTION_PROVIDED,
	DS.DATA_PORTAL_TYPE,
	DS.UPDATE_METHOD,
	DS.README_URL,
	DS.ORIGINATING_ENTITY,
	DS.RETENTION_SCHEDULE,
	DS.ID,
	DS.SCRAPER_URL,
	DS.CREATED_AT,
	DS.SUBMISSION_NOTES,
	DS.REJECTION_NOTE,
	DS.LAST_APPROVAL_EDITOR,
	DS.SUBMITTER_CONTACT_INFO,
	DS.AGENCY_DESCRIBED_SUBMITTED,
	DS.AGENCY_DESCRIBED_NOT_IN_DATABASE,
	DS.DATA_PORTAL_TYPE_OTHER,
	DS.DATA_SOURCE_REQUEST,
	DS.BROKEN_SOURCE_URL_AS_OF,
	DS.ACCESS_NOTES,
	DS.URL_STATUS,
	DS.APPROVAL_STATUS,
	DS.RECORD_TYPE_ID,
	RT.NAME AS RECORD_TYPE_NAME,
	DS.ACCESS_TYPES,
	DS.TAGS,
	DS.RECORD_FORMATS
FROM
	PUBLIC.DATA_SOURCES DS
	LEFT JOIN RECORD_TYPES RT ON DS.RECORD_TYPE_ID = RT.ID;

-- Update trigger
CREATE OR REPLACE FUNCTION insert_new_archive_info() RETURNS TRIGGER AS $$
BEGIN
   INSERT INTO data_sources_archive_info (data_source_id)
   VALUES (NEW.id);
   RETURN NEW;
END
$$ LANGUAGE plpgsql;

--------------------------------------------
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/482
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/483
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/481
--------------------------------------------

-- Add approval_status_updated_at to `data_sources`
ALTER TABLE data_sources
ADD COLUMN approval_status_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

-- Create procedure
CREATE OR REPLACE FUNCTION update_approval_status_updated_at() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN
        NEW.approval_status_updated_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update when status is changed
CREATE TRIGGER update_approval_status_updated_at
BEFORE UPDATE ON data_sources
FOR EACH ROW
EXECUTE PROCEDURE update_approval_status_updated_at();

-- Recreate Data Sources Expanded View
DROP VIEW DATA_SOURCES_EXPANDED;

-- Recreate `data_sources_expanded` view
CREATE OR REPLACE VIEW DATA_SOURCES_EXPANDED AS
SELECT
	DS.NAME,
	DS.SUBMITTED_NAME,
	DS.DESCRIPTION,
	DS.SOURCE_URL,
	DS.AGENCY_SUPPLIED,
	DS.SUPPLYING_ENTITY,
	DS.AGENCY_ORIGINATED,
	DS.AGENCY_AGGREGATION,
	DS.COVERAGE_START,
	DS.COVERAGE_END,
	DS.UPDATED_AT,
	DS.DETAIL_LEVEL,
	DS.RECORD_DOWNLOAD_OPTION_PROVIDED,
	DS.DATA_PORTAL_TYPE,
	DS.UPDATE_METHOD,
	DS.README_URL,
	DS.ORIGINATING_ENTITY,
	DS.RETENTION_SCHEDULE,
	DS.ID,
	DS.SCRAPER_URL,
	DS.CREATED_AT,
	DS.SUBMISSION_NOTES,
	DS.REJECTION_NOTE,
	DS.LAST_APPROVAL_EDITOR,
	DS.SUBMITTER_CONTACT_INFO,
	DS.AGENCY_DESCRIBED_SUBMITTED,
	DS.AGENCY_DESCRIBED_NOT_IN_DATABASE,
	DS.DATA_PORTAL_TYPE_OTHER,
	DS.DATA_SOURCE_REQUEST,
	DS.BROKEN_SOURCE_URL_AS_OF,
	DS.ACCESS_NOTES,
	DS.URL_STATUS,
	DS.APPROVAL_STATUS,
	DS.RECORD_TYPE_ID,
	RT.NAME AS RECORD_TYPE_NAME,
	DS.ACCESS_TYPES,
	DS.TAGS,
	DS.RECORD_FORMATS,
	DS.approval_status_updated_at
FROM
	PUBLIC.DATA_SOURCES DS
	LEFT JOIN RECORD_TYPES RT ON DS.RECORD_TYPE_ID = RT.ID;

-- Add data requests title with maximum limit
ALTER TABLE data_requests
    ADD COLUMN title TEXT,
    ADD CONSTRAINT title_limit CHECK (length(title) <= 51);

-- Update all existing data requests to have a title that includes the id and 40 characters from submission notes
UPDATE data_requests
SET title = CONCAT(
    'DR',
    id,
    ':',
    substring(SUBMISSION_NOTES for 40),
    '...'
);

-- Set title to not be null
ALTER TABLE data_requests
ALTER COLUMN title SET NOT NULL;

-- Recreate view
DROP VIEW data_requests_expanded;

-- Remove not-null constraints on airtable_uid's
ALTER TABLE DATA_SOURCES
ALTER COLUMN AIRTABLE_UID DROP NOT NULL;

ALTER TABLE AGENCIES
ALTER COLUMN AIRTABLE_UID DROP NOT NULL;

-- Update `agency_source_link` to match nomenclature of other link tables
ALTER TABLE agency_source_link
RENAME TO link_agencies_data_sources;

ALTER TABLE link_agencies_data_sources
RENAME COLUMN link_id to id;

CREATE TABLE LINK_LOCATIONS_DATA_REQUESTS (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    location_id INTEGER NOT NULL REFERENCES LOCATIONS(id) ON DELETE CASCADE,
    data_request_id INTEGER NOT NULL REFERENCES DATA_REQUESTS(id) ON DELETE CASCADE,
    UNIQUE(location_id, data_request_id)
);

ALTER TABLE DATA_REQUESTS
DROP COLUMN location_described_submitted;

CREATE OR REPLACE VIEW DATA_REQUESTS_EXPANDED AS
SELECT
    DR.ID,
    DR.TITLE,
	DR.SUBMISSION_NOTES,
	DR.REQUEST_STATUS,
	DR.ARCHIVE_REASON,
	DR.DATE_CREATED,
    DR.DATE_STATUS_LAST_CHANGED,
    DR.CREATOR_USER_ID,
	DR.INTERNAL_NOTES,
	DR.RECORD_TYPES_REQUIRED,
	DR.PDAP_RESPONSE,
	DR.COVERAGE_RANGE,
	DR.DATA_REQUIREMENTS,
	DR.REQUEST_URGENCY,
	DRGI.GITHUB_ISSUE_URL,
    DRGI.GITHUB_ISSUE_NUMBER
FROM
    DATA_REQUESTS DR
    LEFT JOIN DATA_REQUESTS_GITHUB_ISSUE_INFO DRGI ON DR.ID = DRGI.DATA_REQUEST_ID;

------------------------------------
-- 2024-10-21: Update coverage_range
--------------------------------------
DROP VIEW DATA_REQUESTS_EXPANDED;

ALTER TABLE DATA_REQUESTS
ALTER COLUMN COVERAGE_RANGE TYPE VARCHAR(255);

CREATE OR REPLACE VIEW DATA_REQUESTS_EXPANDED AS
SELECT
    DR.ID,
    DR.TITLE,
	DR.SUBMISSION_NOTES,
	DR.REQUEST_STATUS,
	DR.ARCHIVE_REASON,
	DR.DATE_CREATED,
    DR.DATE_STATUS_LAST_CHANGED,
    DR.CREATOR_USER_ID,
	DR.INTERNAL_NOTES,
	DR.RECORD_TYPES_REQUIRED,
	DR.PDAP_RESPONSE,
	DR.COVERAGE_RANGE,
	DR.DATA_REQUIREMENTS,
	DR.REQUEST_URGENCY,
	DRGI.GITHUB_ISSUE_URL,
    DRGI.GITHUB_ISSUE_NUMBER
FROM
    DATA_REQUESTS DR
    LEFT JOIN DATA_REQUESTS_GITHUB_ISSUE_INFO DRGI ON DR.ID = DRGI.DATA_REQUEST_ID;


-------------------------------------------------------
-- https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/478
-------------------------------------------------------

-- Create Enum of Event Types
CREATE TYPE EVENT_TYPE AS ENUM(
    'Request Ready to Start',
    'Request Complete',
    'Data Source Approved'
);

-- Create Enum of Entity Types
CREATE TYPE ENTITY_TYPE AS ENUM(
    'Data Request',
    'Data Source'
);

-- Create dependent locations view
CREATE VIEW DEPENDENT_LOCATIONS AS
-- Get all county-state relationships
SELECT
	lp.id parent_location_id,
	ld.id dependent_location_id
FROM
	locations lp
	inner join locations ld on ld.state_id = lp.state_id and ld.type = 'County' and lp.type = 'State'
UNION ALL
-- Get all county-locality relationships
SELECT
	lp.id parent_location_id,
	ld.id dependent_location_id
FROM locations lp
	inner join locations ld on ld.county_id = lp.county_id and ld.type = 'Locality' and lp.type = 'County'
-- Get all locality-state relationships
UNION ALL
SELECT
	lp.id parent_location_id,
	ld.id dependent_location_id
FROM locations lp
	inner join locations ld on ld.state_id = lp.state_id and ld.type = 'Locality' and lp.type = 'State';

COMMENT ON VIEW DEPENDENT_LOCATIONS IS 'Expresses which locations are dependent locations of other locations; for example: a county is a dependent location of a state, and a locality is a dependent location of a state and county';

-- Create Qualifying Notifications View

CREATE VIEW QUALIFYING_NOTIFICATIONS AS
	WITH
	CUTOFF_POINT AS (
		SELECT
			(DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month')::TIMESTAMPTZ DATE_RANGE_MIN,
		    DATE_TRUNC('month', CURRENT_DATE) DATE_RANGE_MAX
	)
		SELECT
			CASE
				WHEN DR.REQUEST_STATUS = 'Ready to start' THEN 'Request Ready to Start'::EVENT_TYPE
				WHEN DR.REQUEST_STATUS = 'Complete' THEN 'Request Complete'::EVENT_TYPE
			END EVENT_TYPE,
			DR.ID ENTITY_ID,
			'Data Request'::ENTITY_TYPE ENTITY_TYPE,
			DR.TITLE ENTITY_NAME,
			LNK_DR.LOCATION_ID LOCATION_ID,
			DR.DATE_STATUS_LAST_CHANGED EVENT_TIMESTAMP
		FROM
			CUTOFF_POINT CP,
			DATA_REQUESTS DR
		INNER JOIN LINK_LOCATIONS_DATA_REQUESTS LNK_DR ON LNK_DR.DATA_REQUEST_ID = DR.ID
		WHERE
			DR.DATE_STATUS_LAST_CHANGED > CP.DATE_RANGE_MIN AND DR.DATE_STATUS_LAST_CHANGED < CP.DATE_RANGE_MAX
			AND (DR.REQUEST_STATUS = 'Ready to start' or DR.REQUEST_STATUS = 'Complete')
	UNION ALL
		SELECT
			'Data Source Approved'::EVENT_TYPE EVENT_TYPE,
			DS.ID ENTITY_ID,
			'Data Source'::ENTITY_TYPE ENTITY_TYPE,
			DS.NAME ENTITY_NAME,
			A.LOCATION_ID LOCATION_ID,
			DS.APPROVAL_STATUS_UPDATED_AT EVENT_TIMESTAMP
		FROM
			CUTOFF_POINT CP,
			DATA_SOURCES DS
			INNER JOIN LINK_AGENCIES_DATA_SOURCES LNK ON LNK.DATA_SOURCE_ID = DS.ID
			INNER JOIN AGENCIES A ON LNK.AGENCY_ID = A.ID
		WHERE
			DS.APPROVAL_STATUS_UPDATED_AT > CP.DATE_RANGE_MIN AND DS.APPROVAL_STATUS_UPDATED_AT < CP.DATE_RANGE_MAX
			AND DS.APPROVAL_STATUS = 'approved';

COMMENT ON VIEW QUALIFYING_NOTIFICATIONS IS 'List of data requests and data sources that qualify for notifications';

-- Create user pending notifications view
CREATE VIEW USER_PENDING_NOTIFICATIONS AS
SELECT DISTINCT
	Q.EVENT_TYPE,
	Q.ENTITY_ID,
	Q.ENTITY_TYPE,
	Q.ENTITY_NAME,
	Q.LOCATION_ID,
	Q.EVENT_TIMESTAMP,
	L.USER_ID,
	U.EMAIL
FROM
	PUBLIC.QUALIFYING_NOTIFICATIONS Q
	INNER JOIN DEPENDENT_LOCATIONS D ON D.DEPENDENT_LOCATION_ID = Q.LOCATION_ID
	INNER JOIN LINK_USER_FOLLOWED_LOCATION L ON L.LOCATION_ID = Q.LOCATION_ID
	OR L.LOCATION_ID = D.PARENT_LOCATION_ID
	INNER JOIN USERS U ON U.ID = L.USER_ID;

COMMENT ON VIEW USER_PENDING_NOTIFICATIONS IS 'View of all pending notifications for individual users.';

CREATE TABLE USER_NOTIFICATION_QUEUE (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES USERS(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    entity_id INTEGER NOT NULL,
    entity_type ENTITY_TYPE NOT NULL,
    entity_name TEXT NOT NULL,
    event_type EVENT_TYPE NOT NULL,
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE
);

COMMENT ON TABLE USER_NOTIFICATION_QUEUE IS 'Queue for user notifications for past month.';

-- Create new 'notifications' permission
INSERT INTO PERMISSIONS (permission_name, description) VALUES
    ('notifications', 'Enables sending of notifications to users');

-------------------------------------------------------
-- 2024-10-25: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/468
-------------------------------------------------------

-- Create Recent Searches table
CREATE TABLE RECENT_SEARCHES(
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES USERS(id) ON DELETE CASCADE,
    location_id INTEGER NOT NULL REFERENCES LOCATIONS(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE RECENT_SEARCHES IS 'Table logging last 50 searches for each user';

CREATE OR REPLACE FUNCTION maintain_recent_searches_row_limit()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if there are more than 50 rows with the same user_id
    IF (SELECT COUNT(*) FROM RECENT_SEARCHES WHERE user_id = NEW.user_id) >= 50 THEN
        -- Delete the oldest row for that b_id
        DELETE FROM RECENT_SEARCHES
        WHERE id = (
            SELECT id FROM RECENT_SEARCHES
            WHERE user_id = NEW.user_id
            ORDER BY created_at ASC
            LIMIT 1
        );
    END IF;

    -- Now the new row can be inserted as normal
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION maintain_recent_searches_row_limit is 'Removes least recent search for a user_id if there are 50 or more rows with the same user_id';

CREATE TRIGGER check_recent_searches_row_limit
BEFORE INSERT ON recent_searches
FOR EACH ROW
EXECUTE FUNCTION maintain_recent_searches_row_limit();

COMMENT ON trigger check_recent_searches_row_limit ON RECENT_SEARCHES is 'Executes `maintain_recent_searches_row_limit` prior to every insert';

CREATE TABLE LINK_RECENT_SEARCH_RECORD_CATEGORIES (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recent_search_id INTEGER NOT NULL REFERENCES RECENT_SEARCHES(id) ON DELETE CASCADE,
    record_category_id INTEGER NOT NULL REFERENCES RECORD_CATEGORIES(id) ON DELETE CASCADE
);

COMMENT ON TABLE LINK_RECENT_SEARCH_RECORD_CATEGORIES IS 'Link table between recent searches and record categories searched for in that search';

INSERT INTO RECORD_CATEGORIES (name, description)
VALUES ('All', 'Pseudo-category representing all record categories');

DROP TABLE QUICK_SEARCH_QUERY_LOGS;

-- Create Expanded View of Recent Searches, including location and record category information
CREATE VIEW RECENT_SEARCHES_EXPANDED AS
SELECT
	RS.ID,
	RS.USER_ID,
	RS.LOCATION_ID,
	LE.STATE_ISO,
	LE.COUNTY_NAME,
	LE.LOCALITY_NAME,
	LE.TYPE LOCATION_TYPE,
	ARRAY_AGG(RC.NAME) AS RECORD_CATEGORIES
FROM RECENT_SEARCHES RS
INNER JOIN LOCATIONS_EXPANDED LE ON RS.LOCATION_ID = LE.ID
INNER JOIN LINK_RECENT_SEARCH_RECORD_CATEGORIES LINK ON LINK.RECENT_SEARCH_ID = RS.ID
INNER JOIN RECORD_CATEGORIES RC ON LINK.RECORD_CATEGORY_ID = RC.ID
GROUP BY
	LE.STATE_ISO,
	LE.COUNTY_NAME,
	LE.LOCALITY_NAME,
	LE.TYPE,
	RS.ID;

COMMENT ON VIEW RECENT_SEARCHES_EXPANDED IS 'Expanded view of recent searches, including location and record category information';

----------------------------------------------------------------------
-- 2024-11-03: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/388
----------------------------------------------------------------------

-- Remove default value for `API_KEY`
ALTER TABLE users ALTER COLUMN API_KEY DROP DEFAULT;

-- Update existing API keys to be SHA256 hashed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

UPDATE USERS
SET API_KEY = encode(digest(API_KEY, 'sha256'), 'hex')
WHERE API_KEY IS NOT NULL;

----------------------------------------------------------------------
-- 2024-11-06: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/504
----------------------------------------------------------------------
ALTER TYPE RECORD_TYPE ADD VALUE 'Car GPS';


----------------------------------------------------------------------------
-- 2024-11-09: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/496
-- 2024-11-09: https://github.com/Police-Data-Accessibility-Project/data-sources-app/issues/498
----------------------------------------------------------------------------

DROP VIEW DATA_SOURCES_EXPANDED;

ALTER TABLE DATA_SOURCES
ALTER COLUMN BROKEN_SOURCE_URL_AS_OF TYPE TIMESTAMP WITH TIME ZONE;

-- RECREATE DATA_SOURCES_EXPANDED VIEW
CREATE OR REPLACE VIEW public.data_sources_expanded
 AS
 SELECT ds.name,
    ds.submitted_name,
    ds.description,
    ds.source_url,
    ds.agency_supplied,
    ds.supplying_entity,
    ds.agency_originated,
    ds.agency_aggregation,
    ds.coverage_start,
    ds.coverage_end,
    ds.updated_at,
    ds.detail_level,
    ds.record_download_option_provided,
    ds.data_portal_type,
    ds.update_method,
    ds.readme_url,
    ds.originating_entity,
    ds.retention_schedule,
    ds.id,
    ds.scraper_url,
    ds.created_at,
    ds.submission_notes,
    ds.rejection_note,
    ds.last_approval_editor,
    ds.submitter_contact_info,
    ds.agency_described_submitted,
    ds.agency_described_not_in_database,
    ds.data_portal_type_other,
    ds.data_source_request,
    ds.broken_source_url_as_of,
    ds.access_notes,
    ds.url_status,
    ds.approval_status,
    ds.record_type_id,
    rt.name AS record_type_name,
    ds.access_types,
    ds.tags,
    ds.record_formats,
    ds.approval_status_updated_at
   FROM data_sources ds
     LEFT JOIN record_types rt ON ds.record_type_id = rt.id;

-- Create trigger to update BROKEN_SOURCE_URL_AS_OF when url_status is set to broken
CREATE OR REPLACE FUNCTION update_broken_source_url_as_of()
 RETURNS TRIGGER AS $$
BEGIN
    IF NEW.url_status = 'broken' THEN
        NEW.broken_source_url_as_of = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_broken_source_url_as_of
BEFORE UPDATE ON data_sources
FOR EACH ROW
EXECUTE PROCEDURE update_broken_source_url_as_of();

-- Drop record_download_option_provided
ALTER TABLE data_sources
DROP COLUMN record_download_option_provided;

-- RECREATE DATA_SOURCES_EXPANDED VIEW
CREATE OR REPLACE VIEW public.data_sources_expanded
 AS
 SELECT ds.name,
    ds.submitted_name,
    ds.description,
    ds.source_url,
    ds.agency_supplied,
    ds.supplying_entity,
    ds.agency_originated,
    ds.agency_aggregation,
    ds.coverage_start,
    ds.coverage_end,
    ds.updated_at,
    ds.detail_level,
    ds.data_portal_type,
    ds.update_method,
    ds.readme_url,
    ds.originating_entity,
    ds.retention_schedule,
    ds.id,
    ds.scraper_url,
    ds.created_at,
    ds.submission_notes,
    ds.rejection_note,
    ds.last_approval_editor,
    ds.submitter_contact_info,
    ds.agency_described_submitted,
    ds.agency_described_not_in_database,
    ds.data_portal_type_other,
    ds.data_source_request,
    ds.broken_source_url_as_of,
    ds.access_notes,
    ds.url_status,
    ds.approval_status,
    ds.record_type_id,
    rt.name AS record_type_name,
    ds.access_types,
    ds.tags,
    ds.record_formats,
    ds.approval_status_updated_at
   FROM data_sources ds
     LEFT JOIN record_types rt ON ds.record_type_id = rt.id;

-- ✅

