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
        #print(f"Failed to connect to database '{database}': {e}")
        sys.exit(1)

def find_sql_files(base_dir=".sql"):
    # Use os.path.join to ensure the path is cross-platform safe
    sql_dir = os.path.join(os.path.dirname(__file__), "..", base_dir)
    sql_dir = os.path.normpath(sql_dir)  # Normalize path to handle OS-specific separator issues
    
    if not os.path.isdir(sql_dir):
        print(f"SQL directory '{sql_dir}' does not exist.")
        sys.exit(1)

    sql_files = [
        os.path.join(sql_dir, f)
        for f in os.listdir(sql_dir)
        if f.endswith(".sql")
    ]
    
    # Sort the files alphabetically by name (this ensures proper execution order)
    sql_files.sort()
    return sql_files

def run_sql_files(conn, sql_files):
    cursor = conn.cursor()
    for sql_file in sql_files:
        #print(f"Running: {sql_file}")
        try:
            with open(sql_file, 'r', encoding='utf-8') as f:
                sql = f.read()
                cursor.execute(sql)
                conn.commit()
        except Exception as e:
            print(f"Error executing '{sql_file}': {e}")
            conn.rollback()
            cursor.close()
            conn.close()
            sys.exit(1)
    cursor.close()
    #print("All SQL scripts executed successfully.")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 build_environment.py <databasename>")
        sys.exit(1)
    
    database = sys.argv[1]
    config = load_config()
    
    host = config.get('host')
    user = config.get('user')
    password = config.get('password')
    
    conn = connect_to_database(host, user, password, database)
    
    sql_files = find_sql_files()
    run_sql_files(conn, sql_files)
    
    conn.close()

def main(databasename):
    #print(f"Building environment for {databasename}")

    database = databasename
    config = load_config()
    
    host = config.get('host')
    user = config.get('user')
    password = config.get('password')
    
    conn = connect_to_database(host, user, password, database)
    
    sql_files = find_sql_files()
    run_sql_files(conn, sql_files)
    
    conn.close()

if __name__ == "__main__":
    import sys
    main(sys.argv[1])  # Run main if executed directly


#if __name__ == "__main__":
#    main()

