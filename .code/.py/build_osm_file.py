import psycopg2
import configparser
import os
import sys

def read_config(config_file='my_preferences.config'):
    config = configparser.ConfigParser()
    
    # Get the current directory of the script
    current_directory = os.path.dirname(os.path.realpath(__file__))
    
    # Navigate two folders up
    config_file_path = os.path.join(current_directory, '..', '..', config_file)
    
    if os.path.exists(config_file_path):
        config.read(config_file_path)
    else:
        print(f"Configuration file {config_file_path} not found.")
        return None
    
    try:
        db_host = config['server_connection'].get('host', 'localhost')
        db_user = config['server_connection'].get('user', 'your_user')
        db_password = config['server_connection'].get('password', 'your_password')
        return db_host, db_user, db_password
    except KeyError as e:
        print(f"Missing configuration for {e}")
        return None

def connect_to_database(db_host, db_user, db_password, db_name):
    try:
        connection = psycopg2.connect(
            host=db_host,
            database=db_name,
            user=db_user,
            password=db_password
        )
        cursor = connection.cursor()
        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()
        #print(f"Connected to the database: {db_version[0]}")
        return connection, cursor
    except Exception as error:
        print(f"Error connecting to the database: {error}")
        return None, None

def prepare_output_folder(db_name, schema_name, table_name):
    # Navigate two folders up from the current directory
    databases_folder = os.path.join(os.getcwd(), 'databases')
    os.makedirs(databases_folder, exist_ok=True)

    db_folder = os.path.join(databases_folder, db_name)
    os.makedirs(db_folder, exist_ok=True)

    output_filename = f"{schema_name}.{table_name}.osm"
    output_filepath = os.path.join(db_folder, output_filename)

    return output_filepath

