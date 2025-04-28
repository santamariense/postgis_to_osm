
-- Simplify multi to simple geometries when they contain just one item
DROP FUNCTION IF EXISTS postgis_to_osm.simplify_multi;
CREATE OR REPLACE FUNCTION postgis_to_osm.simplify_multi(geom geometry)
RETURNS geometry AS $$
BEGIN
    --RAISE NOTICE 'GeometryType(geom) = %', GeometryType(geom);
    IF geom IS NULL THEN
        RETURN NULL;
    ELSIF GeometryType(geom) = 'MULTIPOINT' AND ST_NumGeometries(geom) = 1 THEN
        RETURN ST_GeometryN(geom, 1);
    ELSIF GeometryType(geom) = 'MULTILINESTRING' AND ST_NumGeometries(geom) = 1 THEN
        RETURN ST_GeometryN(geom, 1);
    ELSIF GeometryType(geom) = 'MULTIPOLYGON' AND ST_NumGeometries(geom) = 1 THEN
        RETURN ST_GeometryN(geom, 1);
    ELSE
        RETURN geom;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;



-- Test Zone
/*
SELECT ST_AsText(postgis_to_osm.simplify_multi(
 ST_GeometryFromText('
MULTILINESTRING((-47.7628302820967 -15.6478987267765,-47.7631625722526 -15.6483461784742,-47.7629693860279 -15.6485453804497,-47.763102240508 -15.6486506849182,-47.7632050536604 -15.6485741728048,-47.7633102578164 -15.6484594046346,-47.764642046791 -15.6491336676343,-47.7647639879718 -15.6488897852727,-47.7633641443741 -15.6481794521709,-47.7633410799932 -15.648147676377,-47.763291533729 -15.6480762125353,-47.7630273063807 -15.6477774437557,-47.7628283282841 -15.6479026344017))', 4326)
));
*/