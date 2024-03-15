cd "/Users/xzhcandice/Documents/W2/Econ203Data"
capture log close
log using "finalpaper.log", text replace
clear

use wbicleaned.dta, clear

keep countrycode year country GDP GDP_PC GDP_PC_PPP GDP_PPP ODAAndAid_Received NetODAReceived FDIInflow Percent_FDIInflow_GDP Remittances_Paid Remittances_Received Tourism_NumberofArrivals TourismReceipts

// also need to drop the year 2019, no data
drop if year==2019

gen yearjoined= 1958 if country == "Belgium" | country == "France" | country == "Germany"| country == "Italy"| country == "Luxembourg"| country == "Netherlands"
replace yearjoined= 1973 if country == "Denamrk" | country == "Ireland" 
replace yearjoined= 1981 if country== "Greece" 
replace yearjoined= 1986 if country == "Portugal" | country == "Spain"
replace yearjoined= 1995 if country == "Austria" | country == "Finland" | country == "Sweden"
replace yearjoined= 2004 if country == "Cyprus" | country == "Czech Republic" | country== "Estonia" | country == "Hungary" | country == "Latvia" | country== "Lithuania" | country== "Malta" | country == "Poland" | country== "Slovakia" | country== "Slovenia"
replace yearjoined= 2007 if country == "Bulgaria" | country == "Romania" 
replace yearjoined= 2013 if country == "Croatia"
//will also need to later drop EU countries that joined in 1958 bcz of lack of data before they joined

gen inEU = 0 
replace inEU=1 if year >= yearjoined 
replace inEU=0 if yearjoined == .

gen Europe_countries = 0

gen EUcountries = 0
replace EUcountries = 1 if yearjoined !=.
replace Europe_countries= 1 if EUcountries == 1

replace Europe_countries = 1 if country == "Andorra" | country == "Belarus"| country == "Iceland" ///
| country == "Liechtenstein"| country == "Moldova"| country == "Monaco"| country == "Norway"| country == "Russia"| country == "San Marino"| country == "Switzerland" ///
| country == "Ukraine"| country == "Bosnia and Herzegovina" | country == "Albania"| country == "Montenegro" | country == "Serbia" ///
| country == "North Macedonia"

// dropped Kosovo, UK, armenia, geargia, azerbaijan, vatican, turkey out of Europe_countries

egen countryid=group(country)
reghdfe ODAAndAid_Received inEU, absorb(year countryid)
reg ODAAndAid_Received inEU

gen lnFDI = ln(FDIInflow)
reghdfe lnFDI inEU, absorb(year countryid)
reg lnFDI inEU

gen lnTourismReceipts = ln(TourismReceipts)
reghdfe lnTourismReceipts inEU, absorb(year countryid)
reg lnTourismReceipts inEU

gen lnGDP_PC_PPP = ln(GDP_PC_PPP)
reghdfe lnGDP_PC_PPP inEU, absorb(year countryid)
reg lnGDP_PC_PPP inEU

gen lnODAAndAid_Received = ln(ODAAndAid_Received)
reghdfe lnGDP_PPP inEU, absorb(year countryid)
reg lnODAAndAid_Received inEU

//Synthetic control
* Install synth package 
ssc install synth, replace

* Manually create a macro with EU country names
local EUListFormatted "Austria" "Belgium" "Bulgaria" "Croatia" "Cyprus" "Czech Republic" "Denmark" "Estonia" "Finland" "France" "Germany" "Greece" "Hungary" "Ireland" "Italy" "Latvia" "Lithuania" "Luxembourg" "Malta" "Netherlands" "Poland" "Portugal" "Romania" "Slovakia" "Slovenia" "Spain" "Sweden"

* Specify the variables for the synth command
local predictors GDP_PC GDP_PC_PPP GDP_PPP ODAAndAid_Received FDIInflow Tourism_NumberofArrivals TourismReceipts
local predictors_ln lnFDI lnTourismReceipts lnGDP_PC_PPP lnODAAndAid_Received
local timevar year
local unitvar countryid

* Declare the data as time series
tsset countryid year

* Create a list of EU countries
egen EUList = group(country) if yearjoined != .

* Loop through each EU country and apply the synth command
levelsof country if inEU == 1, local(EU_countries)
foreach country in `EU_countries' {
    * Get the joining year for the current country
    sum yearjoined if country == "`country'", meanonly
    local joinYear = r(mean)

    * Run the synth command using the joining year
    synth `predictors', trunit("`country'") trperiod(`joinYear') gen(`country'_synth)
}


* Create macros for EU joining years for each country
local joinYearAustria [Year Austria joined]
local joinYearBelgium [Year Belgium joined]
... (and so on for each EU country)

* Loop through each EU country
foreach country in Austria Belgium ... {  // List all EU countries
    * Retrieve the joining year for the current country
    local joinYear = joinYear`country'

    * Run the synth command using the retrieved joining year
    synth `predictors', trunit(`countryid') trperiod(`joinYear') gen(`country'_synth)
}