def build_osm_file(cursor, output_file_path):
    try:
        tables = ['nodes', 'ways', 'relations']
        schema = 'postgis_to_osm'

        with open(output_file_path, 'w', encoding='utf-8') as osm_file:
            # Write XML header
            osm_file.write("<?xml version='1.0' encoding='UTF-8'?>\n")

            # Fetch config information
            cursor.execute(f"SELECT * FROM {schema}.config LIMIT 1;")
            config_row = cursor.fetchone()
            config_columns = [desc[0] for desc in cursor.description]

            if config_row:
                config_data = dict(zip(config_columns, config_row))
                version = config_data.get('version', '0.6')
                download = str(config_data.get('download', 'true')).lower()
                upload = str(config_data.get('upload', 'true')).lower()
                locked = str(config_data.get('locked', 'false')).lower()
                generator = config_data.get('generator', 'postgis_to_osm')
            else:
                version = '0.6'
                download = 'true'
                upload = 'true'
                locked = 'false'
                generator = 'postgis_to_osm'

            # Write <osm> start tag
            osm_file.write(
                f"<osm version='{version}' download='{download}' upload='{upload}' locked='{locked}' generator='{generator}'>\n"
            )

            # --- Process nodes ---
            cursor.execute(f"SELECT id, action, lat, lon, tags FROM {schema}.nodes;")
            nodes = cursor.fetchall()

            for node in nodes:
                id_, action, lat, lon, tags = node

                if not tags or all(tag == ["", ""] for tag in tags):  # Check for empty or invalid tags
                    osm_file.write(f"  <node id='{id_}' action='{action}' lat='{lat}' lon='{lon}' />\n")
                else:  # Has valid tags
                    osm_file.write(f"  <node id='{id_}' action='{action}' lat='{lat}' lon='{lon}'>\n")
                    for tag_pair in tags:
                        if tag_pair and len(tag_pair) == 2 and tag_pair[0] and tag_pair[1]:  # Valid tag
                            k, v = tag_pair
                            osm_file.write(f"    <tag k='{k}' v='{v}' />\n")
                    osm_file.write("  </node>\n")

            # --- Process ways ---
            cursor.execute(f"SELECT id, action, nds, tags FROM {schema}.ways;")
            ways = cursor.fetchall()

            for way in ways:
                id_, action, nds, tags = way

                # Start writing the way
                osm_file.write(f"  <way id='{id_}' action='{action}'>\n")

                # Write all nd references
                for nd_ref in nds:
                    osm_file.write(f"    <nd ref='{nd_ref}' />\n")

                # If there are tags, write them
                if tags and any(tag != ["", ""] for tag in tags):
                    for tag_pair in tags:
                        if tag_pair and len(tag_pair) == 2 and tag_pair[0] and tag_pair[1]:  # Valid tag
                            k, v = tag_pair
                            osm_file.write(f"    <tag k='{k}' v='{v}' />\n")

                # Close the way
                osm_file.write("  </way>\n")

            # --- Process relations ---
            cursor.execute(f"SELECT id, action, members, tags FROM {schema}.relations;")
            relations = cursor.fetchall()

            for relation in relations:
                id_, action, members, tags = relation

                # Start writing the relation
                osm_file.write(f"  <relation id='{id_}' action='{action}'>\n")

                # Process members - each member is a list with 3 elements: type, ref, role
                for i in range(0, len(members), 3):
                    # Extract type, ref, and role
                    member_type = members[i][1]   # e.g., 'node', 'way', etc.
                    member_ref = members[i+1][1]  # The ref ID
                    member_role = members[i+2][1] # The role (which may be empty)

                    # Write the member element
                    osm_file.write(f"    <member type='{member_type}' ref='{member_ref}' role='{member_role}' />\n")

                # If there are tags, write them
                if tags and any(tag != ["", ""] for tag in tags):
                    for tag_pair in tags:
                        if tag_pair and len(tag_pair) == 2 and tag_pair[0] and tag_pair[1]:  # Valid tag
                            k, v = tag_pair
                            osm_file.write(f"    <tag k='{k}' v='{v}' />\n")

                # Close the relation
                osm_file.write("  </relation>\n")

            # Close <osm> tag
            osm_file.write("</osm>\n")

        #print(f"OSM file created at: {output_file_path}")

    except Exception as error:
        print(f"Error building the OSM file: {error}")

def main():
    if len(sys.argv) != 2:
        print("Usage: build_osm_file.py <databasename.schemaname.tablename>")
        sys.exit(1)
    
    db_schema_table = sys.argv[1]
    parts = db_schema_table.split('.')
    if len(parts) != 3:
        print("Invalid format. Use: databasename.schemaname.tablename")
        sys.exit(1)

    db_name, schema_name, table_name = parts
    config_params = read_config('my_preferences.config')
    if not config_params:
        sys.exit(1)
    
    db_host, db_user, db_password = config_params

    connection, cursor = connect_to_database(db_host, db_user, db_password, db_name)
    
    if connection:
        output_file_path = prepare_output_folder(db_name, schema_name, table_name)
        build_osm_file(cursor, output_file_path)
        cursor.close()
        connection.close()
        #print("Connection closed.")



def main(databasename_schemaname_tablename):
    #print(f"Updating table config for {databasename}")

    parts = databasename_schemaname_tablename.split('.')
    if len(parts) != 3:
        #print("Invalid format. Use: databasename.schemaname.tablename")
        sys.exit(1)

    db_name, schema_name, table_name = parts
    config_params = read_config('my_preferences.config')
    if not config_params:
        sys.exit(1)
    
    db_host, db_user, db_password = config_params

    connection, cursor = connect_to_database(db_host, db_user, db_password, db_name)
    
    if connection:
        output_file_path = prepare_output_folder(db_name, schema_name, table_name)
        build_osm_file(cursor, output_file_path)
        cursor.close()
        connection.close()
        #print("Connection closed.")


if __name__ == "__main__":
    import sys
    main(sys.argv[1])  # Run main if executed directly

#if __name__ == "__main__":
#    main()

