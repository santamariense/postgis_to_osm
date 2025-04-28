
-- POLYGON to way|relation 
DROP FUNCTION IF EXISTS postgis_to_osm.polygon_to_way;
CREATE OR REPLACE FUNCTION postgis_to_osm.polygon_to_way(
  polygon GEOMETRY,
  fields TEXT[][]
)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
  num_interior INT;
BEGIN
  -- Count the number of interior rings (holes)
  num_interior := ST_NumInteriorRings(polygon);

  IF num_interior = 0 THEN
    -- No interior rings: treat as simple linestring
    RETURN postgis_to_osm.linestring_to_way(polygon, fields);
  ELSE
    -- Has interior rings: treat as multipolygon relation
    RETURN postgis_to_osm.multipolygon_to_relation(ST_Multi(polygon), fields);
  END IF;
END;
$$;

/*
-- Test polygon
SELECT postgis_to_osm.polygon_to_way( 
  ST_GeomFromText('POLYGON((
  -51.154950 -29.854570,
  -51.154950 -29.854470,
  -51.154850 -29.854470,
  -51.154850 -29.854570,
  -51.154950 -29.854570
))', 4326),
  ARRAY[
    ARRAY['natural','wood'],
    ARRAY['name','Jungloo Woods']
  ]
);
*/
