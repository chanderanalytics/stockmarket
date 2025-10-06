import time
import random
import pandas as pd
import os
from selenium import webdriver
from selenium.webdriver.common.by import By

# Tabs available on Moneycontrol
tabs = {
    "Cash": "cash",
    "F&O": "fno",
    "MF SEBI": "mfsebi",
    "FII SEBI": "fiisebi"
}

# Files
output_file = "fii_dii_daily_all_tabs.csv"
progress_file = "progress.csv"

# Load previous progress
if os.path.exists(progress_file):
    done = set(pd.read_csv(progress_file)["key"].tolist())
else:
    done = set()

# Start browser
driver = webdriver.Chrome()

all_data = []

for tab_name, tab_id in tabs.items():
    print(f"🔄 Processing {tab_name} tab...")

    # Open main page
    url = "https://www.moneycontrol.com/stocks/marketstats/fii_dii_activity/index.php"
    driver.get(url)
    time.sleep(random.uniform(3, 6))

    # Click tab
    driver.find_element(By.LINK_TEXT, tab_name).click()
    time.sleep(random.uniform(2, 5))

    # Select full range
    driver.find_element(By.ID, "fromMonth").send_keys("Jan")
    driver.find_element(By.ID, "fromYear").send_keys("2006")
    driver.find_element(By.ID, "toMonth").send_keys("Dec")
    driver.find_element(By.ID, "toYear").send_keys("2025")

    # Click Go
    driver.find_element(By.ID, "reserch-btn").click()
    time.sleep(random.uniform(5, 8))

    # Get all month links
    month_links = driver.find_elements(By.CSS_SELECTOR, "table.tbldata14 td a")

    for link in month_links:
        month_name = link.text
        month_url = link.get_attribute("href")
        key = f"{tab_name}_{month_name}"

        # Skip if already done
        if key in done:
            print(f"   ⏩ Skipping {tab_name} | {month_name} (already scraped)")
            continue

        print(f"   → Scraping {tab_name} | {month_name}")

        try:
            driver.get(month_url)
            time.sleep(random.uniform(3, 7))

            rows = driver.find_elements(By.CSS_SELECTOR, "table.tbldata14 tr")
            headers = [h.text for h in rows[0].find_elements(By.TAG_NAME, "th")]

            for row in rows[1:]:
                cols = [c.text for c in row.find_elements(By.TAG_NAME, "td")]
                if cols and not row.text.startswith("Total"):
                    cols.append(tab_name)
                    all_data.append(cols)

            # Save batch to CSV (append mode)
            df = pd.DataFrame(all_data, columns=headers + ["Segment"])
            if os.path.exists(output_file):
                df.to_csv(output_file, mode="a", header=False, index=False, encoding="utf-8-sig")
            else:
                df.to_csv(output_file, index=False, encoding="utf-8-sig")

            all_data = []  # reset after save

            # Update progress file
            pd.DataFrame([[key]], columns=["key"]).to_csv(
                progress_file, mode="a", header=not os.path.exists(progress_file), index=False
            )
            done.add(key)

            # Random pause between months
            time.sleep(random.uniform(4, 9))

        except Exception as e:
            print(f"   ❌ Failed {tab_name} | {month_name} → {e}")
            continue

driver.quit()
print("✅ Scraping completed (or stopped, but progress saved).")