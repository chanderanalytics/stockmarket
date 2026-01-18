import os
import re
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin

# ------------------------------------------------
# CONFIG
# ------------------------------------------------
HEADERS = {"User-Agent": "Mozilla/5.0"}
PDF_KEYWORDS = ["annual", "report", "presentation", "results", "financial", "investor"]
SEARCH_ENGINE = "https://www.google.com/search?q="  # could swap with Bing if blocked


# ------------------------------------------------
# 1️⃣ Get company official website from Google
# ------------------------------------------------
def find_official_website(company_name):
    """Find the official company website using DuckDuckGo's JSON API."""
    print(f"🔍 Searching for official website of {company_name} ...")
    try:
        query = f"{company_name} official site"
        url = f"https://api.duckduckgo.com/?q={query}&format=json&no_html=1"
        resp = requests.get(url, timeout=10)
        data = resp.json()

        candidates = []

        # Try from related topics
        for topic in data.get("RelatedTopics", []):
            if "FirstURL" in topic:
                href = topic["FirstURL"]
                if href.startswith("http") and not any(x in href for x in ["wikipedia", "facebook", "linkedin"]):
                    candidates.append(href)

        # Try from abstract URL if available
        if data.get("AbstractURL"):
            candidates.append(data["AbstractURL"])

        if not candidates:
            print("⚠️ No official site found.")
            return None

        # Pick first valid domain
        website = sorted(set(candidates))[0]
        print(f"🌍 Found official-looking site: {website}")
        return website
    except Exception as e:
        print(f"⚠️ Error fetching from DuckDuckGo: {e}")
        return None

# ------------------------------------------------
# 2️⃣ Find likely investor page
# ------------------------------------------------
def find_investor_page(homepage):
    print(f"🔎 Checking for investor/financial pages on {homepage} ...")
    try:
        resp = requests.get(homepage, headers=HEADERS, timeout=15)
        resp.raise_for_status()
    except Exception as e:
        print(f"⚠️ Could not load homepage: {e}")
        return homepage

    soup = BeautifulSoup(resp.text, "html.parser")
    for a in soup.find_all("a", href=True):
        href = a["href"].lower()
        if any(k in href for k in ["investor", "financial", "annual", "report"]):
            return urljoin(homepage, href)

    print("⚠️ No explicit investor page found, using homepage instead.")
    return homepage


# ------------------------------------------------
# 3️⃣ Crawl for PDF links
# ------------------------------------------------
def find_pdf_links(website):
    print(f"🌍 Crawling {website} for PDFs...")
    try:
        resp = requests.get(website, headers=HEADERS, timeout=15)
        resp.raise_for_status()
    except Exception as e:
        print(f"⚠️ Failed to load {website}: {e}")
        return []

    soup = BeautifulSoup(resp.text, "html.parser")
    pdf_links = []
    for a in soup.find_all("a", href=True):
        href = a["href"].lower()
        if href.endswith(".pdf") and any(k in href for k in PDF_KEYWORDS):
            pdf_links.append(urljoin(website, href))

    pdf_links = list(dict.fromkeys(pdf_links))  # deduplicate
    print(f"✅ Found {len(pdf_links)} PDF links.")
    return pdf_links


# ------------------------------------------------
# 4️⃣ Download PDFs
# ------------------------------------------------
def download_pdfs(company, pdf_links):
    save_dir = f"./pdfs/{company.replace(' ', '_')}"
    os.makedirs(save_dir, exist_ok=True)
    for link in pdf_links:
        fname = os.path.basename(link.split("?")[0])
        path = os.path.join(save_dir, fname)
        if os.path.exists(path):
            continue
        try:
            print(f"⬇️ {fname}")
            r = requests.get(link, stream=True, timeout=30)
            with open(path, "wb") as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        except Exception as e:
            print(f"⚠️ Failed: {link} ({e})")
    print(f"📁 PDFs saved in {save_dir}")


# ------------------------------------------------
# ENTRY POINT
# ------------------------------------------------
if __name__ == "__main__":
    company = input("Enter company name: ").strip()
    homepage = find_official_website(company)
    if not homepage:
        homepage = input("Enter homepage manually (https://...): ").strip()

    investor_page = find_investor_page(homepage)
    pdfs = find_pdf_links(investor_page)
    if pdfs:
        download_pdfs(company, pdfs)
    else:
        print("❌ No PDFs found.")