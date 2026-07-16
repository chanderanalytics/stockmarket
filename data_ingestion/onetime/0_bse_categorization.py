import pandas as pd
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

# ==========================================================
# CONFIG
# ==========================================================

INPUT_FILE = "/Users/chanderbhushan/stockmkt/data/Equity.csv"
OUTPUT_FILE = "bse_industry_classification.csv"

MAX_WORKERS = 20

# ==========================================================
# LOAD FILE
# ==========================================================

master = pd.read_csv(INPUT_FILE)
master = master.reset_index()

print(f"Loaded {len(master):,} stocks")

# ==========================================================
# HEADERS
# ==========================================================

HEADERS = {
    "User-Agent": "Mozilla/5.0",
    "Referer": "https://www.bseindia.com/",
    "Origin": "https://www.bseindia.com"
}

# ==========================================================
# FETCH FUNCTION
# ==========================================================

def fetch_stock(row):

    try:

        scripcode = str(row["level_0"]).strip()

        url = (
            "https://api.bseindia.com/BseIndiaAPI/api/ComHeadernew/w"
            f"?quotetype=&scripcode={scripcode}&seriesid="
        )

        r = requests.get(
            url,
            headers=HEADERS,
            timeout=20
        )

        if r.status_code != 200:
            return None

        data = r.json()

        return {

            # Original BSE Columns

            "Security Code": row["level_0"],
            "Issuer Name": row["level_1"],
            "Security Id": row["level_2"],
            "Security Name": row["level_3"],
            "Status": row["level_4"],

            "Group": row["Security Code"],
            "Face Value": row["Issuer Name"],
            "ISIN No": row["Security Id"],

            # Classification

            "Industry": data.get("Industry"),
            "Instrument": row["Security Name"],

            "Sector Name": data.get("Sector"),
            "Industry New Name": data.get("IndustryNew"),
            "Igroup Name": data.get("IGroup"),
            "ISubgroup Name": data.get("ISubGroup"),

            # Additional Fields

            "PE": data.get("PE"),
            "PB": data.get("PB"),
            "EPS": data.get("EPS"),
            "CEPS": data.get("CEPS"),
            "ROE": data.get("ROE"),
            "OPM": data.get("OPM"),
            "NPM": data.get("NPM"),

            "ConPE": data.get("ConPE"),
            "ConEPS": data.get("ConEPS"),
            "ConCEPS": data.get("ConCEPS"),
            "ConROE": data.get("ConROE"),
            "ConPB": data.get("ConPB"),

            "Index": data.get("Index"),
            "Grp_Index": data.get("Grp_Index"),
            "FaceVal_API": data.get("FaceVal"),
            "SetlType": data.get("SetlType")

        }

    except Exception:
        return None


# ==========================================================
# PARALLEL DOWNLOAD
# ==========================================================

results = []

with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:

    futures = [
        executor.submit(fetch_stock, row)
        for _, row in master.iterrows()
    ]

    total = len(futures)

    for i, future in enumerate(as_completed(futures), 1):

        result = future.result()

        if result:
            results.append(result)

        if i % 100 == 0:
            print(
                f"Completed {i:,} / {total:,}"
            )

# ==========================================================
# DATAFRAME
# ==========================================================

df = pd.DataFrame(results)

column_order = [

    "Security Code",
    "Issuer Name",
    "Security Id",
    "Security Name",
    "Status",
    "Group",
    "Face Value",
    "ISIN No",
    "Industry",
    "Instrument",
    "Sector Name",
    "Industry New Name",
    "Igroup Name",
    "ISubgroup Name",

    "PE",
    "PB",
    "EPS",
    "CEPS",
    "ROE",
    "OPM",
    "NPM",

    "ConPE",
    "ConEPS",
    "ConCEPS",
    "ConROE",
    "ConPB",

    "Index",
    "Grp_Index",
    "FaceVal_API",
    "SetlType"
]

df = df[column_order]

# ==========================================================
# SAVE
# ==========================================================

df.to_csv(
    OUTPUT_FILE,
    index=False
)

print("\n=================================")
print("DOWNLOAD COMPLETE")
print("=================================")
print(f"Rows: {len(df):,}")
print(f"File: {OUTPUT_FILE}")