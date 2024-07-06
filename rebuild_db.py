import subprocess
import os
import sys


def run_command(command):
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        sys.exit(result.returncode)
    return result.stdout.strip()


def main(admin_db_conn_string, stg_db_conn_string, dump_file, target_db):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    drop_connections(admin_db_conn_string, target_db)

    drop_database(admin_db_conn_string, target_db)

    create_database(admin_db_conn_string, target_db)

    restore_dump(dump_file, stg_db_conn_string)

    add_dev_schemas(stg_db_conn_string)


def drop_connections(admin_db_conn_string, target_db):
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


def add_dev_schemas(stg_db_conn_string):
    print("Adding development schemas to database...")
    run_command(f"psql {stg_db_conn_string} < dev_scripts.sql")


def restore_dump(dump_file, stg_db_conn_string):
    if dump_file.endswith(".sql"):
        print("Restoring dump to database via psql...")
        run_command(f"psql {stg_db_conn_string} < {dump_file}")
    else:
        print("Restoring dump to database via pg_restore...")
        run_command(f"pg_restore --dbname={stg_db_conn_string} -v --no-acl --no-comments --no-owner < {dump_file}")


def create_database(admin_db_conn_string, target_db):
    print("Creating database...")
    run_command(f"psql -d {admin_db_conn_string} -c \"CREATE DATABASE {target_db};\"")


def drop_database(admin_db_conn_string, target_db):
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


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python script.py <admin_db_conn_string> <stg_db_conn_string> <dump_file> <target_db>")
        sys.exit(1)
    print("Running rebuild_db.py script...")

    admin_db_conn_string = sys.argv[1]
    stg_db_conn_string = sys.argv[2]
    dump_file = sys.argv[3]
    target_db = sys.argv[4]

    main(admin_db_conn_string, stg_db_conn_string, dump_file, target_db)
