from dataclasses import dataclass
from enum import Enum, auto

from Key import Key


class FrequencyEnum(Enum):
    WEEKLY = "weekly"
    MONTHLY = "monthly"

@dataclass
class DirectoryConfig:
    key: str
    frequency: FrequencyEnum
    directory_max: int

    def build_full_key(self, sub_key: str) -> Key:
        return Key(key=f"{self.key}/{sub_key}")

MonthlyDirectoryConfig = DirectoryConfig(
    key="Monthly",
    frequency=FrequencyEnum.MONTHLY,
    directory_max=12
)

WeeklyDirectoryConfig = DirectoryConfig(
    key="Weekly",
    frequency=FrequencyEnum.WEEKLY,
    directory_max=5
)

DIRECTORY_CONFIGS = [
    MonthlyDirectoryConfig,
    WeeklyDirectoryConfig
]

DIRECTORY_CONFIG_MAP = {
    FrequencyEnum.MONTHLY: MonthlyDirectoryConfig,
    FrequencyEnum.WEEKLY: WeeklyDirectoryConfig
}
