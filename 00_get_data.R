#!/usr/bin/Rscript
#
# Get the 2017 WA parcels database
# This data does not have owner information, but it does have parcel ID that
# we can link to previous owner info, and it is potentially better developed
# than the 2012 version.
library(here)

### Get the 2017 WA parcels database
# This data does not have owner information, but it does have parcel ID that
# we can link to previous owner info, and it is potentially better developed
# than the 2012 version.


### Get WRIA polygons
# Source: http://geo.wa.gov/datasets/d3071915e69e45a3be63965f2305eeaa_0
wria_url <- "https://services.arcgis.com/6lCKYNJLvwTXqrmp/arcgis/rest/services/WAECY_WRIA/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json"
download.file(wria_url, destfile = "/usb/big/data/ecy/wria/wria.geojson")


### Get Irrigation Districts

### Get WSDA Crop layers
# https://agr.wa.gov/departments/land-and-water/natural-resources/agricultural-land-use



