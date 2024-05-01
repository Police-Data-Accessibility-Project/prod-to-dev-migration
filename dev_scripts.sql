-- This script contains all scripts to update the schema in the Dev database

------------------------
-- TEST UPDATE
------------------------
CREATE TABLE IF NOT EXISTS public.test
(
    id integer NOT NULL DEFAULT nextval('test_id_seq'::regclass)
)
