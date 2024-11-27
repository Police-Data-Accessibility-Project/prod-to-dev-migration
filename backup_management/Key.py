import re


class Key:
    def __init__(self, key: str):

        self.full_key = key
        self.root_key = re.match(r'^([^\/]+)\/', key).group(1)
        self.sub_key = re.match(r'^([^\/]+)\/(.*)$', key).group(2)

    def __str__(self):
        return self.full_key

    def is_directory(self) -> bool:
        return self.sub_key == ""
