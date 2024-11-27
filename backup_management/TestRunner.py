import os
import tempfile

from dotenv import load_dotenv

from BotoClient import BotoClient
from DirectoryConfig import DIRECTORY_CONFIGS
from util import get_least_recent_object


class TestRunner:

    def __init__(self, boto_client: BotoClient):
        self.boto_client = boto_client


    def populate_with_test_data(self):
        # For each directory, fill with test data until it's at directory max
        for dc in DIRECTORY_CONFIGS:
            objects = self.boto_client.get_objects(dc=dc)
            directory_count = len(objects)
            while directory_count < dc.directory_max:
                tmp = tempfile.NamedTemporaryFile(delete=False)
                tmp.close()
                self.boto_client.add_object(dc=dc, file_name=tmp.name)
                os.unlink(tmp.name)
                directory_count += 1

    def remove_least_recent_object(self):
        for dc in DIRECTORY_CONFIGS:
            objects = self.boto_client.get_objects(dc=dc)
            lr_object = get_least_recent_object(objects=objects)
            self.boto_client.delete_object(key=lr_object.key)


if __name__ == "__main__":
    load_dotenv()
    boto_client = BotoClient(
        access_key=os.getenv("DO_SPACES_ACCESS_KEY"),
        secret_key=os.getenv("DO_SPACES_SECRET_KEY")
    )
    test_runner = TestRunner(boto_client=boto_client)
    test_runner.populate_with_test_data()
    test_runner.remove_least_recent_object()