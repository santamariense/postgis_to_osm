
-- LINESTRING to way
DROP FUNCTION IF EXISTS postgis_to_osm.linestring_to_way;
CREATE OR REPLACE FUNCTION postgis_to_osm.linestring_to_way(
  linestring GEOMETRY,
  fields TEXT[][]
)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
  pt GEOMETRY;
  lat_val DOUBLE PRECISION;
  lon_val DOUBLE PRECISION;
  node_id BIGINT;
  nds_list BIGINT[] := '{}';
  existing_id BIGINT;
  existing_tags TEXT[][];
  merged_tags TEXT[][];
  tag_map JSONB := '{}';
  field TEXT[];
  k TEXT;
  v TEXT;
BEGIN
  -- 1. Convert points to nodes
  FOR pt IN SELECT (dp).geom FROM ST_DumpPoints(linestring) AS dp
  LOOP
    lat_val := ROUND(ST_Y(pt)::numeric, 7);
    lon_val := ROUND(ST_X(pt)::numeric, 7);

    node_id := postgis_to_osm.point_to_node(
      ST_SetSRID(ST_MakePoint(lon_val, lat_val), 4326),
      ARRAY[]::TEXT[][]
    );

    nds_list := nds_list || node_id;
  END LOOP;

  -- 2. Check for existing way with the same nds_list
  SELECT id, tags INTO existing_id, existing_tags
  FROM postgis_to_osm.ways
  WHERE nds = nds_list
  LIMIT 1;

  IF existing_id IS NOT NULL THEN
    -- Convert existing tags to map
    FOREACH field SLICE 1 IN ARRAY existing_tags LOOP
      tag_map := tag_map || jsonb_build_object(field[1], field[2]);
    END LOOP;

    -- Merge with incoming fields
    FOREACH field SLICE 1 IN ARRAY fields LOOP
      k := field[1];
      v := field[2];
      IF tag_map ? k THEN
        IF NOT (tag_map ->> k) ILIKE '%' || v || '%' THEN
          tag_map := jsonb_set(tag_map, ARRAY[k], to_jsonb((tag_map ->> k) || ';' || v));
        END IF;
      ELSE
        tag_map := tag_map || jsonb_build_object(k, v);
      END IF;
    END LOOP;

    -- Convert back to TEXT[][]
    SELECT array_agg(ARRAY[sub.k, sub.v]) INTO merged_tags
    FROM (
      SELECT key AS k, value AS v
      FROM jsonb_each_text(tag_map)
      ORDER BY key
    ) sub;

    -- Update existing tags
    UPDATE postgis_to_osm.ways
    SET tags = merged_tags
    WHERE id = existing_id;

    RETURN existing_id;
  END IF;

  -- 3. Insert if not found
  INSERT INTO postgis_to_osm.ways (nds, tags)
  VALUES (nds_list, fields)
  RETURNING id INTO existing_id;

  RETURN existing_id;
END;
$$;



/*
-- Test LineString
SELECT postgis_to_osm.linestring_to_way( 
  ST_GeomFromText('LINESTRING(-51.154941 -29.8545727, -51.154950 -29.8545700, -51.154960 -29.8545680)', 4326),
  ARRAY[
    ARRAY['highway','residential'],
    ARRAY['name','Sample Street']
    --ARRAY['surface','unpaved']
  ]
);
*/



