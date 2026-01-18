# Project VANTAGE

A financial analysis tool for evaluating company performance and generating investment insights.

## Setup

1. Create a virtual environment (recommended):
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Configure the database connection in `config/settings.yaml`

## Usage

Run the main script:
```bash
python main.py
```

Enter a company name when prompted to generate a financial context summary.

## Project Structure

- `data_sources/`: Database connectors and data retrieval
- `intelligence/`: Core analysis and context building
- `config/`: Configuration files
- `outputs/`: Generated reports and analysis

## License

MIT
