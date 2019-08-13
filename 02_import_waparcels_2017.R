################################################################################
# Port the raw GDB ESRI Geodatabase files to POSTGRESQL/POSTGIS.
# 
# Requires:
# gdal - http://www.gdal.org/

library(rgdal)
library(sf)
library(RPostgreSQL)

#connect to the POSTGRESQL DB
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = "wa_parcels") #assumes user has access to postgre

### Import WA Parcel layers
parcels_zip <- "/usb/big/data/parcels/Parcels2017gdb.zip"
parcels_gdb <- "/usb/big/data/parcels/Parcels2017.gdb"

if(!file.exists(parcels_gdb)) unzip(parcels_zip, exdir = "/usb/big/data/parcels/")

parcel_features <- ogrListLayers(dsn = parcels_gdb)

parcel_features <- c(parcel_features[])
## Add features as tables
for(feature in parcel_features) {
  # skip empty features
  if(!(feature %in% c("Name_geocoded", "NormalizedName", "Geocoding_Result"))) {
    message(paste0("Transferring ", feature, " layer to POSTGRES db."))
    tblname <- stringr::str_to_lower(feature)
    tbl <- read_sf(dsn = parcel_gdb, layer = feature)
    
    if(dbExistsTable(con, tblname)) dbRemoveTable(con, tblname)
    
    if("sf" %in% class(tbl)) {
      st_write(tbl, dsn = con, tblname)
    } else {
      dbWriteTable(con, tblname, tbl)
    }
    remove(tbl)
    gc()
  }
}

# ## add the taxroll names
# taxroll_names <- readr::read_csv("/usb/big/data/parcels/TaxRollsHaveNames.csv", col_types = "cccc", col_names = c("role", "objectid", "taxrollid", "nameid"), skip = 1)
# if(dbExistsTable(con, "taxroll_names")) dbRemoveTable(con, "taxroll_names")
# dbWriteTable(con, "taxroll_names", taxroll_names)
# 
# # indices for taxroll_names
# idx_sql <- "
# CREATE INDEX taxroll_names_taxrollid_idx ON taxroll_names USING btree (taxrollid);
# CREATE INDEX taxroll_names_nameid_idx ON taxroll_names USING btree (nameid);
# "
# dbExecute(con, idx_sql)


