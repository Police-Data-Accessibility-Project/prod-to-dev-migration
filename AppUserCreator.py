"""
Creates a user in the database with given permissions, and setting a specific password
"""
import argparse
import hashlib
import json
import uuid
from typing import Optional

from werkzeug.security import generate_password_hash

from DBInterface import DBInterface


class AppUserCreator(DBInterface):
    def __init__(
            self,
            admin_db_conn_string,
            user_email,
            user_password,
            api_key: Optional[str]
    ):
        super().__init__(
            admin_db_conn_string=admin_db_conn_string,
        )
        self.user_email = user_email
        self.user_password = user_password
        self.user_id = self.insert_user(user_email, user_password)
        self.api_key = api_key
        if self.api_key is not None:
            self.insert_api_key(self.user_id, self.api_key)

    def hash_password(self, password):
        return generate_password_hash(password)

    def insert_user(self, user_email, user_password):
        """
        Insert user into `Users` table and return user_id
        :return:
        """
        password_digest = self.hash_password(user_password)
        query = f"""
        INSERT INTO USERS (email, password_digest) 
        VALUES ('{user_email}', '{password_digest}')
        RETURNING id;
        """
        result = self._execute_query(query)
        print(f"Created user with id {result[0][0]}")
        return result[0][0]

    def insert_api_key(self, user_id, api_key):
        raw_key = api_key
        hashed_key = hashlib.sha256(raw_key.encode()).hexdigest()
        query = f"""
        UPDATE USERS SET api_key = '{hashed_key}' WHERE id = {user_id};
        """
        self._execute_query(query)


    def insert_permission(self, user_id, permission: str):
        permission_id = self.get_permission_id(permission)

        query = f"""
        INSERT INTO user_permissions (user_id, permission_id) 
        VALUES ({user_id}, {permission_id});
        """
        self._execute_query(query)

    def get_permission_id(self, permission: str):
        query = f"""
        SELECT permission_id FROM permissions WHERE permission_name = '{permission}';
        """
        result = self._execute_query(query)
        return result[0][0]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create or update app user in target database"
    )

    parser.add_argument("--admin_db_conn_string", type=str, help="Admin database connection string")
    parser.add_argument("--user_config_file", type=str, help="User config file")
    args = parser.parse_args()

    admin_db_conn_string = args.admin_db_conn_string
    user_config_file = args.user_config_file

    with open(user_config_file, "r") as f:
        user_config = json.load(f)

    users = user_config['users']
    for user in users:
        user_email = user["email"]
        user_password = user["password"]
        api_key = user["api_key"]
        app_user_creator = AppUserCreator(
            admin_db_conn_string=admin_db_conn_string,
            user_email=user_email,
            user_password=user_password,
            api_key=api_key
        )