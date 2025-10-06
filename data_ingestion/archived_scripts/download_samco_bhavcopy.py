#!/usr/bin/env python3
"""
Download monthly Bhavcopy data from Samco for NSE Cash, NSE F&O, BSE Cash, and MCX
Time period: 2016-04-01 to 2025-12-31
"""

import requests
import os
from datetime import datetime, timedelta
from pathlib import Path
import time
import logging
import zipfile
import io

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SamcoBhavcopyDownloader:
    """Download Bhavcopy data from Samco website"""
    
    BASE_URL = "https://www.samco.in/bhavcopy-nse-bse-mcx"
    DOWNLOAD_API = "https://www.samco.in/bse_nse_mcx/getBhavcopy"
    
    SEGMENTS = {
        'NSE_CASH': 'NSE',
        'NSE_FO': 'NSEFO',
        'BSE_CASH': 'BSE',
        'MCX': 'MCX'
    }
    
    def __init__(self, output_dir='./bhavcopy_data'):
        """Initialize downloader with output directory"""
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Create subdirectories for each segment
        for segment in self.SEGMENTS.keys():
            segment_dir = self.output_dir / segment
            segment_dir.mkdir(parents=True, exist_ok=True)
    
    def get_month_ranges(self, start_year=2016, start_month=4, end_year=2025):
        """Generate list of (from_date, to_date) tuples for each month"""
        month_ranges = []
        
        for year in range(start_year, end_year + 1):
            # Determine starting month for this year
            first_month = start_month if year == start_year else 1
            
            for month in range(first_month, 13):
                # First day of month
                from_date = datetime(year, month, 1)
                
                # Last day of month
                if month == 12:
                    to_date = datetime(year, 12, 31)
                else:
                    to_date = datetime(year, month + 1, 1) - timedelta(days=1)
                
                # Don't go beyond current date
                if from_date > datetime.now():
                    break
                    
                if to_date > datetime.now():
                    to_date = datetime.now()
                
                month_ranges.append((from_date, to_date))
        
        return month_ranges
    
    def download_bhavcopy(self, from_date, to_date, segment='NSE_CASH'):
        """
        Download Bhavcopy for a specific date range and segment
        
        Args:
            from_date: Start date (datetime object)
            to_date: End date (datetime object)
            segment: One of NSE_CASH, NSE_FO, BSE_CASH, MCX
        """
        # Format dates as YYYY-MM-DD
        from_str = from_date.strftime('%Y-%m-%d')
        to_str = to_date.strftime('%Y-%m-%d')
        
        # Prepare request payload (form data)
        payload = {
            'start_date': from_str,
            'end_date': to_str,
            'bhavcopy_data[]': self.SEGMENTS[segment],
            'show_or_down': '2'  # 2 = download
        }
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Content-Type': 'application/x-www-form-urlencoded',
            'Referer': 'https://www.samco.in/bhavcopy-nse-bse-mcx',
            'Origin': 'https://www.samco.in'
        }
        
        try:
            logger.info(f"Downloading {segment} from {from_str} to {to_str}")
            
            response = requests.post(
                self.DOWNLOAD_API,
                data=payload,
                headers=headers,
                timeout=60
            )
            
            if response.status_code == 200 and len(response.content) > 0:
                # Check if response contains actual data
                if b'No file available' in response.content:
                    logger.warning(f"✗ No data available for {segment} from {from_str} to {to_str}")
                    return False
                
                # The response is a ZIP file containing daily CSVs
                try:
                    # Extract ZIP file
                    with zipfile.ZipFile(io.BytesIO(response.content)) as z:
                        # Extract all files to the segment directory
                        segment_dir = self.output_dir / segment
                        z.extractall(segment_dir)
                        
                        file_list = z.namelist()
                        logger.info(f"✓ Downloaded {segment}: {len(file_list)} files ({len(response.content)} bytes)")
                        return True
                except zipfile.BadZipFile:
                    logger.error(f"✗ Invalid ZIP file for {segment} from {from_str} to {to_str}")
                    return False
            elif response.status_code == 200 and len(response.content) == 0:
                logger.warning(f"✗ Empty response for {segment} from {from_str} to {to_str}")
                return False
            else:
                logger.error(f"✗ Failed to download {segment} for {from_str}-{to_str}: HTTP {response.status_code}")
                if len(response.content) < 500:
                    logger.error(f"Response: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"✗ Error downloading {segment} for {from_str}-{to_str}: {str(e)}")
            return False
    
    def download_all(self, segments=None, start_year=2016, start_month=4, end_year=2025, delay=1):
        """
        Download all Bhavcopy data for specified segments and date range
        
        Args:
            segments: List of segments to download (default: all)
            start_year: Start year (default: 2016)
            start_month: Start month (default: 4 for April)
            end_year: End year (default: 2025)
            delay: Delay between requests in seconds (default: 1)
        """
        if segments is None:
            segments = list(self.SEGMENTS.keys())
        
        month_ranges = self.get_month_ranges(start_year, start_month, end_year)
        
        logger.info(f"Starting download for {len(month_ranges)} months across {len(segments)} segments")
        logger.info(f"Output directory: {self.output_dir.absolute()}")
        
        total_downloads = 0
        successful_downloads = 0
        
        for segment in segments:
            logger.info(f"\n{'='*60}")
            logger.info(f"Processing segment: {segment}")
            logger.info(f"{'='*60}")
            
            for from_date, to_date in month_ranges:
                success = self.download_bhavcopy(from_date, to_date, segment)
                total_downloads += 1
                if success:
                    successful_downloads += 1
                
                # Be polite to the server
                time.sleep(delay)
        
        logger.info(f"\n{'='*60}")
        logger.info(f"Download complete!")
        logger.info(f"Successful: {successful_downloads}/{total_downloads}")
        logger.info(f"Output directory: {self.output_dir.absolute()}")
        logger.info(f"{'='*60}")


def main():
    """Main function to run the downloader"""
    
    # Create output directory in data/bhavcopies
    script_dir = Path(__file__).parent.parent
    output_dir = script_dir / 'data' / 'bhavcopies'
    
    # Initialize downloader
    downloader = SamcoBhavcopyDownloader(output_dir=output_dir)
    
    # Download only NSE Cash and BSE Cash from April 2016 to 2025
    downloader.download_all(
        segments=['NSE_CASH', 'BSE_CASH'],  # Only NSE Cash and BSE Cash
        start_year=2016,
        start_month=4,  # April
        end_year=2025,
        delay=10  # 3 second delay between requests
    )


if __name__ == '__main__':
    main()
