#!/usr/bin/env python3

import configparser
import os
import sys
import psycopg2

def load_config(file_path="my_preferences.config"):
    # Find the project root directory (where my_preferences.config is located)
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    config_file_path = os.path.join(project_root, file_path)
    
    # Read the configuration file
    config = configparser.ConfigParser()
    config.read(config_file_path)
    if 'server_connection' not in config:
        raise KeyError("Missing [server_connection] section in config file.")
    return config['server_connection']

def connect_to_database(host, user, password, database):
    try:
        conn = psycopg2.connect(
            host=host,
            user=user,
            password=password,
            dbname=database
        )
        #print(f"Successfully connected to database '{database}'.")
        return conn
    except Exception as e:
        print(f"Failed to connect to database '{database}': {e}")
        sys.exit(1)

def demolish_schema(conn):
    cursor = conn.cursor()
    try:
        # SQL statement to drop the schema
        drop_schema_sql = "DROP SCHEMA IF EXISTS postgis_to_osm CASCADE;"
        #print(f"Executing: {drop_schema_sql}")
        cursor.execute(drop_schema_sql)
        conn.commit()
        #print("Schema 'postgis_to_osm' dropped successfully.")
    except Exception as e:
        print(f"Error dropping schema: {e}")
        conn.rollback()
        cursor.close()
        conn.close()
        sys.exit(1)
    cursor.close()

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 demolish_environment.py <databasename>")
        sys.exit(1)
    
    database = sys.argv[1]
    config = load_config()
    
    host = config.get('host')
    user = config.get('user')
    password = config.get('password')
    
    conn = connect_to_database(host, user, password, database)
    
    demolish_schema(conn)
    
    conn.close()


def main(databasename):
    #print(f"Demolishing postgis_to_osm schema on {databasename}")

    database = databasename
    config = load_config()
    
    host = config.get('host')
    user = config.get('user')
    password = config.get('password')
    
    conn = connect_to_database(host, user, password, database)
    
    demolish_schema(conn)
    
    conn.close()

if __name__ == "__main__":
    import sys
    main(sys.argv[1])  # Run main if executed directly


#if __name__ == "__main__":
#    main()


