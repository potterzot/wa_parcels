#!/bin/bash
# Import the GDB files into POSTGRESQL/POSTGIS
ogr2ogr -skipfailures -f PostgreSQL PG:'dbname=wa_parcels' '/usb/big/data/cropland/2016WSDACropDistribution.gdb'
ogr2ogr -skipfailures -f PostgreSQL PG:'dbname=wa_parcels' '/usb/big/data/parcels/StatewideParcels_v2012_e9.2_r1.1.gdb'

