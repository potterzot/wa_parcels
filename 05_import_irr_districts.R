#!/usr/bin/Rscript
#
# Import the WA irrigation district shapes
library(sf)
library(RPostgreSQL)

#connect to the POSTGRESQL DB
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = "wa_parcels") #assumes user has access to postgre

# Unzip and import
d_zip <- "/usb/big/data/ecy/irr_districts/irr_districts_rough.zip"

if(!file.exists("/usb/big/data/ecy/irr_districts/irr_districts_rough.shp")) {
  unzip(d_zip, exdir = "/usb/big/data/ecy/irr_districts/")
}

# Read data and lower case variables
d <- read_sf("/usb/big/data/ecy/irr_districts")
names(d) <- stringr::str_to_lower(names(d))
st_geometry(d) <- "geometry"

dbExecute(con, "DROP TABLE IF EXISTS irr_districts;")
write_sf(d, con, "irr_districts")

# Set the geometry type and EPSG
epsg <- st_crs(d)$epsg
dbExecute(con, paste0("ALTER TABLE irr_districts ALTER COLUMN geometry TYPE GEOMETRY(MULTIPOLYGON,", epsg, ") USING ST_SetSRID(geometry,", epsg, ");"))

# Add an object ID
dbExecute(con, "ALTER TABLE irr_districts ADD COLUMN oid SERIAL UNIQUE;")

# Add an index on geometry
dbExecute(con, 'CREATE INDEX irr_districts_geometry_idx ON irr_districts USING GIST ("geometry");')

# Analyze for improved query speed
dbExecute(con, "VACUUM ANALYZE irr_districts;")
