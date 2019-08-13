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

#Enable POSTGIS
postgis_sql <- "
CREATE EXTENSION postgis;
CREATE EXTENSION postgis_topology;
CREATE EXTENSION fuzzystrmatch;
CREATE EXTENSION postgis_tiger_geocoder;
"
dbExecute(con, postgis_sql)

### Import WA Parcel layers
parcel_gdb <- "/usb/big/data/parcels/StatewideParcels_v2012_e9.2_r1.1.gdb"
parcel_features <- ogrListLayers(dsn = parcel_gdb)
parcel_features <- c(parcel_features[])

## Add features as tables
for(feature in parcel_features) {
  # skip empty features
  if(!(feature %in% c("Name_geocoded", "NormalizedName", "Geocoding_Result"))) {
    message(paste0("Transferring ", feature, " layer to POSTGRES db."))
    tblname <- stringr::str_to_lower(feature)
    if(dbExistsTable(con, tblname)) dbRemoveTable(con, tblname)
    
    tbl <- read_sf(dsn = parcel_gdb, layer = feature)
    
    # Column names to lower case
    names(tbl) <- stringr::str_to_lower(names(tbl))
    if(feature %in% c("Parcel", "ParcelBoundary", "Name_geocoded2")) {
      # Each of these features has a geometry named "SHAPE" or "Shape",
      # which is converted to "shape"
      st_geometry(tbl) <- "shape"
      
      # Set the geometry type and EPSG
      epsg <- st_crs(tbl)$epsg
      geom_type <- unique(st_geometry_type(tbl))
      
      dbExecute(con, paste0(
        "ALTER TABLE ", tblname, 
        " ALTER COLUMN geometry TYPE GEOMETRY(", geom_type, ",", epsg, ") 
        USING ST_SetSRID(geometry,", epsg, ");"))
    }
    
    if(dbExistsTable(con, tblname)) dbRemoveTable(con, tblname)
    
    if("sf" %in% class(tbl)) {
      st_write(tbl, dsn = con, tblname)
    } else {
      dbWriteTable(con, tblname, tbl)
    }
    dbExecute(paste0("VACUUM ANALYZE ", tblname, ";"))
    remove(tbl)
    gc()
  }
}

## add the taxroll names
taxroll_names <- readr::read_csv("/usb/big/data/parcels/TaxRollsHaveNames.csv", col_types = "cccc", col_names = c("role", "objectid", "taxrollid", "nameid"), skip = 1)
if(dbExistsTable(con, "taxroll_names")) dbRemoveTable(con, "taxroll_names")
dbWriteTable(con, "taxroll_names", taxroll_names)

# indices for taxroll_names
idx_sql <- "
CREATE INDEX taxroll_names_taxrollid_idx ON taxroll_names USING btree (taxrollid);
CREATE INDEX taxroll_names_nameid_idx ON taxroll_names USING btree (nameid);
"
dbExecute(con, idx_sql)

## Fix specific column names
#dbExecute(con, 'ALTER TABLE parcel RENAME COLUMN "GISAcres" TO gisacres;')
dbExecute(con, "ALTER TABLE name RENAME COLUMN addressline1 TO addr1;")
dbExecute(con, "ALTER TABLE name RENAME COLUMN addressline2 TO addr2;")
dbExecute(con, "ALTER TABLE name RENAME COLUMN addressline3 TO addr3;")
dbExecute(con, "ALTER TABLE name RENAME COLUMN addresscity TO city;")
dbExecute(con, "ALTER TABLE name RENAME COLUMN addressstate TO state;")
dbExecute(con, "ALTER TABLE name RENAME COLUMN addresszip TO zip;")
dbExecute(con, "ALTER TABLE name RENAME COLUMN addresscountry TO country;")
