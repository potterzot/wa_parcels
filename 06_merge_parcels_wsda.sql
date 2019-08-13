-- Merge WSDA Crop layer with PARCELS
--
-- RUN WITH:
--   psql -f <filename.sql> wa_parcels
DROP TABLE IF EXISTS parcel_crops;
CREATE TABLE parcel_crops
AS
SELECT
a.polyid as parcel_id, 
--a.shape as parcel_shape,
b.oid as wsda_id
--b.irrigation, b.acres, b.cropgroup, b.croptype, 
--b.rotcroptype, b.organic, 
--b.centroid as wsda_centroid
FROM parcel a, wsdacrop_2018 b
WHERE ST_WITHIN(ST_TRANSFORM(b.centroid, 2927), a.shape);
