library(Synth)
library(readxl)
library(dplyr)
library(ggplot2)
library(grid)
library(png)
library(gridExtra)

# Load dataset
file_path = "/Users/xzhcandice/Documents/W4/Capstone/eu_cleaned.xlsx"
data <- read_excel(file_path)
head(data)
summary(data)
str(data)
data <- as.data.frame(data)

# Create a mapping between country names and region numbers
country_region_map <- data %>%
   distinct(country) %>%
   mutate(region_no = row_number())

# Merge the mapping with the original dataset to add region numbers
data_with_region <- data %>%
  left_join(country_region_map, by = "country")

summary(data_with_region)

# Filter the dataset for treatment and control groups
treatment_units <- data_with_region %>%
  filter(yearjoined >= 1980) %>%
  distinct(region_no) %>%
  pull(region_no)

treatment_names <- data_with_region %>%
  filter(yearjoined >= 1980) %>%
  distinct(country) %>%
  pull(country)

treatment_units
treatment_names

control_units <- data_with_region %>%
  filter(EUcountries == 0) %>%
  distinct(region_no) %>%
  pull(region_no)

control_units

control_names <- data_with_region %>%
  filter(EUcountries == 0) %>%
  distinct(country) %>%
  pull(country)

control_names

# Function to prepare data for synthetic control
prepare_plot_data <- function(treatment_unit, data_with_region, control_units, yearjoin) {
  dataprep.out <- dataprep(
    foo = data_with_region,
    predictors = c('PopDensity', 'PercentUrban',
       'ElectricPowerConsumption', 'FDIInflow', 'Percent_Exports_GDP',
       'Percent_Imports_GDP', 'Remittances_Paid', 'Remittances_Received',
       'AirTransport', 'Industry_ValueAdded', 'Manuf_ValueAdded', 'CO2_manu',
       'CO2_othersectors', 'CO2_buildings', 'CO2_transport',
       'Net_trade_in_goods', 'Tariffrate', 'Inflation'),
    predictors.op = "mean",
    time.predictors.prior = 1980:yearjoin,
    dependent = "GDP_PC",
    unit.variable = "region_no",
    unit.names.variable = "country",
    time.variable = "year",
    treatment.identifier = treatment_unit,
    controls.identifier = control_units,
    time.optimize.ssr = 1980:yearjoin,
    time.plot = 1980:2018
  )
  
  synth.out <- synth(data.prep.obj = dataprep.out,
                    method = "BFGS" 
                    )
  
  
  return(list(dataprep_out = dataprep.out, synth_out = synth.out))
}

calculate_pre_treatment_mse <- function(actual, synthetic, pre_treatment_years) {
  # Subset the actual and synthetic data to pre-treatment years
  actual_pre <- actual[pre_treatment_years]
  synthetic_pre <- synthetic[pre_treatment_years]
  
  # Calculate the Mean Squared Error between actual and synthetic data
  mse <- mean((actual_pre - synthetic_pre)^2)
  return(mse)
}

# Initialize a data frame to store treatment effect results
treatment_effects <- data.frame(
  country = character(),
  year_joined = integer(),
  treatment_effect = numeric(),
  stringsAsFactors = FALSE
)

mse_threshold <- 1000000
plot_dir <- "/Users/xzhcandice/Documents/W4/Capstone/Results" # Specify your directory path for saving plots
dir.create(plot_dir, recursive = TRUE) # Create the directory if it doesn't exist

for(treatment_unit in treatment_units) {
  yearjoin <- data_with_region %>%
  filter(region_no == treatment_unit) %>%
  distinct(yearjoined) %>%
  pull(yearjoined)

  country_name <- data_with_region %>%
  filter(region_no == treatment_unit) %>%
  distinct(country) %>%
  pull(country)

  result <- prepare_plot_data(treatment_unit, data_with_region, control_units, yearjoin )
  dataprep.out <- result$dataprep_out
  synth.out <- result$synth_out

  # Check if the MSE exceeds the threshold
  pre_treatment_years <- 1980:yearjoin
  mse <- calculate_pre_treatment_mse(dataprep.out$Y1plot, dataprep.out$Y0plot %*% synth.out$solution.w, yearjoin - 1980)

  if(mse > mse_threshold) {
    next  # Skip if MSE is above threshold
  }

  # Calculate the treatment effect
  post_treatment_years_index <- (yearjoin - 1979):(2018 - 1980) 
  actual_post_treatment_values <- dataprep.out$Y1plot[post_treatment_years_index]
  synthetic_post_treatment_values <- dataprep.out$Y0plot[post_treatment_years_index, ] %*% synth.out$solution.w
  treatment_effect <- mean(actual_post_treatment_values - synthetic_post_treatment_values)

  # Add the results to the data frame
  treatment_effects <- rbind(treatment_effects, data.frame(
    country = country_name,
    year_joined = yearjoin,
    treatment_effect = treatment_effect
  ))


  # Save the plot to a file
  plot_file_name <- paste0(plot_dir, "/plot_", treatment_unit, ".png")
  png(filename = plot_file_name, width = 800, height = 600)
  path.plot(synth.res = synth.out,
            dataprep.res = dataprep.out,
            Ylab = "GDPpc",
            Xlab = "year",
            Ylim = c(0,60000),
            Legend = c(country_name,"synthetic"),
            Legend.position = "bottomright"
            )
  abline(v = yearjoin, col = "red", lty = 2)
  text(x = yearjoin, y = 20000, "Joining EU", pos = 4, col = "red", font = 2) 
  dev.off() # Close the device
}

