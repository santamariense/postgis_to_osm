
-- MULTIPOLYGON to relation
DROP FUNCTION IF EXISTS postgis_to_osm.multipolygon_to_relation;
CREATE OR REPLACE FUNCTION postgis_to_osm.multipolygon_to_relation(
  geom geometry,
  fields TEXT[][]
) RETURNS BIGINT AS $$
DECLARE
  polygon geometry;
  polygon_id BIGINT;
  role TEXT;
  new_members TEXT[][] := ARRAY[]::TEXT[][];
  existing_id BIGINT;
  existing_tags TEXT[][];
  field_map TEXT[][];
  new_kv TEXT[];
  merged_tags TEXT[][];
  updated BOOLEAN;
  i INT;
  j INT;
  type_found BOOLEAN := FALSE;
BEGIN
  -- Initialize field_map with provided tags
  field_map := fields;

  -- Ensure 'type' field is present and correct
  FOR i IN 1..COALESCE(array_length(field_map, 1), 0) LOOP
    IF field_map[i][1] = 'type' THEN
      IF field_map[i][2] IS NULL OR field_map[i][2] = '' THEN
        field_map[i][2] := 'multipolygon';
      END IF;
      type_found := TRUE;
      EXIT;
    END IF;
  END LOOP;
  
  IF NOT type_found THEN
    field_map := field_map || ARRAY[ARRAY['type', 'multipolygon']];
  END IF;

  -- Loop through each top-level polygon
  FOR i IN 1..ST_NumGeometries(ST_Multi(geom)) LOOP
    polygon := ST_GeometryN(ST_Multi(geom), i);

    -- Process outer ring
    polygon_id := postgis_to_osm.polygon_to_way(
      ST_MakePolygon(ST_ExteriorRing(polygon)),
      ARRAY[ARRAY['','']]
    );

    role := 'outer'; -- Exterior is outer

    new_members := new_members || ARRAY[
      ARRAY['type', 'way'],
      ARRAY['ref', polygon_id::TEXT],
      ARRAY['role', role]
    ];

    -- Process interior rings (holes)
    FOR j IN 1..ST_NumInteriorRings(polygon) LOOP
      polygon_id := postgis_to_osm.polygon_to_way(
        ST_MakePolygon(ST_InteriorRingN(polygon, j)),
        ARRAY[ARRAY['','']]
      );

      role := 'inner'; -- Interiors are inner

      new_members := new_members || ARRAY[
        ARRAY['type', 'way'],
        ARRAY['ref', polygon_id::TEXT],
        ARRAY['role', role]
      ];
    END LOOP;
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


-- Test multipolygon
/*
--inner ring
SELECT postgis_to_osm.multipolygon_to_relation( 
  ST_GeomFromText('MULTIPOLYGON(((
  -51.155000 -29.854600,
  -51.155000 -29.854400,
  -51.154800 -29.854400,
  -51.154800 -29.854600,
  -51.155000 -29.854600
),(
  -51.154950 -29.854550,
  -51.154950 -29.854450,
  -51.154850 -29.854450,
  -51.154850 -29.854550,
  -51.154950 -29.854550
)))', 4326),
  ARRAY[
    --ARRAY['type','multipolygon'],
    ARRAY['name','Jungloo Woods']
  ]
);
*/

/*
SELECT postgis_to_osm.multipolygon_to_relation( 
  ST_GeomFromText('MULTIPOLYGON(
  (
    (-51.5845 -29.8543, -51.5843 -29.8543, -51.5843 -29.8541, -51.5845 -29.8541, -51.5845 -29.8543)
  ),
  (
    (-51.5849 -29.8546, -51.5847 -29.8546, -51.5847 -29.8544, -51.5849 -29.8544, -51.5849 -29.8546)
  ),
  (
    (-51.5852 -29.8548, -51.5850 -29.8548, -51.5850 -29.8546, -51.5852 -29.8546, -51.5852 -29.8548)
  )
)', 4326),
  ARRAY[
    --ARRAY['type','boundary'],
    --ARRAY['source','MM&I']
    ARRAY['old_name','Joseph`s forest']
  ]
);
*/


