import argparse

import psycopg2

from DBInterface import DBInterface


class UserCreator(DBInterface):
    def __init__(self, admin_db_conn_string, dev_db_user, dev_db_password, target_db):
        super().__init__(
            admin_db_conn_string=admin_db_conn_string,
        )
        self.dev_db_user = dev_db_user
        self.dev_db_password = dev_db_password
        self.target_db = target_db

    def create_or_update_user(self):
        query = f"""
        DO $$
        BEGIN
            IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '{self.dev_db_user}') THEN
                ALTER ROLE {self.dev_db_user} WITH LOGIN PASSWORD '{self.dev_db_password}';
            ELSE
                CREATE ROLE {self.dev_db_user} LOGIN PASSWORD '{self.dev_db_password}';
            END IF;
        END
        $$;
        """
        self._execute_query(query, {'dev_db_user': self.dev_db_user, 'dev_db_password': self.dev_db_password})



    def grant_user_privileges(self):
        privileges_queries = [
            f"GRANT CONNECT ON DATABASE {self.target_db} TO {self.dev_db_user};",
            f"GRANT USAGE ON SCHEMA public TO {self.dev_db_user};",
            f"GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO {self.dev_db_user};",
            f"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {self.dev_db_user};",
            f"GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO {self.dev_db_user};",
            f"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO {self.dev_db_user};",
            f"GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO {self.dev_db_user};",
            f"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO {self.dev_db_user};",
            f"GRANT ALL ON PROCEDURE refresh_typeahead_locations TO {self.dev_db_user};"
            f"GRANT ALL ON PROCEDURE refresh_typeahead_agencies TO {self.dev_db_user};"
            f"GRANT ALL ON PROCEDURE refresh_distinct_source_urls TO {self.dev_db_user};"
        ]

        for query in privileges_queries:
            self._execute_query(query, query_msg=f"{query[0:25]}...")

    def grant_developer_privileges(self):
        privileges_queries = [
            f"GRANT {dev_db_user} TO doadmin;",
            f"GRANT CREATE ON SCHEMA public TO {dev_db_user};",
            # Grant ownership of tables.
            f"""
            DO
            $$
            DECLARE
                r RECORD;
            BEGIN
                FOR r IN (SELECT tablename FROM pg_tables WHERE tableowner = 'doadmin') LOOP
                    EXECUTE 'ALTER TABLE ' || quote_ident(r.tablename) || ' OWNER TO {dev_db_user}';
                END LOOP;
            END
            $$;
            """
        ]
        for query in privileges_queries:
            self._execute_query(query, query_msg=f"{query[0:25]}...")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create or update database user in target database"
    )

    parser.add_argument("--admin_db_conn_string", type=str, help="Admin database connection string")
    parser.add_argument("--dev_db_user", type=str, help="Developer database user")
    parser.add_argument("--dev_db_password", type=str, help="Developer database password")
    parser.add_argument("--target_db", type=str, help="Target database")

    parser.add_argument("--developer_privileges", action="store_true", help="Grant developer privileges")

    args = parser.parse_args()

    admin_db_conn_string = args.admin_db_conn_string
    dev_db_user = args.dev_db_user
    dev_db_password = args.dev_db_password
    target_db = args.target_db

    user_creator = UserCreator(
        admin_db_conn_string=admin_db_conn_string,
        dev_db_user=dev_db_user,
        dev_db_password=dev_db_password,
        target_db=target_db)
    user_creator.create_or_update_user()
    user_creator.grant_user_privileges()
    if args.developer_privileges:
        user_creator.grant_developer_privileges()
