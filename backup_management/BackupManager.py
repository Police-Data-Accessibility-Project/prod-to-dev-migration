import os

from dotenv import load_dotenv

import DBDumper
from BotoClient import BotoClient
from DirectoryConfig import DirectoryConfig, FrequencyEnum, DIRECTORY_CONFIG_MAP
from util import get_least_recent_object


class BackupManager:

    def __init__(
            self,
            frequency: FrequencyEnum,
            connection_string: str,
            boto_client: BotoClient
    ):
        self.dc = DIRECTORY_CONFIG_MAP[frequency]
        self.connection_string = connection_string
        self.boto_client = boto_client


    def execute(self):
        self.backup(dc=self.dc)

    def backup(self, dc: DirectoryConfig):
        print("Dumping database...")
        file_name = DBDumper.dump_db(connection_string=self.connection_string)
        print("Dump completed. File at %s" % file_name)
        print("Uploading dump")
        self.boto_client.add_object(dc=dc, file_name=file_name)
        print("Cleaning up...")
        objects = self.boto_client.get_objects(dc=dc)
        if len(objects) > dc.directory_max:
            lr_object = get_least_recent_object(objects=objects)
            print(f"Removing least recent object ({lr_object.key})")
            self.boto_client.delete_object(key=lr_object.key)

if __name__ == "__main__":
    load_dotenv()

    access_key = os.getenv("DO_SPACES_ACCESS_KEY")
    secret_key = os.getenv("DO_SPACES_SECRET_KEY")
    connection_string = os.getenv("PROD_DB_CONN_STRING")
    frequency = FrequencyEnum(os.getenv("BACKUP_FREQUENCY"))
    client = BotoClient(
        access_key=access_key,
        secret_key=secret_key
    )
    backup_manager = BackupManager(
        frequency=frequency,
        connection_string=connection_string,
        boto_client=client
    )
    backup_manager.execute()

