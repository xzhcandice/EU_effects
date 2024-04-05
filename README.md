# EU Membership Economic Effects Analysis

This repository contains all the necessary files and analysis regarding the impact of EU membership on member states' economies. Utilizing the Synthetic Control Method, this study aims to estimate the economic effects, particularly focusing on GDP per capita, following EU accession.

## Overview

The project is structured to investigate the causal impact of joining the European Union on economic metrics of the member countries. It employs a data-driven approach, leveraging the Synthetic Control Method to construct counterfactual scenarios and analyze the potential outcome had the countries not joined the EU.

## Repository Structure

- `PlaceboResults/`: Contains placebo test results for assessing the method's robustness.
- `Results/`: Stores outcomes from the main analysis including graphical representations
- `capstoneEnv/`, `venv/`: Virtual environments for Python and R, ensuring reproducibility.
- `*.png`: Various plots generated during the analysis showcasing distributions, correlations, and comparison between actual and synthetic controls.
- `capstone.R`: R script for executing the Synthetic Control Method and generating results.
- `data_cleaning.py`: Python script for preliminary data cleaning and preprocessing.
- `eu_cleaned.xlsx`, `eu_data.xlsx`, `wbicleaned.dta`: Data files used in the analysis.
- `Xie_Capstone Abstracts.pdf`, `Xie_Capstone Poster (2).pdf`: Academic abstracts and poster summarizing the project findings.
- `treatmentEffects.xlsx`: Detailed treatment effects computed for each EU member included in the study.

## Getting Started

To replicate this analysis:
1. Clone this repository.
2. Ensure Python and R environments are properly set up with necessary libraries and packages as listed in `requirements.txt` and `R_packages.txt`.
3. Run `data_cleaning.py` to preprocess the dataset.
4. Execute `capstone.R` to perform the Synthetic Control analysis and generate results.
5. Review `Xie_Capstone Poster (1).pdf` and `Xie_Capstone Abstracts.pdf` for a summarized version of the findings.

