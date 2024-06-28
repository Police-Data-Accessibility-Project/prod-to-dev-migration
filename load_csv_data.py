import os
import re
import sys
import psycopg2
from pathlib import Path

DUMMY_DATA_DIR = 'dummy_data'

def extract_table_name_from_filename(filename):
    assert re.match(r'^\w+\.csv$', filename), \
        f'Invalid filename: {filename}. Must end with .csv and contain only letters, numbers, and underscores.'
    return filename.split('.')[0]

class DummyDataFinder:

    def __init__(self, directory):
        self.directory = directory

    def find_dummy_data_files(self) -> Path:
        """
        Generator that yields the full path of all .csv files in the directory.
        :return:
        """
        for filename in os.listdir(self.directory):
            if re.match(r'^\w+\.csv$', filename):
                yield os.path.join(self.directory, filename)

class DatabaseDataLoader:

    def __init__(self, database_string: str):
        self.connection = psycopg2.connect(database_string)

    def load_csv_to_table(self, table_name: str, csv_file_path: Path):

        cursor = self.connection.cursor()
        copy_command = f"COPY {table_name} FROM STDIN WITH CSV HEADER;"
        try:
            with open(csv_file_path, 'r') as f:
                cursor.copy_expert(copy_command, f)
            self.connection.commit()
        except psycopg2.Error as e:
            print(f'Error: {e}')
            self.connection.rollback()
        finally:
            cursor.close()

def main():

    # Get database string as first argument
    if len(sys.argv) < 2:
        print('Usage: python load_csv_data.py <database string>')
        sys.exit(1)
    database_data_loader = DatabaseDataLoader(sys.argv[1])
    dummy_data_finder = DummyDataFinder(DUMMY_DATA_DIR)

    for csv_file_path in dummy_data_finder.find_dummy_data_files():
        print(f'Loading {csv_file_path}...')
        csv_file = os.path.basename(csv_file_path)
        table_name = extract_table_name_from_filename(csv_file)
        database_data_loader.load_csv_to_table(table_name, csv_file_path)