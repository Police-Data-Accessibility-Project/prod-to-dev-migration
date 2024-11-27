import subprocess
import sys

from ObjectInfo import ObjectInfo


def get_least_recent_object(objects: list[ObjectInfo]) -> ObjectInfo:
    return min(objects, key=lambda o: o.last_modified)


# TODO: The below is redundant with components of `rebuild_db.py`, and this should be cleaned up at some point
def run_command(command: str):
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        sys.exit(result.returncode)
    return result.stdout.strip()

def drop_connections(admin_db_conn_string: str, target_db: str):
    print(f"Dropping all connections to the {target_db} database...")
    run_command(
        f"psql -d {admin_db_conn_string} -c \"SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '{target_db}' AND pid <> pg_backend_pid();\"")
    connections = run_command(
        f"psql {admin_db_conn_string} -t -c \"SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '{target_db}';\"").replace(
        ' ', '')
    if connections == "0":
        print(f"All connections to the database '{target_db}' have been successfully terminated.")
    else:
        print(f"There are still active connections to the database '{target_db}'. Cancelling")
        sys.exit(1)

def drop_database(admin_db_conn_string: str, target_db: str):
    print("Dropping the database...")
    run_command(f"psql -d {admin_db_conn_string} -c \"DROP DATABASE IF EXISTS {target_db};\"")
    db_exists = run_command(
        f"psql {admin_db_conn_string} -t -c \"SELECT 1 FROM pg_database WHERE datname = '{target_db}';\"").replace(' ',
                                                                                                                   '')
    if db_exists == "":
        print(f"The database '{target_db}' has been successfully dropped.")
    else:
        print(f"Failed to drop the database '{target_db}'.")
        sys.exit(1)

def restore_dump(dump_file: str, target_db_conn_string: str):
    print("Restoring dump to database via pg_restore...")
    run_command(f"pg_restore --dbname={target_db_conn_string} -v --no-acl --no-comments --no-owner < {dump_file}")
