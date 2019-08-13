#!/usr/bin/Rscript
#
# Import the WRIA shapes into the POSTGIS db.
library(here)
library(rgdal)
library(sf)
library(RPostgreSQL)
library(dplyr)

#connect to the POSTGRESQL DB
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = "wa_parcels") #assumes user has access to postgre

# Load the data and do some housekeeping
d <- read_sf("/usb/big/data/ecy/wria/wria.geojson")
names(d) <- stringr::str_to_lower(names(d))
st_geometry(d) <- "geometry"

dbExecute(con, "DROP TABLE IF EXISTS wria;")
write_sf(d, con, "wria")

# Set the geometry type and EPSG
epsg <- st_crs(d)$epsg
dbExecute(con, paste0("ALTER TABLE wria ALTER COLUMN geometry TYPE GEOMETRY(POLYGON,", epsg, ") USING ST_SetSRID(geometry,", epsg, ");"))

# Add an object ID
dbExecute(con, "ALTER TABLE wria ADD COLUMN oid SERIAL UNIQUE;")

# Add an index on geometry
dbExecute(con, 'CREATE INDEX wria_geometry_idx ON wria USING GIST ("geometry");')

# Analyze for improved query speed
dbExecute(con, "VACUUM ANALYZE wria;")
