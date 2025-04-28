
-- POLYGON to relation|way | it redirects to polygon_to_way() since the decision is made there
DROP FUNCTION IF EXISTS postgis_to_osm.polygon_to_relation;
CREATE OR REPLACE FUNCTION postgis_to_osm.polygon_to_relation(
  polygon GEOMETRY,
  fields TEXT[][]
)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE

BEGIN
    -- Redirects to polygon_to_way
    RETURN postgis_to_osm.polygon_to_way(polygon, fields);
END;
$$;


/*
Example of polygon with inner ring

SELECT postgis_to_osm.polygon_to_relation( 
  ST_GeomFromText('POLYGON(
  (  
    51.154950 29.854570,
    51.164950 29.854570,
    51.164950 29.864570,
    51.154950 29.864570,
    51.154950 29.854570
  ),
  ( 
    51.157950 29.857570,
    51.161950 29.857570,
    51.161950 29.861570,
    51.157950 29.861570,
    51.157950 29.857570
  )
)', 4326),
  ARRAY[
    ARRAY['natural','wood'],
    ARRAY['name','Jungloo Woods']
  ]
);


*/


