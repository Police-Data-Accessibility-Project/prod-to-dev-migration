import datetime
from dataclasses import dataclass

from Key import Key


@dataclass
class ObjectInfo:
    key: Key
    last_modified: datetime.datetime