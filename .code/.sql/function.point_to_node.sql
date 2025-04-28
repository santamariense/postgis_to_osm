-- POINT to node
DROP FUNCTION IF EXISTS postgis_to_osm.point_to_node;
CREATE OR REPLACE FUNCTION postgis_to_osm.point_to_node(point GEOMETRY, fields TEXT[][])
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
  lat_val DOUBLE PRECISION := ROUND(ST_Y(point)::numeric, 7);
  lon_val DOUBLE PRECISION := ROUND(ST_X(point)::numeric, 7);
  normalized_fields JSONB := (
    SELECT jsonb_agg(f ORDER BY f)
    FROM unnest(fields) AS f
  );
  node_id BIGINT;
BEGIN
  IF array_length(fields, 1) IS NULL THEN
    -- tags are empty
    SELECT id INTO node_id
    FROM postgis_to_osm.nodes
    WHERE lat = lat_val AND lon = lon_val
      AND (tags IS NULL OR array_length(tags, 1) IS NULL)
    LIMIT 1;

    IF NOT FOUND THEN
      INSERT INTO postgis_to_osm.nodes (lat, lon, tags)
      VALUES (lat_val, lon_val, '{}')
      RETURNING id INTO node_id;
    END IF;
  ELSE
    -- tags are not empty
    SELECT id INTO node_id
    FROM postgis_to_osm.nodes
    WHERE lat = lat_val AND lon = lon_val
      AND (
        SELECT jsonb_agg(f ORDER BY f)
        FROM unnest(tags) AS f
      ) = normalized_fields
    LIMIT 1;

    IF NOT FOUND THEN
      INSERT INTO postgis_to_osm.nodes (lat, lon, tags)
      VALUES (lat_val, lon_val, fields)
      RETURNING id INTO node_id;
    END IF;
  END IF;

  RETURN node_id;
END;
$$;


/*
-- Test Point
SELECT postgis_to_osm.point_to_node( 
        ST_GeometryFromText('POINT(-51.15494097504 -29.85457274247)', 4326 ),
	    ARRAY[ARRAY['amenity','bar'],ARRAY['name','Foo Bar']]
		--ARRAY[]::TEXT[][]
	 );
*/