treatment_effects

# Aggregate the graph
png(filename = "aggregated_plots.png", width = 3000, height = 1200, res = 300)  # Adjust size as needed
plot_files <- list.files(plot_dir, pattern = "\\.png$", full.names = TRUE)
plot_list <- lapply(plot_files, function(file) {
  rasterGrob(readPNG(file), interpolate = TRUE)
})

do.call(grid.arrange, c(plot_list, ncol = 5, nrow = 3))
dev.off()



#  gaps <- dataprep.out$Y1plot - (dataprep.out$Y0plot %*% synth.out$solution.w)
#  gaps[1:3, 1]

#Example of Spain
treatment_unit <- 9
  yearjoin <- data_with_region %>%
  filter(region_no == treatment_unit) %>%
  distinct(yearjoined) %>%
  pull(yearjoined)

  country_name <- data_with_region %>%
  filter(region_no == treatment_unit) %>%
  distinct(country) %>%
  pull(country)

  result <- prepare_plot_data(treatment_unit, data_with_region, control_units, yearjoin )
  dataprep.out <- result$dataprep_out
  synth.out <- result$synth_out

 synth.tables <- synth.tab(dataprep.res = dataprep.out,
                           synth.res    = synth.out
                           )

synth.tables$tab.pred
synth.tables$tab.v
synth.tables$tab.w

#  gaps.plot(synth.res = synth.out,
#            dataprep.res = dataprep.out,
#            Ylab = "Gap in real GDPpc",
#            Xlab = "year",
#            Ylim = c(-5000,10000),
#            Main = NA
#            )
# abline(v = 1993, col = "red", lty = 2)
# text(x = 1993, y = 5000, "EU Establishment", pos = 4, col = "red", font = 2)

# Placeholder to store placebo treatment effects
plot_dir <- "/Users/xzhcandice/Documents/W4/Capstone/PlaceboResults" # Specify your directory path for saving plots
dir.create(plot_dir, recursive = TRUE) # Create the directory if it doesn't exist

placebo_effects <- vector("list", length(control_units))

for (i in seq_along(control_units)) {
  control_unit <- control_units[i]
  yearjoin <- 1986

    country_name <- data_with_region %>%
    filter(region_no == control_unit) %>%
    pull(country) %>%
    unique() 


  # Use control units as 'treated' in a placebo test
  current_controls <- control_units[control_units != control_unit]
  placebo_result <- prepare_plot_data(control_unit, data_with_region, current_controls, yearjoin)
  dataprep.out <- placebo_result$dataprep_out
  synth.out <- placebo_result$synth_out

  # Calculate MSE for excluding poor fits, similar to how you did for treated units
  pre_treatment_years <- 1980:yearjoin
  mse <- calculate_pre_treatment_mse(dataprep.out$Y1plot, dataprep.out$Y0plot %*% synth.out$solution.w, yearjoin - 1980)
  
  if(mse <= mse_threshold) {

    # Calculate placebo treatment effect if MSE is within threshold
    post_treatment_years_index <- (yearjoin - 1979):(2018 - 1980)
    actual_post_treatment_values <- dataprep.out$Y1plot[post_treatment_years_index]
    synthetic_post_treatment_values <- dataprep.out$Y0plot[post_treatment_years_index, ] %*% synth.out$solution.w
    placebo_treatment_effect <- mean(actual_post_treatment_values - synthetic_post_treatment_values)
    
    # Store the placebo treatment effect
    placebo_effects[[i]] <- list(
      country = country_name,
      treatment_effect = placebo_treatment_effect
    )

      # Save the plot to a file
  plot_file_name <- paste0(plot_dir, "/plot_", country_name, ".png")
  png(filename = plot_file_name, width = 800, height = 600)
  path.plot(synth.res = synth.out,
            dataprep.res = dataprep.out,
            Ylab = "GDPpc",
            Xlab = "year",
            Ylim = c(0,60000),
            Legend = c(country_name,"synthetic"),
            Legend.position = "bottomright"
            )
  abline(v = yearjoin, col = "red", lty = 2)
  text(x = yearjoin, y = 20000, "Joining EU", pos = 4, col = "red", font = 2) 
  dev.off() # Close the device
  } 
}

placebo_effects
treatment_effects
actual_treatment_effect <- 0.5*(5196.81450+5553.78560)

# Aggregate the graph
png(filename = "aggregated_placebo.png", width = 3000, height = 2000, res = 300)  # Adjust size as needed
plot_files <- list.files(plot_dir, pattern = "\\.png$", full.names = TRUE)
plot_list <- lapply(plot_files, function(file) {
  rasterGrob(readPNG(file), interpolate = TRUE)
})

do.call(grid.arrange, c(plot_list, ncol = 3, nrow = 2))
dev.off()


# Convert the list of placebo effects to a data frame
placebo_effects_df <- do.call(rbind, lapply(placebo_effects, function(x) {
  return(data.frame(country = x$country, treatment_effect = x$treatment_effect))
}))
placebo_effects_df <- rbind(placebo_effects_df, data.frame(country = "Actual", treatment_effect = actual_treatment_effect))
ggplot(placebo_effects_df, aes(x = country, y = treatment_effect, fill = country == "Actual")) +
  geom_boxplot() +
  theme_minimal() +
  labs(title = "Comparison of Placebo and Actual Treatment Effects", x = "", y = "Treatment Effect") +
  scale_fill_manual(values = c("TRUE" = "red", "FALSE" = "grey"))  # Highlight actual effect
