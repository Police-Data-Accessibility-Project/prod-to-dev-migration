import psycopg2

from RelationConfigurationManager import RelationConfiguration, RelationConfigurationManager
from helper import execute_query_with_connection, get_connection_string_from_argument, \
    setup_connection


def insert_relation_columns_to_db(
    connection: psycopg2.extensions.connection,
    relation_configuration: RelationConfiguration
):
    relation_name = relation_configuration.relation_name
    columns = relation_configuration.get_column_names()
    for column in columns:
        execute_query_with_connection(
            query=f"""
            INSERT INTO relation_column (relation, associated_column)
            VALUES ('{relation_name}', '{column}');
            """,
            connection=connection
        )

def insert_column_permissions_to_db(
    connection: psycopg2.extensions.connection,
    relation_configuration: RelationConfiguration
):
    relation_name = relation_configuration.relation_name
    columns = relation_configuration.columns.values()
    for column in columns:
        for role, access_permission in column.access_permissions.items():
            execute_query_with_connection(
                query=f"""
                INSERT INTO column_permission (rc_id, relation_role, access_permission)
                SELECT rc.id, '{role.strip()}', '{access_permission.value}'
                FROM
                    relation_column rc
                WHERE
                    relation = '{relation_name}' AND
                    associated_column = '{column.column_name}';
                """,
                connection=connection
            )
    pass

if __name__ == "__main__":
    connection_string = get_connection_string_from_argument()
    conn = setup_connection(connection_string)

    execute_query_with_connection(
        query=f"""
        DELETE FROM column_permission;
        """,
        connection=conn
    )

    execute_query_with_connection(
        query=f"""
        DELETE FROM relation_column;
        """,
        connection=conn
    )

    relation_configuration_manager = RelationConfigurationManager()
    relation_configurations = relation_configuration_manager.relation_configurations

    for relation_configuration in relation_configurations.values():
        insert_relation_columns_to_db(
            connection=setup_connection(connection_string),
            relation_configuration=relation_configuration
        )

        insert_column_permissions_to_db(
            connection=setup_connection(connection_string),
            relation_configuration=relation_configuration
        )