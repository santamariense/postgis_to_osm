import configparser
import psycopg2
import sys
import os

def load_config(filename='my_preferences.config'):
    # Get the current script's directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Go up two directories to the project root and add the config file path
    config_path = os.path.join(script_dir, '..', '..', filename)
    
    config = configparser.ConfigParser()
    config.read(config_path)
    return config

def get_osm_file_config(config):
    osm_config = config['osm_file_config']
    return {
        'version': osm_config.get('version', '0.6'),
        'download': osm_config.get('download', 'true'),
        'upload': osm_config.get('upload', 'true'),
        'locked': osm_config.get('locked', 'false'),
        'generator': osm_config.get('generator', 'postgis_to_osm'),
        'simplify_geometry_type': osm_config.get('simplify_geometry_type', 'no')
    }

def connect_database(config, database_name):
    return psycopg2.connect(
        host=config['server_connection']['host'],
        user=config['server_connection']['user'],
        password=config['server_connection']['password'],
        dbname=database_name
    )

def update_table(conn, osm_config_data):
    with conn.cursor() as cur:
        # Delete all rows
        cur.execute("DELETE FROM postgis_to_osm.config;")
        
        # Insert new values
        cur.execute("""
            INSERT INTO postgis_to_osm.config (
                version, download, upload, locked, generator, simplify_geometry_type
            ) VALUES (%s, %s, %s, %s, %s, %s);
        """, (
            osm_config_data['version'],
            osm_config_data['download'],
            osm_config_data['upload'],
            osm_config_data['locked'],
            osm_config_data['generator'],
            osm_config_data['simplify_geometry_type'],
            #osm_config_data['var_geom'],
            #osm_config_data['var_fields']
        ))
    conn.commit()

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 update_table_config.py <databasename>")
        sys.exit(1)

    database_name = sys.argv[1]

    config = load_config()
    osm_config_data = get_osm_file_config(config)

    try:
        conn = connect_database(config, database_name)
        update_table(conn, osm_config_data)
        #print("Table postgis_to_osm.config updated successfully!")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()


def main(databasename):
    #print(f"Updating table config for {databasename}")

    database_name = databasename

    config = load_config()
    osm_config_data = get_osm_file_config(config)

    try:
        conn = connect_database(config, database_name)
        update_table(conn, osm_config_data)
        #print("Table postgis_to_osm.config updated successfully!")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    import sys
    main(sys.argv[1])  # Run main if executed directly


#if __name__ == "__main__":
#    main()


