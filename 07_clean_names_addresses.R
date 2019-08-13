################################################################################
### Clean names and addresses
### 
### Steps:
### 0. Setup
### 1. Load names data
### 2. Clean
### 3. Add hispanic and historically disadvantaged indicators
### 4. Save to POSTGRES table


#### 0. Setup ----
library(assertthat)     #for data assertions
library(data.table)     #data.tables for faster processing
library(stringr)        #string manipulation
library(here)           #for locations
library(wru)            #bayesian estimation of ethnicity based on name and geolocation
library(zipcode)        #zip code to city data
library(RPostgreSQL)    #connection to postgres db

#Driver for postgres database
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = "wa_parcels") #assumes user has access to postgre

## city to county crosswalk
city_county <- data.table(readr::read_csv("/usb/big/data/census/city_county.csv"))
city_county$state <- "WA"

#### 1. Make an SQL query to get names and addresses ----
get_names_sql <- "
SELECT DISTINCT
x.nameid, x.name, 
x.addr1, x.addr2, x.addr3, 
x.city, x.state, x.zip, x.country 
FROM name x;"

names <- data.table(dbGetQuery(con, get_names_sql))
setnames(names, c("nameid", "name", "addr1", "addr2", "addr3", "city", "state", "zip9", "country"))


#### 2. Clean up names and addresses ----

### Clean up countries 
names[, oldcountry := country]
names[, country := str_to_upper(oldcountry)]
names[oldcountry %in% c("USA", "US"), country := "UNITED STATES"]
names[oldcountry %in% c("CAN", "CANDA"), country := "CANADA"]
names[grepl("AUSTRALIA", city), country := "AUSTRALIA"]
names[grepl("BANKOK 10110 THAIL", city), country := "THAILAND"]
names[grepl(" BC ", city), country := "CANADA"]
names[state %in% c("BC CANADA", "CANADA", "BC"), country := "CANADA"]
names[state == "WEST YORKSHIRE", country := "UNITED KINGDOM"]
names[oldcountry == "NA", country := NA]
names[!is.na(state), country := "UNITED STATES"]

### Clean up states 
names[, oldstate := state]
names[, state := trimws(str_to_upper(oldstate))]
names[oldstate == "", state := NA]
names[oldstate == "9.91562E+008", state := NA]
names[oldstate == "ALASKA", state := "AK"]
names[oldstate == "BC CANADA", state := "BC"]
names[oldstate == "CANADA", state := NA]
names[oldstate == "IDAHO", state := "ID"]
names[oldstate == "WASH", state := "WA"]
names[oldstate == "WEST YORKSHIRE", state := NA]
names[oldstate == "NA", state := NA]

### Clean up zips
names[, zip9 := trimws(zip9)]
names[, zip := substr(zip9, 1, 5)]
names[zip %in% c("-", "0", "0000", "00000", " 9900", "0    "), zip := NA]
names[, zip9 := NULL]


### Clean up cities and add counties 
# Simple city fixes
names[, oldcity := city]                       #preserve old values
names[, city := trimws(str_to_upper(oldcity))] #upper case
names[grepl(" BC ", oldcity), city := str_replace(oldcity, " BC ", "")]
names[grepl(", WA", oldcity), city := str_replace(oldcity, ", WA", "")]
names[str_sub(oldcity, -1) == ",", city := str_sub(oldcity, 1, -2)]

# Specific city name fixes
names[grepl(" NSW 2548, AUSTRALIA", oldcity), city := "TURA BEACH"]
names[grepl("ANDERSON IS", oldcity), city := "ANDERSON ISLAND"]
names[grepl("AUBRUN", oldcity), city := "AUBURN"]
names[grepl("BANKOK 10110 THAIL", oldcity), city := "BANKOK"]
names[grepl("EAST WENATCHE", oldcity), city := "EAST WENATCHEE"]
names[grepl("EAST WENATHCEE", oldcity), city := "EAST WENATCHEE"]
names[grepl("E WENATCHEE", oldcity), city := "EAST WENATCHEE"]
names[grepl("GREENACRES", oldcity), city := "GREEN ACRES"]
names[grepl("LACENTER", oldcity), city := "LA CENTER"]
names[grepl("MOSESLAKE", oldcity), city := "MOSES LAKE"]
names[grepl("MONTLAKE TERRACE", oldcity), city := "MOUNTLAKE TERRACE"]
names[grepl("N LAKEWOOD", oldcity), city := "LAKEWOOD"]
names[grepl("OAKSDALE", oldcity), city := "OAKESDALE"]
names[grepl("OKANAGAN", oldcity), city := "OKANOGAN"]
names[grepl("OKANAGON", oldcity), city := "OKANOGAN"]
names[grepl("ORONDO,", oldcity), city := "ORONDO"]
names[grepl("OTHELL", oldcity), city := "OTHELLO"]
names[grepl("ROSAILIA", oldcity), city := "ROSALIA"]
names[grepl("ROYALCITY", oldcity), city := "ROYAL CITY"]
names[grepl("SEATTLE,", oldcity), city := "SEATTLE"]
names[grepl("SEDRO-WOOLLEY", oldcity), city := "SEDRO WOOLLEY"]
names[grepl("SEVENBAYS", oldcity), city := "SEVEN BAYS"]
names[grepl("SO CLE ELUM", oldcity), city := "SOUTH CLE ELUM"]
names[grepl("ST.JOHN", oldcity), city := "ST. JOHN"]
names[grepl("TUKWILLA", oldcity), city := "TUKWILA"]
names[grepl("UNIVERSITY PL", oldcity), city := "UNIVERSITY PLACE"]
names[grepl("VANCOVER", oldcity), city := "VANCOUVER"]
names[grepl("WALLA WALA", oldcity), city := "WALLA WALLA"]
names[grepl("WALLAWALLA", oldcity), city := "WALLA WALLA"]
names[oldcity == "NA", city := NA]

