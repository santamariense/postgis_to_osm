
# PostGIS to OSM Converter

This script (`postgis_to_osm.py`) automates the process of extracting spatial data from a PostGIS database, converting it into OpenStreetMap (OSM) XML structure, and generating an `.osm` file, that can be opened on JOSM.

## ⚠️ CAUTION

Never run this script in a database that already contains a schema named `postgis_to_osm`.
If such a schema exists by coincidence, **rename it before executing the script**.

The script automatically creates a temporary schema called `postgis_to_osm` where it builds the OSM file structure.
Failing to rename an existing schema may lead to data loss or overwrite issues.

---

## Execution Flow

The script executes the following functions in order:

1. Sets up temporary structures and environments required for the conversion process, such as temporary tables and schemas.

2. Reads the `my_preferences.config` file to determine the configuration settings for each table or feature class during the conversion.

3. Transforms the queried PostGIS table data into an in-memory OSM-like object structure (nodes, ways, relations) that can be serialized into an OSM file.

4. Serializes the in-memory OSM structure into a properly formatted `.osm` XML file, openable on JOSM.

5. Cleans up any temporary database objects created during the environment setup phase.

---

## Configuration (`my_preferences.config`)

There is a file called `my_preferences.config` where the user can customize output settings, including server connection configurations and behavior of the conversion.

### Example Configuration:

```ini
[server_connection]
host = localhost
user = postgres
password = postgres

[osm_file_config]
version = 0.6
download = true
upload = true
locked = false
generator = postgis_to_osm
simplify_geometry_type = no
var_geom = geom
var_fields = -
```

### Configuration Sections:

#### [server_connection]
- **host**: Hostname or IP address of the PostgreSQL server.
- **user**: Username to connect to the database.
- **password**: Password for the database user.

#### [osm_file_config]
- **version**: The OSM XML version (typically 0.6).
- **download**: Whether to download the OSM data. Possible values: true, false
- **upload**: Whether to upload the OSM data. Possible values: true, false, never
- **locked**: Whether the OSM file is locked (editable). Possible values: true, false
- **generator**: The name of the script generating the OSM file. In this case, `postgis_to_osm`
- **simplify_geometry_type**: Simplifies geometries based on their type. Possible values: `yes` or `no`. If set to `yes`, geometries of type `multipolygon`, `multilinestring`, and `multipoint` will be simplified to `polygon`, `linestring`, and `point` respectively, provided that these geometries contain only a single "sub-geometry". This helps avoid the creation of unnecessary relations in the final OSM file. Note: This option is an additional safeguard against malformed geometries that should ideally be corrected beforehand.
- **var_geom**: Not in use
- **var_fields**: Not in use

---

## Prerequisites

- Python 3+
- PostgreSQL database with PostGIS extension
- Required Python packages:
- `psycopg2` for PostgreSQL connection


---

## How to Run

1. Make sure you have the `postgis_to_osm.py` script.
2. Edit `my_preferences.config` that is in the same directory as the script and adjust the configuration parameters as needed.
3. Ensure your PostGIS database is set up with the required tables and populated with the fields and geometry you wish to convert.
4. Run the script using the following command, replacing `<database_name>`, `<schema_name>`, and `<table_name>` with your actual database details:

```bash
python3 postgis_to_osm.py <database_name>.<schema_name>.<table_name>
```

The output `.osm` file will be created in the working directory under `databases/<database_name>/<schema_name>.<table_name>.osm`.

---

## Contributing

Contributions are welcome!
If you have suggestions for improvements, bug fixes, or new features, feel free to open an issue or submit a pull request.

Thank you for helping improve this project!

---

## To-Do / Next Steps

- [ ] **Handle long ways**
Split ways with more than 2,000 points into two or more ways due to OSM upload limitations.
If the original geometry is a polygon, convert it into a multipolygon relation with the new ways as members.

- [ ] **Support border deduplication via multipolygons**
Add an option to convert overlapping border ways into multipolygons (way -> relation).
These multipolygons should share the common border segment as a member to reduce duplication and ensure OSM consistency.

---

## License

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.
By contributing to this project, you agree that your contributions may be re-licensed under a different open-source license in the future, if necessary for the project's evolution or broader adoption.
Suggestions for changing the license are welcome, as long as they are accompanied by clear reasoning or arguments.

