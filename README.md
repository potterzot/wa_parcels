# wa_parcels
Processing of WA Parcels data into a POSTGRES database.

## Initial Setup

First you need to create a database and grant your username permissions on that database:

    sudo -u postgres createuser <username>
    sudo -u postgres psql
    sudo -u postgres createdb <wa_parcels>
    psql=# alter user <username> with encrypted password '<password>';
    psql=# grand all privileges on database wa_parcels to <username>;
    psql=# \c wa_parcels
    psql=# CREATE EXTENSION postgis;
    psql=# CREATE EXTENSION postgis_topology;
    psql=# CREATE EXTENSION fuzzystrmatch;
    psql=# CREATE EXTENSION postgis_tiger_geocoder;

## Importing data

The R script `01_import_gdb.R` connects to the `wa_parcels` database and imports the GDB files. Two files are needed: the washington parcels geodatabase file and the WSDA ag parcels geodatabase.