# Add city based on zip code
data(zipcode)
setnames(zipcode, "city", "zipcity")
names <- merge(names, zipcode[, c("zip", "zipcity")], by="zip", all.x = TRUE)
names[, zipcity := str_to_upper(zipcity)]

# Merge county by city and then zipcity
names <- merge(names, city_county[, c("city", "county", "state")], 
  by=c("city", "state"), all.x = TRUE)
names <- merge(names, city_county[, c("city", "county", "state")], 
  by.x=c("zipcity", "state"), by.y=c("city", "state"), all.x = TRUE)
names[is.na(county.x), county.x := county.y]
setnames(names, "county.x", "county")
names[, county.y := NULL]

n_missing <- length(names[is.na(county) & !is.na(city)]$city)
n_missing_wa <- length(names[is.na(county) & state == 'WA' & !is.na(city)]$city)
message(paste0("After matching on city name and zip, ",
  n_missing , " valid WA records are still missing a county."))

#table of missing city names
mc <- names[is.na(county) & state == 'WA' & !is.na(city)]$city

message("Top 100 cities missing counties")
sort(table(mc), decreasing = TRUE)[1:100]

#merge county fips
names <- merge(names, unique(city_county[, c("county", "state", "state_fips", "county_fips")]), by=c("state", "county"), all.x = TRUE)

# clear old variables and rename
names[, oldcity := NULL]
names[, oldcountry := NULL]
names[, oldstate := NULL]
names[, zipcity := NULL]

setnames(names, c("county", "county_fips"), c("county_name", "county"))


### Drop the old columns and keep the cleaned ones
names <- names[, c("nameid", "name", 
                   "addr1", "addr2", "addr3", "city", "state", "zip", "country", 
                   "county")]

#### 3. Add hispanic and historically disadvantaged indicators -----------------

### Determine surnames
get_surname <- function(names, known_surnames, 
  not_names = c(
    "DEVELOPMENT", "INC", "LLC", "COMPANY", "TRUST", "ASSN", "ESTATE", 
    "PARTNERSHIP", "INTEREST", "ASSOC") ) {
  
  if(missing(known_surnames)) {
    known_surnames <- wru::surnames2010$surname
  }
  
  names <- str_to_upper(names)
  surnames <- mclapply(names, function(s) {
    #allocate name based on whether it's "LAST, FIRST" or "FIRST LAST"
    s_comma <- str_split(s, ",")[[1]]
    s_space <- str_split(str_replace_all(s, ",", ""), " ")[[1]]
    sur <- if(length(s_comma) == 2) { s_comma[1] } 
    else { s_space[length(s_space)] }
    #Check for non-surname names and correct using name list or set to NA
    #If any not_name word is in the name, then check for surname
    #Select the longest match
    not_name <- sapply(not_names, function(nn) { nn %in% s_space })
    # if(any(not_name)) {
    #   idxs <- which(sapply(known_surnames, function(k) { k %in% s_space }))
    #   possible_surnames <- as.character(known_surnames[idxs])
    #   if(length(possible_surnames) > 0) {
    #     best_surname <- possible_surnames[which.max(nchar(possible_surnames))]
    #     sur <- ifelse(best_surname %in% not_names, NA, best_surname)
    #   } else {
    #     sur <- NA
    #   }
    # }
    if(any(not_name)) sur <- NA
    sur
  })
  unlist(surnames)
}

names[, surname := get_surname(name)]

### Get Census county demographics
census_county_data <- get_census_data(key = census_api, states = c("WA"), census.geo = "county")


### Predict based on surname, state, county
eth_names <- data.table(
  predict_race(names[!is.na(county) & state == "WA",], 
    census.surname = TRUE, 
    surname.year = 2010,
    census.geo = "county", 
    census.key = census_api, 
    census.data = census_county_data))

### Create hispanic and historically disadvantaged and merge to names
res <- eth_names[, .(
  hist_disadv = as.integer(which.max(c(pred.whi, pred.bla, pred.his, pred.asi, pred.oth)) != 1),
  hispanic = as.integer(which.max(c(pred.whi, pred.bla, pred.his, pred.asi, pred.oth)) == 3)
), by="nameid"]
setkey(res, nameid)
remove(eth_names)

names2 <- merge(names, res, by = "nameid", all.x = TRUE)

# 4. Write to a new table ------------------------------------------------------
dbGetQuery(con, "DROP TABLE IF EXISTS name_clean;")
dbWriteTable(con, "name_clean", names2)


beepr::beep(sound = 11)


