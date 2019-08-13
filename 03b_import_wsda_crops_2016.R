################################################################################
# Port the raw GDB ESRI Geodatabase files to POSTGRESQL/POSTGIS.
# 
# Requires:
# gdal - http://www.gdal.org/

library(rgdal)
library(sf)
library(dplyr)
library(RPostgreSQL)

#connect to the POSTGRESQL DB
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = "wa_parcels") #assumes user has access to postgre

### import WSDA GDB layers
wsda_gdb <- "/usb/big/data/cropland/2016WSDACropDistribution.gdb"
wsda_features <- ogrListLayers(dsn = wsda_gdb)

# Shapes
feature <- "WSDACrop_2016"
tblname <- stringr::str_to_lower(feature)
wsdashapes <- read_sf(dsn = wsda_gdb, layer = feature)

# Crop data
feature <- "CropData"
cropdata <- read_sf(dsn = wsda_gdb, layer = feature)

# Cropdata is just a replication of the shape data, but it also includes croptype
# so we add croptype to the shapes sf before writing a db table
wsda <- cbind(wsdashapes, cropdata$CropType) 
names(wsda)[which(names(wsda) == "cropdata.CropType")] <- "croptype"
names(wsda) <- stringr::str_to_lower(names(wsda))
st_geometry(wsda) <- "shape"

# Fix the geometry and set
st_crs(wsda)
wsda2 <- wsda %>%
  st_cast("MULTIPOLYGON") %>%
  st_cast("MULTILINESTRING") 

wsda3 <- wsda2 %>%
  mutate(centroid = st_centroid(wsda2$shape))
  

# Write to the database
if(dbExistsTable(con, tblname)) dbRemoveTable(con, tblname)
st_write(wsda3, dsn = con, tblname)

# Set the CRS of the shape geometry
epsg <- st_crs(wsda3)$epsg
dbExecute(con, paste0("ALTER TABLE ", tblname, " ALTER COLUMN shape TYPE GEOMETRY(MULTILINESTRING,", epsg, ") USING ST_SetSRID(shape,", epsg, ");"))
dbExecute(con, paste0("ALTER TABLE ", tblname, " ALTER COLUMN centroid TYPE GEOMETRY(POINT,", epsg, ") USING ST_SetSRID(centroid,", epsg, ");"))

# Add an object ID
dbExecute(con, "ALTER TABLE wsdacrop_2016 ADD COLUMN oid SERIAL UNIQUE;")

# Create indexes for the shapes and centroids
dbExecute(con, "CREATE INDEX wsdacrop_2016_centroid_idx ON wsdacrop_2016 USING GIST (centroid);")
dbExecute(con, 'CREATE INDEX wsdacrop_2016_shape_idx ON wsdacrop_2016 USING GIST (shape);')

# Analyze for improved query speed
dbExecute(con, "VACUUM ANALYZE wsdacrop_2016;")

