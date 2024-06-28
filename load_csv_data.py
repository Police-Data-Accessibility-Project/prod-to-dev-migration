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
    database_string = sys.argv[1]

    for csv_file in os.listdir(DUMMY_DATA_DIR):
        if not csv_file.endswith('.csv'):
            continue

        print(f'Loading {csv_file}...')
        table_name = extract_table_name_from_filename(csv_file)
        csv_file_path = os.path.join(DUMMY_DATA_DIR, csv_file)
        with open(os.path.join(DUMMY_DATA_DIR, csv_file)) as f:
            print(f.read())
