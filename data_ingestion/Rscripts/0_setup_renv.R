# Set CRAN mirror for non-interactive installs
options(repos = c(CRAN = "https://cloud.r-project.org"))

# R setup script for reproducible environments using renv

# 1. Install renv if not already installed
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")

# 2. Initialize renv (only run this once per project, then comment out)
#if (!file.exists("renv.lock")) {
#  renv::init(bare = TRUE) }

# 3. Install required packages
required_packages <- c("DBI", "RPostgres", "dplyr", "zoo", "data.table","futile.logger",
"httr","jsonlite")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}


# Load libraries
library(DBI)
library(RPostgres)
library(data.table)
library(dplyr) # Retained for compatibility, but prefer data.table
library(zoo)
library(futile.logger)
library(httr)
library(jsonlite)

# 4. Snapshot the environment (records exact package versions)
renv::snapshot()

cat("renv environment initialized and packages installed.\nSnapshot saved to renv.lock.\n") 