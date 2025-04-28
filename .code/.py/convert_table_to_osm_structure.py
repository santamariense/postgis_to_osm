import psycopg2
import configparser
import os
import sys

def read_config(config_file='my_preferences.config'):
    #print("Reading configuration...")

    # Get the path two directories above the current script
    script_dir = os.path.dirname(os.path.abspath(__file__))  # .py script's directory
    config_file_path = os.path.join(script_dir, '../../', config_file)  # Navigate two directories up

    #print(f"Looking for config file at: {config_file_path}")

    config = configparser.ConfigParser()
    
    if os.path.exists(config_file_path):
        config.read(config_file_path)
        #print(f"Configuration file {config_file} loaded.")
    else:
        print(f"Configuration file {config_file} not found at {config_file_path}.")
        return None
    
    try:
        db_host = config['server_connection'].get('host', 'localhost')
        db_user = config['server_connection'].get('user', 'your_user')
        db_password = config['server_connection'].get('password', 'your_password')
        #print(f"Config values - Host: {db_host}, User: {db_user}")
        return db_host, db_user, db_password
    except KeyError as e:
        print(f"Missing configuration for {e}")
        return None

def connect_to_database(db_host, db_user, db_password, db_name):
    #print(f"Connecting to database {db_name} at {db_host} as user {db_user}...")
    try:
        connection = psycopg2.connect(
            host=db_host,
            database=db_name,
            user=db_user,
            password=db_password
        )
        connection.autocommit = True  # Important for functions that modify data inside!
        cursor = connection.cursor()
        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()
        #print(f"Connected to the database: {db_version[0]}")
        return connection, cursor
    except Exception as error:
        print(f"Error connecting to the database: {error}")
        return None, None

def run_function(cursor, schema_name, table_name):
    full_table = f"{schema_name}.{table_name}"
    #print(f"Preparing to run function on: {full_table}")
    try:
        query = f"SELECT postgis_to_osm.psql_table_to_osm_structure('{full_table}');"
        #print(f"Running query: {query}")
        cursor.execute(query)
        try:
            result = cursor.fetchone()
            #print(f"Function executed. Result: {result}")
        except Exception as fetch_error:
            print(f"Function executed, but error fetching result: {fetch_error}")
    except Exception as e:
        print(f"Error executing the function: {e}")

def main():
    #print("Starting script...")
    if len(sys.argv) != 2:
        print("Usage: convert_table_to_osm_structure.py <databasename.schemaname.tablename>")
        sys.exit(1)
    
    db_schema_table = sys.argv[1]
    parts = db_schema_table.split('.')
    #print(f"Input parts: {parts}")

    if len(parts) != 3:
        print("Invalid format. Use: databasename.schemaname.tablename")
        sys.exit(1)

    db_name, schema_name, table_name = parts
    #print(f"Parsed - Database: {db_name}, Schema: {schema_name}, Table: {table_name}")

    config_params = read_config('my_preferences.config')
    if not config_params:
        sys.exit(1)
    
    db_host, db_user, db_password = config_params

    connection, cursor = connect_to_database(db_host, db_user, db_password, db_name)
    
    if connection and cursor:
        run_function(cursor, schema_name, table_name)
        #print("Closing cursor...")
        cursor.close()
        #print("Closing connection...")
        connection.close()
        #print("Connection closed.")
    else:
        print("Could not establish a database connection.")


def main(databasename_schemaname_tablename):
    
    parts = databasename_schemaname_tablename.split('.')

    db_name, schema_name, table_name = parts
    #print(f"Parsed - Database: {db_name}, Schema: {schema_name}, Table: {table_name}")

    config_params = read_config('my_preferences.config')
    if not config_params:
        sys.exit(1)
    
    db_host, db_user, db_password = config_params

    connection, cursor = connect_to_database(db_host, db_user, db_password, db_name)
    
    if connection and cursor:
        run_function(cursor, schema_name, table_name)
        #print("Closing cursor...")
        cursor.close()
        #print("Closing connection...")
        connection.close()
        #print("Connection closed.")
    else:
        print("Could not establish a database connection.")

if __name__ == "__main__":
    import sys
    main(sys.argv[1])  # Run main if executed directly


#if __name__ == "__main__":
#    main()

