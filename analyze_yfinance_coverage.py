"""
Script to analyze yfinance data coverage in companies table.

This script provides a comprehensive analysis of yfinance column coverage:
- Overall coverage statistics for all yfinance columns
- Breakdown by code type (NSE-only, BSE-only, both)
- Detailed analysis of why yfinance data might be missing
- Comparison with yf_not_found flag
- Recommendations for improving coverage
"""

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from sqlalchemy import create_engine, and_, or_, func
from sqlalchemy.orm import sessionmaker
from backend.models import Company
from datetime import datetime
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DATABASE_URL = 'postgresql://stockuser:stockpass@localhost:5432/stockdb'
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

def analyze_yfinance_coverage():
    """Analyze yfinance data coverage in companies table"""
    session = Session()
    
    try:
        print("🔍 YFINANCE DATA COVERAGE ANALYSIS")
        print("=" * 80)
        
        # Get total companies
        total_companies = session.query(Company).count()
        print(f"Total companies in database: {total_companies}")
        
        # Define yfinance columns to analyze
        yf_columns = [
            'sector_yf', 'industry_yf', 'country_yf', 'website_yf', 'longBusinessSummary_yf',
            'fullTimeEmployees_yf', 'city_yf', 'state_yf', 'address1_yf', 'zip_yf', 'phone_yf',
            'marketCap_yf', 'sharesOutstanding_yf', 'logo_url_yf', 'exchange_yf', 'currency_yf',
            'financialCurrency_yf', 'beta_yf', 'trailingPE_yf', 'forwardPE_yf', 'priceToBook_yf',
            'bookValue_yf', 'payoutRatio_yf', 'ebitda_yf', 'revenueGrowth_yf', 'grossMargins_yf',
            'operatingMargins_yf', 'profitMargins_yf', 'returnOnAssets_yf', 'returnOnEquity_yf',
            'totalRevenue_yf', 'grossProfits_yf', 'freeCashflow_yf', 'operatingCashflow_yf',
            'debtToEquity_yf', 'currentRatio_yf', 'quickRatio_yf', 'shortRatio_yf', 'pegRatio_yf',
            'enterpriseValue_yf', 'enterpriseToRevenue_yf', 'enterpriseToEbitda_yf'
        ]
        
        # Get companies by code type
        nse_only = session.query(Company).filter(
            and_(
                Company.nse_code != None, Company.nse_code != "",
                or_(Company.bse_code == None, Company.bse_code == "")
            )
        ).all()
        
        bse_only = session.query(Company).filter(
            and_(
                Company.bse_code != None, Company.bse_code != "",
                or_(Company.nse_code == None, Company.nse_code == "")
            )
        ).all()
        
        both_codes = session.query(Company).filter(
            and_(
                Company.nse_code != None, Company.nse_code != "",
                Company.bse_code != None, Company.bse_code != ""
            )
        ).all()
        
        print(f"\n📊 COMPANY BREAKDOWN BY CODE TYPE:")
        print(f"NSE-only companies: {len(nse_only)} ({len(nse_only)/total_companies*100:.1f}%)")
        print(f"BSE-only companies: {len(bse_only)} ({len(bse_only)/total_companies*100:.1f}%)")
        print(f"Companies with both codes: {len(both_codes)} ({len(both_codes)/total_companies*100:.1f}%)")
        
        # Analyze yf_not_found flag
        yf_not_found_count = session.query(Company).filter(Company.yf_not_found == 1).count()
        yf_found_count = session.query(Company).filter(Company.yf_not_found == 0).count()
        yf_not_set_count = session.query(Company).filter(Company.yf_not_found == None).count()
        
        print(f"\n🏷️  YF_NOT_FOUND FLAG ANALYSIS:")
        print(f"Companies with yf_not_found=1 (not found): {yf_not_found_count} ({yf_not_found_count/total_companies*100:.1f}%)")
        print(f"Companies with yf_not_found=0 (found): {yf_found_count} ({yf_found_count/total_companies*100:.1f}%)")
        print(f"Companies with yf_not_found=NULL (not set): {yf_not_set_count} ({yf_not_set_count/total_companies*100:.1f}%)")
        
        # Overall yfinance column coverage
        print(f"\n📈 OVERALL YFINANCE COLUMN COVERAGE:")
        print("-" * 80)
        print(f"{'Column':<25} {'Non-Null':<10} {'Null':<10} {'Coverage':<10} {'Unique':<10}")
        print("-" * 80)
        
        overall_stats = {}
        for column_name in yf_columns:
            if hasattr(Company, column_name):
                non_null_count = session.query(Company).filter(getattr(Company, column_name) != None).count()
                null_count = total_companies - non_null_count
                coverage_pct = (non_null_count / total_companies) * 100 if total_companies > 0 else 0
                unique_count = session.query(getattr(Company, column_name)).distinct().count()
                
                overall_stats[column_name] = {
                    'non_null': non_null_count,
                    'null': null_count,
                    'coverage': coverage_pct,
                    'unique': unique_count
                }
                
                print(f"{column_name:<25} {non_null_count:<10} {null_count:<10} {coverage_pct:<10.1f}% {unique_count:<10}")
        
        # Breakdown by code type
        print(f"\n🔍 COVERAGE BREAKDOWN BY CODE TYPE:")
        print("=" * 80)
        
        # NSE-only analysis
        print(f"\n📊 NSE-ONLY COMPANIES ({len(nse_only)} companies):")
        print("-" * 60)
        print(f"{'Column':<20} {'Coverage':<10} {'Non-Null':<10} {'Null':<10}")
        print("-" * 60)
        
        nse_stats = {}
        for column_name in yf_columns:
            if hasattr(Company, column_name):
                non_null_count = session.query(Company).filter(
                    and_(
                        Company.nse_code != None, Company.nse_code != "",
                        or_(Company.bse_code == None, Company.bse_code == ""),
                        getattr(Company, column_name) != None
                    )
                ).count()
                null_count = len(nse_only) - non_null_count
                coverage_pct = (non_null_count / len(nse_only)) * 100 if len(nse_only) > 0 else 0
                
                nse_stats[column_name] = {
                    'coverage': coverage_pct,
                    'non_null': non_null_count,
                    'null': null_count
                }
                
                print(f"{column_name:<20} {coverage_pct:<10.1f}% {non_null_count:<10} {null_count:<10}")
        
        # BSE-only analysis
        print(f"\n📊 BSE-ONLY COMPANIES ({len(bse_only)} companies):")
        print("-" * 60)
        print(f"{'Column':<20} {'Coverage':<10} {'Non-Null':<10} {'Null':<10}")
        print("-" * 60)
        
        bse_stats = {}
        for column_name in yf_columns:
            if hasattr(Company, column_name):
                non_null_count = session.query(Company).filter(
                    and_(
                        Company.bse_code != None, Company.bse_code != "",
                        or_(Company.nse_code == None, Company.nse_code == ""),
                        getattr(Company, column_name) != None
                    )
                ).count()
                null_count = len(bse_only) - non_null_count
                coverage_pct = (non_null_count / len(bse_only)) * 100 if len(bse_only) > 0 else 0
                
                bse_stats[column_name] = {
                    'coverage': coverage_pct,
                    'non_null': non_null_count,
                    'null': null_count
                }
                
                print(f"{column_name:<20} {coverage_pct:<10.1f}% {non_null_count:<10} {null_count:<10}")
        
        # Both codes analysis
        print(f"\n📊 COMPANIES WITH BOTH CODES ({len(both_codes)} companies):")
        print("-" * 60)
        print(f"{'Column':<20} {'Coverage':<10} {'Non-Null':<10} {'Null':<10}")
        print("-" * 60)
        
        both_stats = {}
        for column_name in yf_columns:
            if hasattr(Company, column_name):
                non_null_count = session.query(Company).filter(
                    and_(
                        Company.nse_code != None, Company.nse_code != "",
                        Company.bse_code != None, Company.bse_code != "",
                        getattr(Company, column_name) != None
                    )
                ).count()
                null_count = len(both_codes) - non_null_count
                coverage_pct = (non_null_count / len(both_codes)) * 100 if len(both_codes) > 0 else 0
                
                both_stats[column_name] = {
                    'coverage': coverage_pct,
                    'non_null': non_null_count,
                    'null': null_count
                }
                
                print(f"{column_name:<20} {coverage_pct:<10.1f}% {non_null_count:<10} {null_count:<10}")
        
        # Key insights and recommendations
        print(f"\n💡 KEY INSIGHTS:")
        print("=" * 80)
        
        # Find columns with highest and lowest coverage
        sorted_columns = sorted(overall_stats.items(), key=lambda x: x[1]['coverage'], reverse=True)
        
        print(f"🏆 TOP 5 YFINANCE COLUMNS BY COVERAGE:")
        for i, (col, stats) in enumerate(sorted_columns[:5]):
            print(f"  {i+1}. {col}: {stats['coverage']:.1f}% ({stats['non_null']}/{total_companies})")
        
        print(f"\n📉 BOTTOM 5 YFINANCE COLUMNS BY COVERAGE:")
        for i, (col, stats) in enumerate(sorted_columns[-5:]):
            print(f"  {i+1}. {col}: {stats['coverage']:.1f}% ({stats['non_null']}/{total_companies})")
        
        # Compare NSE vs BSE coverage
        print(f"\n🔄 NSE vs BSE COVERAGE COMPARISON:")
        key_columns = ['sector_yf', 'industry_yf', 'marketCap_yf', 'trailingPE_yf', 'beta_yf']
        for col in key_columns:
            if col in nse_stats and col in bse_stats:
                nse_cov = nse_stats[col]['coverage']
                bse_cov = bse_stats[col]['coverage']
                diff = nse_cov - bse_cov
                print(f"  {col}: NSE {nse_cov:.1f}% vs BSE {bse_cov:.1f}% (diff: {diff:+.1f}%)")
        
        # Recommendations
        print(f"\n🎯 RECOMMENDATIONS:")
        print("=" * 80)
        
        # Check if BSE companies have lower coverage
        bse_lower_coverage = []
        for col in key_columns:
            if col in nse_stats and col in bse_stats:
                if bse_stats[col]['coverage'] < nse_stats[col]['coverage'] * 0.8:  # 20% lower
                    bse_lower_coverage.append(col)
        
        if bse_lower_coverage:
            print(f"⚠️  BSE companies have significantly lower coverage for: {', '.join(bse_lower_coverage)}")
            print(f"   → Consider re-running yfinance fetch for BSE companies")
            print(f"   → Check if BSE ticker format needs adjustment")
        
        # Check yf_not_found flag consistency
        companies_with_yf_data_but_marked_not_found = session.query(Company).filter(
            and_(
                Company.yf_not_found == 1,
                or_(
                    Company.sector_yf != None,
                    Company.industry_yf != None,
                    Company.marketCap_yf != None
                )
            )
        ).count()
        
        if companies_with_yf_data_but_marked_not_found > 0:
            print(f"⚠️  {companies_with_yf_data_but_marked_not_found} companies have yf_not_found=1 but actually have yfinance data")
            print(f"   → Consider updating yf_not_found flag for these companies")
        
        # Check companies with no yf_not_found flag
        if yf_not_set_count > 0:
            print(f"⚠️  {yf_not_set_count} companies have yf_not_found=NULL (not processed)")
            print(f"   → Consider running yfinance fetch for these companies")
        
        # Overall coverage summary
        avg_coverage = sum(stats['coverage'] for stats in overall_stats.values()) / len(overall_stats)
        print(f"\n📊 OVERALL SUMMARY:")
        print(f"Average yfinance column coverage: {avg_coverage:.1f}%")
        print(f"Total yfinance columns analyzed: {len(yf_columns)}")
        print(f"Companies with any yfinance data: {yf_found_count} ({yf_found_count/total_companies*100:.1f}%)")
        print(f"Companies with no yfinance data: {yf_not_found_count} ({yf_not_found_count/total_companies*100:.1f}%)")
        
        return {
            'total_companies': total_companies,
            'nse_only': len(nse_only),
            'bse_only': len(bse_only),
            'both_codes': len(both_codes),
            'yf_found': yf_found_count,
            'yf_not_found': yf_not_found_count,
            'yf_not_set': yf_not_set_count,
            'overall_stats': overall_stats,
            'nse_stats': nse_stats,
            'bse_stats': bse_stats,
            'both_stats': both_stats,
            'avg_coverage': avg_coverage
        }
        
    finally:
        session.close()

if __name__ == "__main__":
    analyze_yfinance_coverage() 