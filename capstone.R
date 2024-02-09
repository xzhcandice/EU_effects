library(haven)
library(tidyverse) 
library(dplyr)
library(mice)
library(leaps)
library(MASS)
library(car)
library(pROC)
library(lmtest)
library(ggplot2)


file_path <- "/Users/xzhcandice/Documents/W2/Econ203Data/wbicleaned.dta"

# Read the .dta file into R
data <- read_dta(file_path)
nrow(data)
ncol(data)

# First, remove the year 2019
data <- data %>% 
  filter(year != 2019)

# Now, we'll create a new column 'yearjoined' based on the country
data <- data %>%
  mutate(yearjoined = case_when(
    country %in% c("Belgium", "France", "Germany", "Italy", "Luxembourg", "Netherlands") ~ 1958,
    country %in% c("Denmark", "Ireland") ~ 1973, # Corrected typo from 'Denamrk' to 'Denmark'
    country == "Greece" ~ 1981,
    country %in% c("Portugal", "Spain") ~ 1986,
    country %in% c("Austria", "Finland", "Sweden") ~ 1995,
    country %in% c("Cyprus", "Czech Republic", "Estonia", "Hungary", "Latvia", "Lithuania", "Malta", "Poland", "Slovakia", "Slovenia") ~ 2004,
    country %in% c("Bulgaria", "Romania") ~ 2007,
    country == "Croatia" ~ 2013,
    TRUE ~ as.numeric(NA) # Default case to NA for countries not in the list
  ))

# Next, create the 'inEU' variable
data <- data %>%
  mutate(inEU = if_else(!is.na(yearjoined) & year >= yearjoined, 1, 0))

# Now we create 'Europe_countries' and 'EUcountries' variables
data <- data %>%
  mutate(EUcountries = if_else(!is.na(yearjoined), 1, 0),
         Europe_countries = if_else(EUcountries == 1, 1, 0))

# Add other European countries
european_countries <- c("Andorra", "Belarus", "Iceland", "Liechtenstein", "Moldova", "Monaco", 
                        "Norway", "Russia", "San Marino", "Switzerland", "Ukraine", "Bosnia and Herzegovina", 
                        "Albania", "Montenegro", "Serbia", "North Macedonia")

data <- data %>%
  mutate(Europe_countries = if_else(country %in% european_countries | EUcountries == 1, 1, 0))

data_eu_only <- data %>%
  filter(inEU == 1 | !is.na(yearjoined))

# Comparing GDP per capita PPP in the year of joining
ggplot(data_eu_only, aes(x = factor(yearjoined), y = GDP_PC_PPP)) +
  geom_boxplot() +
  labs(title = "GDP per Capita PPP in the Year of Joining EU", x = "Year Joined", y = "GDP per Capita PPP") +
  theme_minimal()

# Count missing data for each feature
features <- data_eu_only %>%
  dplyr::select(-year, -countrycode, -country) %>%
  names()
  
data_eu_only %>% 
  summarize(across(all_of(features), function(x) sum(is.na(x)))) %>% 
  pivot_longer(everything(),
              names_to = "feature",
              values_to = "Count of Missing") %>% 
                   knitr::kable()                   
               
features <- data_eu_only %>%
  dplyr::select(-year, -countrycode, -country) %>%
  names()
 
   
# Calculate the percentage of missing data per row
data_eu_only $missing_percent <- apply(data_eu_only, 1, function(x) mean(is.na(x))) * 100

# View the first few rows to check the missing percentages
head(data_eu_only)

# Set a threshold for missing data, e.g., 50%
threshold <- 50


# Remove rows where the missing percentage is greater than the threshold
cleaned_data <- filter(data, missing_percent <= threshold)

# Remove columns where the misssingness is greater than 100
threshold_col <- 20
missingness_per_col <- colMeans(is.na(cleaned_data)) * 100
cleaned_data <- cleaned_data[, missingness_per_col <= threshold_col]

nrow(cleaned_data)

# remove NA values for this visualization.
data_clean <- data[!is.na(data$GDP_PC_PPP), ]

# Let's create a new column 'status' to indicate whether the data point is before or after joining the EU.
data <- data %>%
  mutate(status = if_else(year < yearjoined, "Before joining EU", "After joining EU"))

# Now, let's filter for one country as an example. Replace 'Country Name' with the actual country you're interested in.
# If you want to plot multiple countries, you can remove the filter line or filter for the desired countries.
country_data <- data %>%
  filter(country == "Romania", !is.na(GDP_PC_PPP))  # Replace with actual country names

# Plotting GDP per capita PPP over time, with different colors for before and after joining the EU.
ggplot(country_data, aes(x = year, y = GDP_PC_PPP, color = status)) +
  geom_line() +
  geom_point() +
  theme_minimal() +
  labs(title = "GDP per Capita PPP Over Time for Romania",
       x = "Year",
       y = "GDP per Capita PPP",
       color = "Status")


#EDA



