
-- Convert a table to osm structure and return TRUE if no exception occurs
DROP FUNCTION IF EXISTS postgis_to_osm.psql_table_to_osm_structure;
CREATE OR REPLACE FUNCTION postgis_to_osm.psql_table_to_osm_structure(
   psql_table TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
   v_schema TEXT;
   v_table  TEXT;
   v_exists BOOLEAN;
   v_field RECORD;
   v_values_list TEXT := '';
   v_query TEXT;
BEGIN
   -- Split schema and table
   IF strpos(psql_table, '.') > 0 THEN
       v_schema := split_part(psql_table, '.', 1);
       v_table  := split_part(psql_table, '.', 2);
   ELSE
       v_schema := 'public';
       v_table  := psql_table;
   END IF;
   RAISE NOTICE 'v_schema , v_table = %.%',v_schema,v_table;
   -- Check if table exists
   SELECT EXISTS (
       SELECT 1
       FROM information_schema.tables
       WHERE table_schema = v_schema
         AND table_name = v_table
   ) INTO v_exists;

   IF NOT v_exists THEN
       RAISE EXCEPTION 'Table "%" does not exist in schema "%".', v_table, v_schema;
   END IF;

   -- Build the VALUES part: skip geometry columns
   FOR v_field IN
       SELECT column_name, data_type
       FROM information_schema.columns
       WHERE table_schema = v_schema
         AND table_name = v_table
         AND data_type NOT IN ('USER-DEFINED', 'geometry', 'geography') -- Skip geometry types
   LOOP
       v_values_list := v_values_list || format(
           '(%L, %I::TEXT), ',
           v_field.column_name, v_field.column_name
       );
   END LOOP;

   -- Remove the trailing comma and space
   v_values_list := regexp_replace(v_values_list, ', $', '');

   -- Construct the final dynamic query
   v_query := format(
      'SELECT postgis_to_osm.geometry_to_osm(
          geom,
          ARRAY(
              SELECT ARRAY[field, value]
              FROM (
                  VALUES
                  %s
              ) AS fields(field, value)
              WHERE value IS NOT NULL AND value <> ''''
          )
      )
      FROM %I.%I;',
    v_values_list, v_schema, v_table
   );

   RAISE NOTICE 'v_query = %',v_query;

   -- Execute the query
   EXECUTE v_query;

   -- Return TRUE if no exception occurs
   RETURN TRUE;

EXCEPTION
   -- Catch any exception and return FALSE
   WHEN OTHERS THEN
      RETURN FALSE;
END;
$$;


/*
=======================  QUERY FORMATING  ============================

SELECT postgis_to_osm.geometry_to_osm(
  geom,
  ARRAY(
    SELECT ARRAY[field, value]
    FROM (
      VALUES
        ('cd_setor', cd_setor::TEXT),
        ('nm_log', nm_log::TEXT),
        ('tot_geral', tot_geral::TEXT)
    ) AS fields(field, value)
    WHERE value IS NOT NULL AND value <> ''
  )
 ) 
FROM public.faces_de_logradouros LIMIT 11;
*/






-- Test zone
--SELECT postgis_to_osm.psql_table_to_osm_structure('public._recorte_faces_de_logradouros');


