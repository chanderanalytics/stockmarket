#!/usr/bin/env Rscript

source("data_ingestion/Rscripts/0_setup_renv.R")

library(RPostgres)
library(DBI)
library(futile.logger)

dir.create("log", showWarnings = FALSE, recursive = TRUE)
log_file <- file.path("log", paste0("create_prices_bhavcopy3_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
flog.appender(appender.tee(log_file))
flog.threshold(INFO)

flog.info("Starting FULL optimized prices_bhavcopy3 creation")

flog.info("Connecting to database...")
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("PGDATABASE"),
  host = Sys.getenv("PGHOST"),
  port = Sys.getenv("PGPORT"),
  user = Sys.getenv("PGUSER"),
  password = Sys.getenv("PGPASSWORD")
)

flog.info("Dropping existing prices_bhavcopy3 table if exists...")
dbExecute(con, "DROP TABLE IF EXISTS prices_bhavcopy3")

flog.info("Creating prices_bhavcopy3 table with technical indicators...")
flog.info("Step 1: Processing base indicators (moving averages)...")
flog.info("Step 2: Calculating distance and above/below flags...")
flog.info("Step 3: Computing lag values for crossover detection...")
flog.info("Step 4: Generating return flags and distance bins...")
flog.info("Step 5: Computing change indicators for multiple time periods...")
flog.info("This may take a while as it processes moving averages and flags...")
result <- dbExecute(con, "

CREATE TABLE prices_bhavcopy3 AS

WITH base AS (
    SELECT
        id, company_id, timestamp, open, high, low, close,

        LAG(close) OVER (PARTITION BY company_id ORDER BY timestamp) AS prev_close,

        AVG(close) OVER (
            PARTITION BY company_id ORDER BY timestamp
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS DMA20,

        AVG(close) OVER (
            PARTITION BY company_id ORDER BY timestamp
            ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
        ) AS DMA50,

        AVG(close) OVER (
            PARTITION BY company_id ORDER BY timestamp
            ROWS BETWEEN 199 PRECEDING AND CURRENT ROW
        ) AS DMA200

    FROM prices_bhavcopy_2 p
),

flags AS (
    SELECT
        base.*,

        -- Distance %
        CASE WHEN DMA20 IS NOT NULL AND DMA20 != 0 THEN (close - DMA20)/DMA20*100 END AS distance20DMA,
        CASE WHEN DMA50 IS NOT NULL AND DMA50 != 0 THEN (close - DMA50)/DMA50*100 END AS distance50DMA,
        CASE WHEN DMA200 IS NOT NULL AND DMA200 != 0 THEN (close - DMA200)/DMA200*100 END AS distance200DMA,

        -- Above flags
        CASE WHEN close > DMA20 THEN 1 ELSE 0 END AS Above20DMA,
        CASE WHEN close > DMA50 THEN 1 ELSE 0 END AS Above50DMA,
        CASE WHEN close > DMA200 THEN 1 ELSE 0 END AS Above200DMA

    FROM base
),

lags AS (
    SELECT
        flags.*,

        LAG(Above20DMA) OVER (PARTITION BY company_id ORDER BY timestamp) AS prev_Above20DMA,
        LAG(Above50DMA) OVER (PARTITION BY company_id ORDER BY timestamp) AS prev_Above50DMA,
        LAG(Above200DMA) OVER (PARTITION BY company_id ORDER BY timestamp) AS prev_Above200DMA

    FROM flags
),

final AS (
    SELECT
        -- Base table columns
        id, company_id, timestamp, open, high, low, close,
        
        -- Computed columns from base CTE
        prev_close, DMA20, DMA50, DMA200,
        distance20DMA, distance50DMA, distance200DMA,
        Above20DMA, Above50DMA, Above200DMA,
        
        -- Computed columns from lags CTE  
        prev_Above20DMA, prev_Above50DMA, prev_Above200DMA,
        
        -- Return Flags
        CASE WHEN prev_close IS NULL THEN NULL
             WHEN 100*(close-prev_close)/NULLIF(prev_close,0) > 4.5 THEN 1 ELSE 0 END AS return_gt_4_5pct,

        CASE WHEN prev_close IS NULL THEN NULL
             WHEN 100*(close-prev_close)/NULLIF(prev_close,0) > 9.5 THEN 1 ELSE 0 END AS return_gt_9_5pct

    FROM lags
)

SELECT
    *,

    -- Distance Bins 20 DMA
    CASE
        WHEN distance20DMA < -10 THEN 'bin0_Below_-10%'
        WHEN distance20DMA < -3 THEN 'bin1_-10%_to_-3%'
        WHEN distance20DMA <= 3 THEN 'bin2_-3%_to_3%'
        WHEN distance20DMA <= 10 THEN 'bin3_3%_to_10%'
        WHEN distance20DMA > 10 THEN 'bin4_Above_10%'
    END AS distance20DMA_bin,

    -- Distance Bins 50 DMA
    CASE
        WHEN distance50DMA < -15 THEN 'bin0_Below_-15%'
        WHEN distance50DMA < -5 THEN 'bin1_-15%_to_-5%'
        WHEN distance50DMA < 0 THEN 'bin2_-5%_to_0%'
        WHEN distance50DMA <= 5 THEN 'bin3_0%_to_5%'
        WHEN distance50DMA <= 15 THEN 'bin4_5%_to_15%'
        WHEN distance50DMA > 15 THEN 'bin5_Above_15%'
    END AS distance50DMA_bin,

    -- Distance Bins 200 DMA
    CASE
        WHEN distance200DMA < -30 THEN 'bin0_Below_-30%'
        WHEN distance200DMA < -10 THEN 'bin1_-30%_to_-10%'
        WHEN distance200DMA <= 10 THEN 'bin2_-10%_to_10%'
        WHEN distance200DMA <= 30 THEN 'bin3_10%_to_30%'
        WHEN distance200DMA > 30 THEN 'bin4_Above_30%'
    END AS distance200DMA_bin,

    -- Cross Flags
    CASE WHEN prev_Above20DMA = 0 AND Above20DMA = 1 THEN 1 ELSE 0 END AS crossedAbove20DMA,
    CASE WHEN prev_Above20DMA = 1 AND Above20DMA = 0 THEN 1 ELSE 0 END AS crossedBelow20DMA,

    CASE WHEN prev_Above50DMA = 0 AND Above50DMA = 1 THEN 1 ELSE 0 END AS crossedAbove50DMA,
    CASE WHEN prev_Above50DMA = 1 AND Above50DMA = 0 THEN 1 ELSE 0 END AS crossedBelow50DMA,

    CASE WHEN prev_Above200DMA = 0 AND Above200DMA = 1 THEN 1 ELSE 0 END AS crossedAbove200DMA,
    CASE WHEN prev_Above200DMA = 1 AND Above200DMA = 0 THEN 1 ELSE 0 END AS crossedBelow200DMA,

    -- Change Columns (ALL PERIODS)

    -- 1D
    Above20DMA - LAG(Above20DMA,1) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg1D_Above20DMA,
    Above50DMA - LAG(Above50DMA,1) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg1D_Above50DMA,
    Above200DMA - LAG(Above200DMA,1) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg1D_Above200DMA,

    -- 2D
    Above20DMA - LAG(Above20DMA,2) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg2D_Above20DMA,
    Above50DMA - LAG(Above50DMA,2) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg2D_Above50DMA,
    Above200DMA - LAG(Above200DMA,2) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg2D_Above200DMA,

    -- 4D
    Above20DMA - LAG(Above20DMA,4) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg4D_Above20DMA,
    Above50DMA - LAG(Above50DMA,4) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg4D_Above50DMA,
    Above200DMA - LAG(Above200DMA,4) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg4D_Above200DMA,

    -- 5D
    Above20DMA - LAG(Above20DMA,5) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg5D_Above20DMA,
    Above50DMA - LAG(Above50DMA,5) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg5D_Above50DMA,
    Above200DMA - LAG(Above200DMA,5) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg5D_Above200DMA,

    -- 21D
    Above20DMA - LAG(Above20DMA,21) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg21D_Above20DMA,
    Above50DMA - LAG(Above50DMA,21) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg21D_Above50DMA,
    Above200DMA - LAG(Above200DMA,21) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg21D_Above200DMA,

    -- 63D
    Above20DMA - LAG(Above20DMA,63) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg63D_Above20DMA,
    Above50DMA - LAG(Above50DMA,63) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg63D_Above50DMA,
    Above200DMA - LAG(Above200DMA,63) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg63D_Above200DMA,

    -- 126D
    Above20DMA - LAG(Above20DMA,126) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg126D_Above20DMA,
    Above50DMA - LAG(Above50DMA,126) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg126D_Above50DMA,
    Above200DMA - LAG(Above200DMA,126) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg126D_Above200DMA,

    -- 252D
    Above20DMA - LAG(Above20DMA,252) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg252D_Above20DMA,
    Above50DMA - LAG(Above50DMA,252) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg252D_Above50DMA,
    Above200DMA - LAG(Above200DMA,252) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg252D_Above200DMA,

    -- 512D
    Above20DMA - LAG(Above20DMA,512) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg512D_Above20DMA,
    Above50DMA - LAG(Above50DMA,512) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg512D_Above50DMA,
    Above200DMA - LAG(Above200DMA,512) OVER (PARTITION BY company_id ORDER BY timestamp) AS chg512D_Above200DMA

FROM final
")

flog.info(paste("Table creation completed. Rows processed:", result))
flog.info("Adding primary key...")
dbExecute(con, "ALTER TABLE prices_bhavcopy3 ADD PRIMARY KEY (id)")
flog.info("Creating index on company_id and timestamp...")
dbExecute(con, "CREATE INDEX idx_b3_company_timestamp ON prices_bhavcopy3(company_id, timestamp)")

flog.info("Disconnecting from database...")
dbDisconnect(con)

flog.info("Full script completed successfully")