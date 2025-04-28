
-- MULTIPOINT to relation
DROP FUNCTION IF EXISTS postgis_to_osm.multipoint_to_relation;
CREATE OR REPLACE FUNCTION postgis_to_osm.multipoint_to_relation(
  geom geometry,
  fields TEXT[][]
) RETURNS BIGINT AS $$
DECLARE
  point_geometry geometry;
  point_id BIGINT;
  new_members TEXT[][] := ARRAY[]::TEXT[][];
  existing_id BIGINT;
  existing_tags TEXT[][];
  field_map TEXT[][];
  new_kv TEXT[];
  merged_tags TEXT[][];
  updated BOOLEAN;
  i INT;
  type_found BOOLEAN := FALSE;
  num_geometries INT;
BEGIN
  -- Initialize field_map with provided tags
  field_map := fields;

  -- Ensure 'type' field is present and correct
  FOR i IN 1..COALESCE(array_length(field_map, 1), 0) LOOP
    IF field_map[i][1] = 'type' THEN
      IF field_map[i][2] IS NULL OR field_map[i][2] = '' THEN
        field_map[i][2] := 'collection'; -- Always 'collection' for point collections
      END IF;
      type_found := TRUE;
      EXIT;
    END IF;
  END LOOP;
  
  IF NOT type_found THEN
    field_map := field_map || ARRAY[ARRAY['type', 'collection']];
  END IF;

  -- Check the number of geometries (points in the collection)
  num_geometries := ST_NumGeometries(geom);
  IF num_geometries IS NULL OR num_geometries = 0 THEN
    RAISE EXCEPTION 'Geometry must contain at least one point.';
  END IF;

  -- Loop through each point in the geometry collection
  FOR i IN 1..num_geometries LOOP
    point_geometry := ST_GeometryN(geom, i);

    -- Use point_to_node function to insert and retrieve ID for each point
    point_id := postgis_to_osm.point_to_node(
      point_geometry,
      ARRAY[ARRAY['','']]
    );

    -- Append member info as array of [key, value] pairs
    new_members := new_members || ARRAY[
      ARRAY['type', 'node'],
      ARRAY['ref', point_id::TEXT],
      ARRAY['role', ''] -- No role detection for points
    ];
  END LOOP;

  -- Check if a relation with the same members already exists (order does not matter)
  SELECT id, tags INTO existing_id, existing_tags
  FROM postgis_to_osm.relations
  WHERE (
    SELECT array_agg(m ORDER BY m) FROM unnest(members) AS m
  ) = (
    SELECT array_agg(nm ORDER BY nm) FROM unnest(new_members) AS nm
  )
  LIMIT 1;

  IF existing_id IS NULL THEN
    -- Insert new relation and return its ID
    INSERT INTO postgis_to_osm.relations (members, tags)
    VALUES (new_members, field_map)
    RETURNING id INTO existing_id;
  ELSE
    -- Smart merge field_map into existing_tags
    merged_tags := existing_tags;

    FOREACH new_kv SLICE 1 IN ARRAY field_map LOOP
      updated := FALSE;
      FOR i IN 1..COALESCE(array_length(merged_tags, 1), 0) LOOP
        IF merged_tags[i][1] = new_kv[1] THEN
          -- If the key already exists
          IF NOT EXISTS (
            SELECT 1
            FROM unnest(string_to_array(merged_tags[i][2], ';')) AS val
            WHERE val = new_kv[2]
          ) THEN
            merged_tags[i][2] := merged_tags[i][2] || ';' || new_kv[2];
          END IF;

          -- Always sort merged values
          merged_tags[i][2] := (
            SELECT string_agg(val, ';' ORDER BY val)
            FROM unnest(string_to_array(merged_tags[i][2], ';')) AS val
          );

          updated := TRUE;
          EXIT;
        END IF;
      END LOOP;

      IF NOT updated THEN
        -- If key not found, add new
        merged_tags := merged_tags || ARRAY[new_kv];
      END IF;
    END LOOP;

    -- Update only if tags have changed
    IF merged_tags IS DISTINCT FROM existing_tags THEN
      UPDATE postgis_to_osm.relations
      SET tags = merged_tags
      WHERE id = existing_id;
    END IF;
  END IF;

  -- Return the relation ID (existing or newly inserted)
  RETURN existing_id;
END;
$$ LANGUAGE plpgsql;


/*
-- Test zone
SELECT postgis_to_osm.multipoint_to_relation( 
  ST_GeomFromText('MULTIPOINT(
  (51.155950 29.855570),
  (51.157950 29.856570),
  (51.159950 29.857570)
)
', 4326),
  ARRAY[
    ARRAY['type','bar'],
    ARRAY['name','MultiPoint Bar'],
    ARRAY['amenity','bar']
  ]
);
*/


