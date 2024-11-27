import os
from datetime import datetime
from subprocess import PIPE, call

from dotenv import load_dotenv


def dump_db(connection_string: str):

    timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M-%S-%f')
    dump_file = f"prod-{timestamp}.dump"
    command = f'pg_dump --dbname={connection_string} -Fc --no-owner --no-acl --file={dump_file}'
    call(command, stdout=PIPE, shell=True)

    return dump_file

if __name__ == "__main__":
    # Get environment variables from `.env` file
    load_dotenv()
    connection_string = os.getenv("PROD_DB_CONN_STRING")
    print("Running dump...")
    file_name = dump_db(connection_string)
    print("Dump completed. File at %s" % file_name)
