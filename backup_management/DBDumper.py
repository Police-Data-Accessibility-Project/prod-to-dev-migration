import os
from datetime import datetime
from subprocess import PIPE, Popen

from dotenv import load_dotenv


def dump_db(connection_string: str):

    timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M-%S-%f')
    dump_file = f"prod-{timestamp}.dump"
    command = f'pg_dump "{connection_string}" -Fc --no-owner --no-acl --file={dump_file}'

    proc = Popen(command, stdout=PIPE)
    proc.wait()

    return dump_file

if __name__ == "__main__":
    # Get environment variables from `.env` file
    load_dotenv()
    connection_string = os.getenv("PROD_DB_CONN_STRING")
    dump_db(connection_string)