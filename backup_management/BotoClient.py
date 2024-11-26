import os

import boto3
import botocore
from dotenv import load_dotenv


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

    def get_objects(self, key: str = ""):
        return self.client.list_objects(
            Bucket=self.bucket,
            Prefix=key,
            MaxKeys=20
        )

    def add_object(self, key: str, file_path: str):
        return self.client.upload_file(file_path, self.bucket, key)

    def delete_object(self, key: str):
        return self.client.delete_object(
            Bucket=self.bucket,
            Key=key
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
    print(client.get_objects())