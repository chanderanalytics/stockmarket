

source("data_ingestion/Rscripts/setup_renv.R")



user <- Sys.getenv("PGUSER")
password <- Sys.getenv("PGPASSWORD")
host <- Sys.getenv("PGHOST", "localhost")
port <- as.integer(Sys.getenv("PGPORT", "5432"))
dbname <- Sys.getenv("PGDATABASE", "stockdb")


  # 1. Connect to PostgreSQL
  con <- dbConnect(
    RPostgres::Postgres(),
    dbname = dbname,
    host = host,
    port = port,
    user = user,
    password = password
  )
  
  # 2. Pull the companies table as data.table
  dt_companies <- as.data.table(dbGetQuery(con, "SELECT * FROM companies"))
  


  t(t(names(dt_companies)))