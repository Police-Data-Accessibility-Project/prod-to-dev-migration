import argparse

from DBInterface import DBInterface


class DataCleaner(DBInterface):
    """
    The DataCleaner helps sanitize data for publishing in Stage.
    It does this by anonymizing user data
    """

    def anonymize_user_data(self):
        query = """
        UPDATE users
        SET 
            email = 'user_' || id || '@example.com',
            api_key = 'REDACTED',
            password_digest = 'REDACTED'
        """
        self._execute_query(query)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Sanitize data for publishing in Stage"
    )

    parser.add_argument("--admin_db_conn_string", type=str, help="Admin database connection string")
    args = parser.parse_args()

    admin_db_conn_string = args.admin_db_conn_string

    data_cleaner = DataCleaner(admin_db_conn_string)
    data_cleaner.anonymize_user_data()