import os

from dotenv import load_dotenv

from Key import Key
from BotoClient import BotoClient
from RestoreInfo import RestoreInfo
from util import drop_database, drop_connections, restore_dump


class RestoreManager:

    def __init__(self, restore_info: RestoreInfo, boto_client: BotoClient):
        self.restore_info = restore_info
        self.boto_client = boto_client


    def execute(self, key: Key):
        filename = self.restore_info.dump_filename
        self.boto_client.download_object(key=key, filename=filename)
        drop_connections(
            admin_db_conn_string=self.restore_info.admin_db_conn_string,
            target_db=self.restore_info.target_db
        )
        drop_database(
            admin_db_conn_string=self.restore_info.admin_db_conn_string,
            target_db=self.restore_info.target_db
        )
        restore_dump(
            dump_file=filename,
            target_db_conn_string=self.restore_info.target_db_conn_string
        )

if __name__ == "__main__":
    load_dotenv()
    access_key = os.getenv("DO_SPACES_ACCESS_KEY")
    secret_key = os.getenv("DO_SPACES_SECRET_KEY")
    boto_client = BotoClient(
        access_key=access_key,
        secret_key=secret_key
    )
    restore_info = RestoreInfo(
        dump_filename="file.dump",
        target_db_conn_string=os.getenv("TARGET_DB_CONN_STRING"),
        admin_db_conn_string=os.getenv("ADMIN_DB_CONN_STRING"),
        target_db=os.getenv("TARGET_DB_NAME")
    )
    restore_manager = RestoreManager(
        restore_info=restore_info,
        boto_client=boto_client
    )
    restore_manager.execute(
        key=Key(
            key=os.getenv("RESTORE_DUMP_KEY")
        )
    )




