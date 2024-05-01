-- This script contains all scripts to update the schema in the Dev database

------------------------
-- TEST UPDATE
------------------------
CREATE TABLE IF NOT EXISTS public.migration_test
(
    test_id integer NOT NULL DEFAULT nextval('test_test_id_seq'::regclass)
)

ALTER TABLE IF EXISTS public.migration_test
    OWNER to doadmin;
