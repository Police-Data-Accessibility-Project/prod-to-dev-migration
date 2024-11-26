from dataclasses import dataclass
from enum import Enum, auto


class FrequencyEnum(Enum):
    WEEKLY = auto()
    MONTHLY = auto()

@dataclass
class DirectoryConfig:
    key: str
    frequency: FrequencyEnum

    def build_full_key(self, sub_key: str):
        return f"{self.key}{sub_key}"

MonthlyDirectoryConfig = DirectoryConfig(
    key="Monthly/",
    frequency=FrequencyEnum.MONTHLY
)

WeeklyDirectoryConfig = DirectoryConfig(
    key="Weekly/",
    frequency=FrequencyEnum.WEEKLY
)
