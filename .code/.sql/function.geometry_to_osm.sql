
-- Detects geometry and redirects to correct function
DROP FUNCTION IF EXISTS postgis_to_osm.geometry_to_osm;
CREATE OR REPLACE FUNCTION postgis_to_osm.geometry_to_osm(
  geom geometry,
  fields TEXT[][]
) RETURNS BIGINT AS $$
DECLARE
  geom_simplified_or_not GEOMETRY;
  geom_srid4326 GEOMETRY;
  geom_type TEXT;
  simplify_gt TEXT DEFAULT 'no';
BEGIN

  -- Simplify or not simplify geometry type
  SELECT lower(simplify_geometry_type) INTO simplify_gt
  FROM postgis_to_osm.config
  LIMIT 1;

  --RAISE NOTICE 'geom = %',ST_AsText(geom);

  geom_simplified_or_not = CASE
      WHEN simplify_gt = 'yes' THEN postgis_to_osm.simplify_multi(geom)
      ELSE geom
  END;
  
  geom_srid4326 = CASE
      WHEN ST_SRID(geom_simplified_or_not) = 4326 THEN geom_simplified_or_not
      ELSE ST_Transform(geom_simplified_or_not, 4326)
  END;

  geom_type := ST_GeometryType(geom_srid4326);

  --RAISE NOTICE 'geom_type = %',geom_type;

  CASE geom_type
    WHEN 'ST_Point' THEN
      RETURN postgis_to_osm.point_to_node(geom_srid4326, fields);

    WHEN 'ST_LineString' THEN
      RETURN postgis_to_osm.linestring_to_way(geom_srid4326, fields);

    WHEN 'ST_Polygon' THEN
      RETURN postgis_to_osm.polygon_to_way(geom_srid4326, fields);

    WHEN 'ST_MultiPoint' THEN
      RETURN postgis_to_osm.multipoint_to_relation(geom_srid4326, fields);

    WHEN 'ST_MultiLineString' THEN
      RETURN postgis_to_osm.multilinestring_to_relation(geom_srid4326, fields);

    WHEN 'ST_MultiPolygon' THEN
      RETURN postgis_to_osm.multipolygon_to_relation(geom_srid4326, fields);

    WHEN 'ST_GeometryCollection' THEN
      RETURN postgis_to_osm.geometrycollection_to_relation(geom_srid4326, fields);

    ELSE
      --RAISE EXCEPTION 'Unsupported geometry type: %', geom_type;
	  RETURN NULL;
  END CASE;
END;
$$ LANGUAGE plpgsql;


-- Test Zone
/*
SELECT 
postgis_to_osm.geometry_to_osm(
 ST_GeometryFromText('
MULTILINESTRING((-47.7628302820967 -15.6478987267765,-47.7631625722526 -15.6483461784742,-47.7629693860279 -15.6485453804497,-47.763102240508 -15.6486506849182,-47.7632050536604 -15.6485741728048,-47.7633102578164 -15.6484594046346,-47.764642046791 -15.6491336676343,-47.7647639879718 -15.6488897852727,-47.7633641443741 -15.6481794521709,-47.7633410799932 -15.648147676377,-47.763291533729 -15.6480762125353,-47.7630273063807 -15.6477774437557,-47.7628283282841 -15.6479026344017))', 4326)
,ARRAY[ARRAY['','']]::TEXT[][]);
--*/

