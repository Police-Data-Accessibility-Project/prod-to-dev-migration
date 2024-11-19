import psycopg2
from psycopg2 import ProgrammingError


class DBInterface:

    def __init__(self, admin_db_conn_string):
        self.admin_db_conn_string = admin_db_conn_string

    def _execute_query(self, query, params=None, query_msg: str = ""):
        conn = None
        try:
            conn = psycopg2.connect(self.admin_db_conn_string)
            conn.autocommit = False
            cur = conn.cursor()
            cur.execute(query, params)
            try:
                result = cur.fetchall()
            except ProgrammingError:
                result = None
            conn.commit()
            cur.close()
        except Exception as error:
            print(f"Error executing query '{query_msg}': {type(error).__name__}: {str(error)}")
            exit(1)

        finally:
            if conn is not None:
                conn.close()

        return result