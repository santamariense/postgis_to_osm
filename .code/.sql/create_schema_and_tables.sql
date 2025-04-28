-- Create extensions
CREATE EXTENSION IF NOT EXISTS postgis; 
CREATE EXTENSION IF NOT EXISTS postgis_topology; 

-- Create SCHEMA
DROP SCHEMA IF EXISTS postgis_to_osm CASCADE;  
CREATE SCHEMA IF NOT EXISTS postgis_to_osm;  

/* OSM XML Header
<?xml version='1.0' encoding='UTF-8'?>
<osm version='0.6' download='never' upload='never' locked='true' generator='postgis_to_osm'>
Full geometries types: POINT, LINESTRING, POLYGON, MULTIPOINT, MULTILINESTRING, MULTIPOLYGON, GEOMETRYCOLLECTION
*/

-- Create TABLES - Begin
  -- Table config
  DROP TABLE IF EXISTS postgis_to_osm.config;
  CREATE TABLE postgis_to_osm.config (
    version TEXT DEFAULT '0.6',
    download TEXT DEFAULT 'true', -- values: true, false, never,
    upload TEXT DEFAULT 'true', -- values: true, false, never,
    locked TEXT DEFAULT 'false', -- values: true, false
    generator TEXT DEFAULT 'postgis_to_osm', 
    simplify_geometry_type TEXT DEFAULT 'no' -- yes, no | if yes, convert multipoint to point, 
	                                              -- | multilinestring to linestring and 
	                                              -- | multipolygon to polygon 
	                                              -- | when they contain just one item 
	                                              -- | as a way of avoiding unnecessary relations 
	                                              -- | that contain just one member
    --generated_query TEXT
	--var_geom TEXT DEFAULT 'geom', -- User can wrap it with functions if they wish
	--var_fields TEXT DEFAULT '-' -- "-" means no change has to be done
                                -- Example: 
  );
  INSERT INTO postgis_to_osm.config (version,download,upload,locked,generator,simplify_geometry_type) 
         VALUES ('0.6','true','true','false','postgis_to_osm','no');
  -- Table NODEs
    -- Create SEQUENCE for auto-generating negative IDs
	DROP SEQUENCE IF EXISTS postgis_to_osm.nodes_id_seq CASCADE;
    CREATE SEQUENCE IF NOT EXISTS postgis_to_osm.nodes_id_seq START 10000001;
  DROP TABLE IF EXISTS postgis_to_osm.nodes;
  CREATE TABLE postgis_to_osm.nodes (
    id BIGINT PRIMARY KEY DEFAULT -nextval('postgis_to_osm.nodes_id_seq'),
    action TEXT NOT NULL DEFAULT 'modify',
    visible TEXT NOT NULL DEFAULT 'true',
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    tags TEXT[][] -- k=v
  );
  -- Table WAYs
    -- Create SEQUENCE for auto-generating negative IDs
	DROP SEQUENCE IF EXISTS postgis_to_osm.ways_id_seq CASCADE;
    CREATE SEQUENCE IF NOT EXISTS postgis_to_osm.ways_id_seq START 10001;
  DROP TABLE IF EXISTS postgis_to_osm.ways;
  CREATE TABLE postgis_to_osm.ways (
    id BIGINT PRIMARY KEY DEFAULT -nextval('postgis_to_osm.ways_id_seq'),
    action TEXT NOT NULL DEFAULT 'modify',
    --visible TEXT NOT NULL DEFAULT 'true',
    nds BIGINT[], -- nd ref
    tags TEXT[][] -- k=v
  );
  -- Table RELATIONs
    -- Create SEQUENCE for auto-generating negative IDs
	DROP SEQUENCE IF EXISTS postgis_to_osm.relations_id_seq CASCADE;
    CREATE SEQUENCE IF NOT EXISTS postgis_to_osm.relations_id_seq START 101;
  DROP TABLE IF EXISTS postgis_to_osm.relations;
  CREATE TABLE postgis_to_osm.relations (
    id BIGINT PRIMARY KEY DEFAULT -nextval('postgis_to_osm.relations_id_seq'),
    action TEXT NOT NULL DEFAULT 'modify',
    --visible TEXT NOT NULL DEFAULT 'true',
    members TEXT[][], -- nd ref,
    tags TEXT[][] -- k=v
  );

