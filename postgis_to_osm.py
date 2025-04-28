#!/usr/bin/env python3

import sys
import os

# Add .code/.py to the sys.path to allow importing from that directory
script_dir = os.path.join(os.path.dirname(__file__), '.code', '.py')
sys.path.append(script_dir)

# Import the scripts
import build_environment
import update_table_config
import convert_table_to_osm_structure
import build_osm_file
import demolish_environment

def check_arguments():
    """Check if the correct number of arguments are provided."""
    if len(sys.argv) != 2:
        print("Usage: postgis_to_osm.py <databasename.schemaname.tablename>")
        sys.exit(1)
    return sys.argv[1]

def parse_argument(argument):
    """Parse the argument into databasename, schemaname, and tablename."""
    db_parts = argument.split('.')
    
    if len(db_parts) == 3:
        databasename, schemaname, tablename = db_parts
    elif len(db_parts) == 1:
        databasename = db_parts[0]
        schemaname = None
        tablename = None
    else:
        print("Invalid argument format")
        sys.exit(1)

    return databasename, schemaname, tablename

def execute_scripts(databasename, schemaname, tablename):
    """Execute the scripts sequentially with the appropriate arguments."""
    #print(f"Executing build_environment.py with {databasename}")
    build_environment.main(databasename)

    #print(f"Executing update_table_config.py with {databasename}")
    update_table_config.main(databasename)

    #print(f"Executing convert_table_to_osm_structure.py with {databasename}.{schemaname}.{tablename}")
    convert_table_to_osm_structure.main(f"{databasename}.{schemaname}.{tablename}")

    #print(f"Executing build_osm_file.py with {databasename}.{schemaname}.{tablename}")
    build_osm_file.main(f"{databasename}.{schemaname}.{tablename}")

    #print(f"Executing demolish_environment.py with {databasename}")
    demolish_environment.main(databasename)

def main():
    """Main function to handle the execution flow."""
    argument = check_arguments()
    databasename, schemaname, tablename = parse_argument(argument)
    execute_scripts(databasename, schemaname, tablename)

if __name__ == "__main__":
    main()

