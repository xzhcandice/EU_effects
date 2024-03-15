import pandas as pd
import numpy as np
import statsmodels.api as sm
from statsmodels.formula.api import ols
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import LabelEncoder
from patsy import dmatrices
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.linear_model import LinearRegression
from sklearn.experimental import enable_hist_gradient_boosting 
from sklearn.ensemble import HistGradientBoostingRegressor
from scipy import stats


# Read the .dta file into Python
file_path = "/Users/xzhcandice/Documents/W2/Econ203Data/wbicleaned.dta"
df = pd.read_stata(file_path)
print(df.shape)  
df.describe() #(13140, 76)
df.head()

# Preprocessing the Data
# Remove the year prior to 1980 and 2019
df = df[df['year'] != 2019]
df = df[df['year'] >= 1980]

# Drop the 'countrycode' column to avoid redundancy with "country"
df = df.drop(columns=['countrycode'])

# Create a new column 'yearjoined' based on the country
conditions = [df['country'].isin(["Belgium", "France", "Germany", "Italy", "Luxembourg", "Netherlands"]),
              df['country'].isin(["Denmark", "Ireland"]),
              df['country'] == "Greece",
              df['country'].isin(["Portugal", "Spain"]),
              df['country'].isin(["Austria", "Finland", "Sweden"]),
              df['country'].isin(["Cyprus", "Czech Republic", "Estonia", "Hungary", "Latvia", "Lithuania", "Malta", "Poland", "Slovakia", "Slovenia"]),
              df['country'].isin(["Bulgaria", "Romania"]),
              df['country'] == "Croatia"]

choices = [1958, 1973, 1981, 1986, 1995, 2004, 2007, 2013]
df['yearjoined'] = np.select(conditions, choices, default=np.nan)

# Create the inEU variable
df['inEU'] = np.where(~df['yearjoined'].isna() & (df['year'] >= df['yearjoined']), 1, 0)

# Create Europe_countries and EUcountries variables
df['EUcountries'] = np.where(~df['yearjoined'].isna(), 1, 0) # if a country has ever joined the EU
df['Europe_countries'] = np.where(df['EUcountries'] == 1, 1, 0)

# Add other European countries
european_countries = ["Andorra", "Belarus", "Iceland", "Liechtenstein", "Moldova", "Monaco", 
                      "Norway", "Russian Federation", "San Marino", "Switzerland", "Ukraine", "Bosnia and Herzegovina", 
                      "Albania", "Montenegro", "Serbia", "North Macedonia"]
df['Europe_countries'] = np.where(df['country'].isin(european_countries) | (df['EUcountries'] == 1), 1, 0)

# Filter non-European countries and only keep countries in Europe
df = df[df['Europe_countries'] == 1]

# Drop columns with more than 50% missing values overall
missing_proportion = df.isnull().mean()
columns_to_drop = missing_proportion[missing_proportion > 0.5].index
df = df.drop(columns=columns_to_drop, axis=1)

# Drop columns with more than 50% missing values before joining EU
EU_members = df[df['EUcountries'] == 1] 
missing_percentage_before_EU = EU_members[EU_members['year'] < EU_members['yearjoined']].isnull().mean() * 100
columns_to_drop = missing_percentage_before_EU[missing_percentage_before_EU > 50].index
df = df.drop(columns=columns_to_drop)

print("Shape of DataFrame after dropping columns:", df.shape) #1638,43
missing_proportion = df.isnull().mean()
missing_proportion
redundant_variables = ['GDP', 'Population', 'ElectricityAccess_Rural', 'Percent_FDIInflow_GDP', 'Imports_AnnualGrowth', 'Imports',
       'ElectricityAccess_Urban', 'Exports_AnnualGrowth', 'Exports', 'ElectricityAccess', 'Percent_FDIInflow_GDP', 
       'CO2_kt', 'Merchandise_exports', 'Merchandise_imports', 'Percent_Remittances_Received_GDP', 'Agr_raw_mat_exports', 'Agr_raw_mat_imports',
       'Merchandise_exports', 'Merchandise_imports', 'CO2_kgperGDP', 'GDP_CurrentD', 'Europe_countries']

df = df.drop(redundant_variables, axis=1)
print("Shape of DataFrame after dropping columns:", df.shape) #1638,24
df.columns

# Filter out countries that exceed 60% missing
numerical_df = df.drop(columns=['year','yearjoined','inEU','EUcountries'])
missing_percentage_by_country = numerical_df.groupby('country').apply(lambda x: x.isnull().mean() * 100)
countries_to_exclude = missing_percentage_by_country[missing_percentage_by_country > 60].dropna(how='all').index
df_filtered = df[~df['country'].isin(countries_to_exclude)]

