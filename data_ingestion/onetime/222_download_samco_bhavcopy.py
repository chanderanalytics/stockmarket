#!/usr/bin/env python3
"""
Headless script to fetch NSE & BSE Bhavcopy files from Samco website.

Requirements (add to requirements.txt):
    selenium>=4.19.0
    webdriver-manager>=4.0.1

Usage:
    python download_samco_bhavcopy.py [--date YYYYMMDD] [--dest BASE_DIR]

If --date is omitted the current date is used.  Files are saved under

    BASE_DIR/nse  and  BASE_DIR/bse

and older files are moved to BASE_DIR/nse-hist / bse-hist using the
existing move_historical_bhavcopies.sh script if present.
"""

import argparse
import os
import shutil
import sys
import time
from datetime import datetime
from pathlib import Path

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.firefox.options import Options as FirefoxOptions
from selenium.webdriver.firefox.service import Service as FirefoxService
from webdriver_manager.firefox import GeckoDriverManager
from typing import Optional, Set

SAMCO_URL = "https://www.samco.in/bhavcopy-nse-bse-mcx"
# Map Samco checkbox id -> local subfolder name
SEGMENTS = [
    ("bhavcopy_data1", "nse"),   # NSE Cash
    ("bhavcopy_data3", "bse"),   # BSE Cash
]
DOWNLOAD_TIMEOUT = 60  # seconds per file


def parse_args():
    parser = argparse.ArgumentParser(description="Download Bhavcopy from Samco website (headless).")
    parser.add_argument("--date", help="Date in YYYYMMDD format (default: today)")
    parser.add_argument("--dest", help="Base directory for bhavcopies", default=str(Path.cwd() / "data" / "bhavcopies"))
    return parser.parse_args()


# -------- WebDriver setup (headless Firefox) --------

def setup_driver(download_dir: Path) -> webdriver.Firefox:
    options = FirefoxOptions()
    options.headless = True

    # Firefox download preferences
    options.set_preference("browser.download.folderList", 2)
    options.set_preference("browser.download.dir", str(download_dir))
    options.set_preference("browser.helperApps.neverAsk.saveToDisk", "text/csv,application/zip")
    options.set_preference("pdfjs.disabled", True)

    # Launch Firefox with GeckoDriver
    service = FirefoxService(GeckoDriverManager().install())
    driver = webdriver.Firefox(service=service, options=options)
    driver.set_page_load_timeout(30)
    return driver


# -------- Utility helpers --------

def wait_for_file(download_dir: Path, before_files: set[str], timeout: int = DOWNLOAD_TIMEOUT) -> Optional[Path]:
    """Wait until a new file appears in download_dir whose name is not in before_files and is fully downloaded."""
    end = time.time() + timeout
    while time.time() < end:
        current = set(os.listdir(download_dir))
        new_files = [f for f in current if f not in before_files]
        if new_files:
            latest = max((download_dir / f for f in new_files), key=lambda p: p.stat().st_mtime)
            # If Chrome hasn't finished, there will be a .crdownload suffix
            if latest.suffix != ".crdownload":
                return latest
        time.sleep(1)
    return None


def set_date_inputs(driver: webdriver.Firefox, date_str: str):
    """Set both From and To date inputs to `date_str` using JS (assumes first two date inputs on page)."""
    driver.execute_script(
        "var d=arguments[0]; \n"
        "document.querySelectorAll('input[type=date]').forEach(function(el){el.value=d; el.dispatchEvent(new Event('change'));});",
        date_str,
    )


