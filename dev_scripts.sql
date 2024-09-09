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
ALTER TYPE public.request_status ADD VALUE 'Ready to Start';
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
COMMENT ON COLUMN public.data_requests.withdrawn IS 'Whether the request has been withdrawn by the requester.';

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
ADD COLUMN withdrawn BOOLEAN DEFAULT FALSE;

ALTER TABLE public.data_requests
DROP COLUMN volunteers_can_contact_requestor;

COMMENT ON COLUMN public.data_requests.withdrawn IS 'Whether the request has been withdrawn by the requester.';

CREATE OR REPLACE FUNCTION update_status_on_withdrawn()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.withdrawn = FALSE AND NEW.withdrawn = TRUE THEN
        -- Update the 'status' column or any other column as needed
        NEW.request_status := public.request_status('Request withdrawn');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_status_on_withdrawn
    BEFORE UPDATE OF withdrawn
    ON public.data_requests
    FOR EACH ROW
    WHEN (OLD.withdrawn IS DISTINCT FROM NEW.withdrawn)
    EXECUTE FUNCTION public.update_status_on_withdrawn();

COMMENT ON TRIGGER update_status_on_withdrawn ON public.data_requests IS 'Updates the request_status column when the withdrawn column is updated.';

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
