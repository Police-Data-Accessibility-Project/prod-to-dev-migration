import os

import boto3
import botocore
from dotenv import load_dotenv

from DirectoryConfig import MonthlyDirectoryConfig, DirectoryConfig
from Key import Key
from ObjectInfo import ObjectInfo


class BotoClient:
    def __init__(
            self,
            access_key: str,
            secret_key: str,
            bucket: str = "prod-db-bucket",
            region_name: str="nyc3"
    ):
        self.client = boto3.client(
            's3',
            endpoint_url='https://nyc3.digitaloceanspaces.com',
            config=botocore.config.Config(
                s3={
                    'addressing_style': 'virtual'
                }
            ),
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region_name
        )
        self.bucket = bucket

    def ping(self):
        return self.client.list_buckets(
            MaxBuckets=10
        )

    def get_objects(self, dc: DirectoryConfig) -> list[ObjectInfo]:
        data = self.client.list_objects(
            Bucket=self.bucket,
            Prefix=dc.key,
            MaxKeys=20
        )
        objects = []
        for content in data['Contents']:
            # Ignore directory itself
            key = Key(key=content['Key'])
            if key.is_directory():
                continue
            objects.append(ObjectInfo(
                key=key,
                last_modified=content['LastModified']
            ))

        return objects

    def download_object(self, key: Key, filename: str):
        self.client.download_file(
            Bucket=self.bucket,
            Key=key.full_key,
            Filename=filename
        )
        return filename

    def add_object(self, dc: DirectoryConfig, file_name: str):
        # https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/upload_file.html#
        result = self.client.upload_file(
            Filename=file_name,
            Bucket=self.bucket,
            Key=dc.build_full_key(sub_key=file_name).full_key
        )
        print(result)

    def delete_object(self, key: Key):
        return self.client.delete_object(
            Bucket=self.bucket,
            Key=key.full_key
        )



if __name__ == "__main__":
    # Get environment variables from `.env` file
    load_dotenv()
    access_key =  os.getenv("DO_SPACES_ACCESS_KEY")
    secret_key =  os.getenv("DO_SPACES_SECRET_KEY")
    client = BotoClient(
        access_key=access_key,
        secret_key=secret_key
    )
    print(client.get_objects(
        dc=MonthlyDirectoryConfig
    ))