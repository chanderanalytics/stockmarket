import sys
import json
import traceback
from typing import Optional, Dict, Any, List
import pandas as pd
from prompt_toolkit import PromptSession
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.auto_suggest import AutoSuggestFromHistory

from data_sources.database_connector import get_available_companies, get_company_financials

# Import the financial debate engine
try:
    from agents.financial_debate_engine import run_financial_debate
    DEBATE_ENGINE_AVAILABLE = True
except ImportError:
    print("⚠️ Financial debate engine not available. Install required packages with:")
    print("   pip install pyyaml langchain")
    DEBATE_ENGINE_AVAILABLE = False
from intelligence.context_builder import build_company_context

def get_company_completer() -> WordCompleter:
    """Create a WordCompleter with all available companies."""
    try:
        companies = get_available_companies()
        return WordCompleter(companies, ignore_case=True, match_middle=True, sentence=True)
    except Exception as e:
        print(f"Error creating completer: {e}")
        return WordCompleter([], ignore_case=True, match_middle=True)

def select_company() -> Optional[str]:
    """Interactive company selection with autocomplete."""
    print("\n🔍 Type to search for a company (TAB to autocomplete, Enter to select)")
    print("   Press Ctrl+C to exit\n")
    
    # Get list of company names
    companies = get_available_companies()
    
    # Create completer with company names
    session = PromptSession(
        completer=WordCompleter(companies, ignore_case=True, match_middle=True, sentence=True),
        complete_while_typing=True,
        auto_suggest=AutoSuggestFromHistory()
    )
    
    try:
        while True:
            try:
                # Get user input with autocomplete
                company_name = session.prompt("Company: ").strip()
                if not company_name:
                    continue
                
                # Check for exact match
                if company_name in companies:
                    return company_name
                
                # Try to find a matching company (case-insensitive)
                matches = [name for name in companies if company_name.lower() in name.lower()]
                
                if matches:
                    print("\nDid you mean one of these?")
                    for i, match in enumerate(matches[:5], 1):
                        print(f"  {i}. {match}")
                    print()
                else:
                    print("\n❌ No matching companies found. Try again.\n")
                    
            except KeyboardInterrupt:
                print("\n👋 Exiting...")
                return None
            except Exception as e:
                print(f"\n❌ Error: {e}\n")
                
    except Exception as e:
        print(f"\n❌ An error occurred: {e}")
        return None

def display_company_data(company_data: pd.DataFrame) -> None:
    """Display company data in a readable format."""
    if company_data.empty:
        print("\n❌ No data available for this company.")
        return
    
    # Get company name from the first row
    company_name = company_data.iloc[0]['name']
    
    # Display the data
    print(f"\n📊 {company_name} - Data")
    print("=" * 60)
    print(company_data.to_string())
    print("\n✅ Data display complete.")

def main():
    try:
        print("🔍 Project VANTAGE - Financial Analysis")
        print("=" * 60)
        
        # Get company from command line or prompt user
        if len(sys.argv) > 1:
            # If company name is provided as argument
            company_name = ' '.join(sys.argv[1:])
            print(f"Analyzing company: {company_name}")
        else:
            # Interactive selection
            company_name = select_company()
            if not company_name:
                return
        
        try:
            # Fetch company data
            print(f"\n📊 Fetching data for {company_name}...")
            company_data = get_company_financials(company_name)
            
            # Display the data
            display_company_data(company_data)
            
            # Auto-save to CSV
            import os
            os.makedirs('outputs', exist_ok=True)
            filename = f"outputs/{company_name.replace(' ', '_')}_data.csv"
            company_data.to_csv(filename, index=False)
            print(f"\n💾 Data saved to {filename}")
            
            # Auto-run financial debate if available
            if DEBATE_ENGINE_AVAILABLE:
                try:
                    print("\n🚀 Starting AI based financial debate...")
                    debate_results = run_financial_debate(company_name, company_data)
                    print("\n📝 Debate Summary:")
                    print("=" * 60)
                    
                    # Print the debate results in a nice format
                    if isinstance(debate_results, dict):
                        for category, analysis in debate_results.items():
                            if isinstance(analysis, dict):
                                print(f"\n🔹 {category.replace('_', ' ').title()} (Confidence: {analysis.get('confidence_score', 0)*100:.0f}%)")
                                print(f"   Summary: {analysis.get('summary', 'N/A')}")
                                
                                if 'bullish_points' in analysis and analysis['bullish_points']:
                                    print("\n   👍 Bullish Points:")
                                    for point in analysis['bullish_points']:
                                        print(f"     • {point}")
                                        
                                if 'bearish_points' in analysis and analysis['bearish_points']:
                                    print("\n   👎 Bearish Points:")
                                    for point in analysis['bearish_points']:
                                        print(f"     • {point}")
                                        
                                print("-" * 60)
                except Exception as e:
                    print(f"\n❌ Error running financial debate: {e}")
                    print("Make sure Ollama is running and the model is downloaded.")
                    print("You can download the model with: ollama pull llama3")
            else:
                print("\nℹ️ Financial debate engine is not available. Install required packages with:")
                print("   pip install pyyaml langchain")
                
        except Exception as e:
            print(f"\n❌ Error processing data for {company_name}:", str(e))
            if "No data found" in str(e):
                print("Please check the company name and try again.")
            
    except Exception as e:
        print("\n❌ An unexpected error occurred:", file=sys.stderr)
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