# Display the number of countries before and after filtering
print("Number of countries before filtering:", len(df['country'].unique()))
print("Number of countries after filtering:", len(df_filtered['country'].unique()))

print("Shape of Pre-processed DataFrame:", df_filtered.shape) # 1209, 24

# EDA
# Display the first few rows of the dataset
print("First few rows of the dataset:")
print(df_filtered.head())

# Summary statistics of numerical variables
print("\nSummary statistics of numerical variables:")
print(df_filtered.describe())

# Data types of each column
print("\nData types of each column:")
print(df_filtered.dtypes)

# Missing values
missing_before = df_filtered.isnull().sum()
print("Missing Values Before Imputation:")
print(missing_before)

# Visualize missingness
plt.figure(figsize=(10, 10))
sns.heatmap(df_filtered.isnull(), cbar=False, cmap='viridis')
plt.title('Missing Values Before Imputation')
plt.tight_layout()
plt.savefig('MissingBefore.png')

# Group data by country and impute missing values separately for each country
def impute_missing_values_country(data, target_variable, correlation_threshold=0.5):
    for country, country_data in data.groupby('country'):
        correlation_matrix = country_data.select_dtypes(include=['number']).corr()
        covariates = correlation_matrix[target_variable][correlation_matrix[target_variable].abs() >= correlation_threshold].sort_values(ascending=False)

        covariates_data = country_data[['year'] + covariates.index.tolist()]
        missing_data = country_data[country_data[target_variable].isnull()]
        not_missing_data = country_data.dropna(subset=[target_variable])

        if not missing_data.empty:
            model = HistGradientBoostingRegressor()
            model.fit(not_missing_data[covariates_data.columns], not_missing_data[target_variable])
            predicted_values = model.predict(missing_data[covariates_data.columns])
            missing_data[target_variable] = predicted_values
            data.loc[missing_data.index, target_variable] = predicted_values
    return data

# Apply this function to each column with missing values
columns_with_missing_values = df_filtered.columns[df_filtered.isnull().any()].tolist()
columns_with_missing_values.remove('yearjoined')
for column in columns_with_missing_values:  
    df_filtered = impute_missing_values_country(df_filtered, column)

missing_after = df_filtered.isnull().sum()
print("Missing Values After Imputation:")
print(missing_after)


# Export the DataFrame 
file_path = "eu_cleaned.xlsx"
df_filtered.to_excel(file_path, index=False) 


# EDA after imputation
# Distribution plots for numerical variables
numerical_columns = df_filtered.select_dtypes(include=['int', 'float']).columns
len(numerical_columns)
num_rows = 4 
num_cols = 5 

fig, axes = plt.subplots(num_rows, num_cols, figsize=(20, 16))
axes = axes.flatten()

# Loop through each numerical column and create the distribution plot
for i, column in enumerate(df_filtered.select_dtypes(include=['int', 'float']).drop(columns=['inEU','EUcountries']).columns):
    sns.histplot(data=df_filtered[column], bins=20, kde=True, ax=axes[i])
    axes[i].set_title(f'Distribution of {column}')
    axes[i].set_xlabel('Value')
    axes[i].set_ylabel('Frequency')

plt.tight_layout()
plt.subplots_adjust(hspace=0.5, wspace=0.2) 
plt.savefig('DistributionAfter.png')

# Create a heatmap
correlation_matrix = df_filtered.select_dtypes(include=['number']).drop(columns=['year','yearjoined','inEU','EUcountries']).corr()
plt.figure(figsize=(12, 10))
sns.heatmap(correlation_matrix, annot=True, cmap='coolwarm', fmt=".2f")
plt.title('Correlation Matrix Heatmap')
plt.tight_layout()
plt.savefig('CorrelationHeatmap.png')

# Box plot to visualize outliers
columns_of_interest = df_filtered.select_dtypes(include=['number']).drop(columns=['year','yearjoined','inEU','EUcountries'])
fig, axes = plt.subplots(nrows=5, ncols=4, figsize=(20, 15))
axes = axes.flatten()
for i, column in enumerate(columns_of_interest):
    sns.boxplot(x=df[column], ax=axes[i])
    axes[i].set_title(column)

for i in range(len(columns_of_interest), len(axes)):
    fig.delaxes(axes[i])

plt.tight_layout()
plt.savefig("Outlier.png")

df_filtered.columns