def download_segment(driver: webdriver.Firefox, checkbox_id: str, dest_dir: Path) -> Optional[Path]:
    """Select segment and click Download. Returns downloaded file path or None."""
    print(f"\n➡️  Processing segment id: {checkbox_id}")

    wait = WebDriverWait(driver, 20)

    # Uncheck all segment checkboxes then tick the desired one
    driver.execute_script(
        "document.querySelectorAll('input[type=checkbox][name^=bhavcopy_data]').forEach(c=>c.checked=false);"
        f"document.getElementById('{checkbox_id}').checked=true;"
    )

    # Click Submit button
    try:
        submit_btn = wait.until(
            EC.element_to_be_clickable(
                (
                    By.ID,
                    "Show",
                )
            )
        )
        driver.execute_script("arguments[0].click();", submit_btn)
    except Exception as e:
        print(f"  ⚠️  Submit button not found: {e}")
        return None

    # Click Download
    try:
        download_btn = wait.until(EC.element_to_be_clickable((By.ID, "btn_sub")))
    except Exception as e:
        print(f"  ⚠️  Download button not found for {checkbox_id}: {e}")
        return None

    # Downloads land in the browser's root download directory (parent of dest_dir)
    download_root = dest_dir.parent
    before = set(os.listdir(download_root))
    driver.execute_script("arguments[0].click();", download_btn)

    downloaded = wait_for_file(download_root, before)
    if downloaded is None:
        print(f"  ❌ Download timed out for {checkbox_id}")
        return None

    print(f"  ✅ Downloaded: {downloaded.name}")
    
    # Extract ZIP if needed
    if downloaded.suffix.lower() == '.zip':
        import zipfile
        try:
            # First ensure the destination directory exists
            dest_dir.mkdir(parents=True, exist_ok=True)
            
            # Extract directly to the destination directory
            with zipfile.ZipFile(downloaded, 'r') as zip_ref:
                zip_ref.extractall(dest_dir)
            print(f"  ✅ Extracted to: {dest_dir}")
            
            # Get the extracted files
            extracted_files = [f for f in dest_dir.glob('*') if f != downloaded]
            
            # Make sure the zip file is closed before trying to delete it
            try:
                downloaded.unlink()  # Delete the zip file
                print(f"  🗑️  Removed: {downloaded.name}")
            except Exception as e:
                print(f"  ⚠️  Error removing {downloaded.name}: {e}")
            
            # Return the first extracted file if any
            if extracted_files:
                return extracted_files[0]
            return None
                
        except Exception as e:
            print(f"  ⚠️  Error extracting {downloaded.name}: {e}")
    
    return downloaded


def move_old_files(base_dir: Path):
    print("\n🔄 Moving historical files using external script…")
    script_path = Path(__file__).parent / "333_move_historical_bhavcopies.sh"
    if script_path.exists():
        import subprocess
        try:
            subprocess.run([str(script_path)], check=True)
            print("✅ Historical files moved using external script")
        except subprocess.CalledProcessError as e:
            print(f"⚠️  Error running external script: {e}")
    else:
        print(f"⚠️  External script not found at {script_path}")


def main():
    args = parse_args()
    bhav_date = datetime.strptime(args.date, "%Y%m%d") if args.date else datetime.now()
    base_dir = Path(args.dest).expanduser().resolve()
    base_dir.mkdir(parents=True, exist_ok=True)

    for sub in ("nse", "bse"):
        (base_dir / sub).mkdir(exist_ok=True)

    driver = setup_driver(base_dir)
    try:
        print("🚀 Opening Samco Bhavcopy page…")
        driver.get(SAMCO_URL)

        # Accept cookies if banner pops
        try:
            WebDriverWait(driver, 5).until(EC.element_to_be_clickable((By.XPATH, "//button[contains(text(),'Accept')]"))).click()
        except Exception:
            pass

                # Set date inputs each loop to ensure they remain after refresh (first run sets both From and To)
        set_date_inputs(driver, bhav_date.strftime('%Y-%m-%d'))

        for checkbox_id, subdir in SEGMENTS:
            dest_sub_dir = base_dir / subdir
            downloaded = download_segment(driver, checkbox_id, dest_sub_dir)
            if downloaded:
                # Rename with consistent naming
                target_name = f"{bhav_date.strftime('%Y%m%d')}_{subdir.upper()}{downloaded.suffix}"
                (dest_sub_dir / target_name).write_bytes(downloaded.read_bytes())
                downloaded.unlink()

        print("\n✨ All downloads finished. Files saved under", base_dir)

    finally:
        driver.quit()

    # Move historical files
    move_old_files(base_dir)
    print("✅ Historical files moved where applicable.")


if __name__ == "__main__":
    main()
