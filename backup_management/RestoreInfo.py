from dataclasses import dataclass

@dataclass
class RestoreInfo:
    dump_filename: str
    target_db_conn_string: str
    admin_db_conn_string: str
    target_db: str
