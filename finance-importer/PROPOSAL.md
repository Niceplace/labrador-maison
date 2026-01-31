# Finance CSV Importer API - Proposal

## Overview

A custom API/translation service that ingests credit card statement CSV files (4-5 years of historical data) and transforms them into the appropriate formats for:
- **Actual Budget** (envelope-based budgeting)
- **Firefly III** (double-entry bookkeeping)
- **Wallos** (subscription tracking)
- **IHateMoney** (shared expense management)

## Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  CSV Files      │────▶│  Finance Importer    │────▶│  Target Apps    │
│  (Credit Card   │     │  API                 │     │  - Actual       │
│   Statements)   │     │                      │     │  - Firefly III  │
└─────────────────┘     │  - Parser            │     │  - Wallos       │
                        │  - Validator         │     │  - IHateMoney   │
                        │  - Transformer       │     └─────────────────┘
                        │  - Dispatcher        │
                        └──────────────────────┘
```

## Project Structure

```
finance-importer/
├── docker-compose.yml
├── api/
│   ├── main.py                 # FastAPI application
│   ├── parsers/
│   │   ├── __init__.py
│   │   ├── base.py             # Base parser interface
│   │   └── csv_parser.py       # CSV parsing logic
│   ├── transformers/
│   │   ├── __init__.py
│   │   ├── actual.py           # Actual Budget transformer
│   │   ├── firefly.py          # Firefly III transformer
│   │   ├── wallos.py           # Wallos transformer
│   │   └── ihatemoney.py       # IHateMoney transformer
│   ├── clients/
│   │   ├── __init__.py
│   │   ├── actual.py           # Actual API client
│   │   ├── firefly.py          # Firefly API client
│   │   ├── wallos.py           # Wallos API client
│   │   └── ihatemoney.py       # IHateMoney API client
│   ├── models/
│   │   ├── __init__.py
│   │   └── transaction.py      # Shared transaction models
│   ├── config.py               # Configuration management
│   └── storage.py              # File storage handling
├── storage/
│   ├── incoming/               # Upload directory for CSV files
│   ├── processed/              # Successfully processed files
│   └── failed/                 # Failed processing files
└── config/
    ├── banks.yaml              # Bank-specific CSV format configs
    └── mappings.yaml           # Category and payee mappings
```

## API Specification

### 1. Upload and Parse CSV

**POST** `/api/v1/upload`

Uploads a credit card statement CSV file for processing.

```yaml
Request:
  - multipart/form-data
  - file: CSV file

Response (200 OK):
  {
    "job_id": "uuid",
    "filename": "statement_2024.csv",
    "status": "parsing",
    "transactions_detected": 0,
    "date_range": null,
    "bank_detected": null
  }
```

### 2. Get Parse Status

**GET** `/api/v1/jobs/{job_id}`

Returns the status of a parsing job.

```yaml
Response (200 OK):
  {
    "job_id": "uuid",
    "status": "parsed|processing|completed|failed",
    "filename": "statement_2024.csv",
    "transactions_detected": 234,
    "date_range": {
      "start": "2020-01-15",
      "end": "2024-12-20"
    },
    "bank_detected": "Desjardins",
    "preview": [
      {
        "date": "2024-12-15",
        "description": "AMAZON WEB SERVICES",
        "amount": -45.99,
        "currency": "CAD",
        "category": null,
        "payee": "Amazon Web Services"
      }
    ]
  }
```

### 3. Map Categories and Payees

**POST** `/api/v1/jobs/{job_id}/mappings`

Apply category and payee mappings before importing.

```yaml
Request Body:
  {
    "mappings": {
      "categories": {
        "AMAZON": "Software/Subscriptions",
        "GROCERIES": "Food: Groceries"
      },
      "payees": {
        "AMAZON WEB SERVICES": "AWS",
        "NO FRILLS": "No Frills"
      }
    },
    "defaults": {
      "uncategorized": "Uncategorized",
      "unknown_payee": "Unknown Merchant"
    }
  }
```

### 4. Preview Transformations

**GET** `/api/v1/jobs/{job_id}/preview/{target}`

Preview how transactions will be transformed for each target app.

```yaml
Response for Firefly III:
  {
    "target": "firefly-iii",
    "transactions": [
      {
        "type": "withdrawal",
        "date": "2024-12-15",
        "amount": "-45.99",
        "description": "AMAZON WEB SERVICES",
        "source_account": "Credit Card",
        "destination_name": "AWS",
        "category": "Software/Subscriptions",
        "tags": ["subscription"]
      }
    ]
  }

Response for Actual:
  {
    "target": "actual",
    "transactions": [
      {
        "date": "2024-12-15",
        "amount": -45.99,
        "payee": "AWS",
        "category": "Software/Subscriptions",
        "notes": "Imported from credit card statement",
        "imported_payee": "AMAZON WEB SERVICES"
      }
    ]
  }
```

### 5. Import to Target Apps

**POST** `/api/v1/jobs/{job_id}/import`

Imports transactions to one or more target applications.

```yaml
Request Body:
  {
    "targets": ["actual", "firefly-iii"],
    "options": {
      "actual": {
        "account_id": "account_uuid",
        "run_transfers": true,
        "learn_categories": true
      },
      "firefly-iii": {
        "account_id": 1,
        "apply_rules": true,
        "fire_webhooks": false
      }
    }
  }

Response (202 Accepted):
  {
    "job_id": "uuid",
    "status": "importing",
    "targets": ["actual", "firefly-iii"],
    "estimated_time_seconds": 60
  }
```

### 6. Get Import Status

**GET** `/api/v1/jobs/{job_id}/import/status`

```yaml
Response:
  {
    "job_id": "uuid",
    "status": "completed",
    "targets": [
      {
        "name": "actual",
        "status": "completed",
        "imported": 234,
        "failed": 0,
        "errors": []
      },
      {
        "name": "firefly-iii",
        "status": "completed",
        "imported": 234,
        "failed": 2,
        "errors": [
          "Transaction at row 45: Duplicate transaction detected"
        ]
      }
    ]
  }
```

### 7. Supported Banks

**GET** `/api/v1/banks`

Returns list of supported bank CSV formats.

```yaml
Response:
  {
    "banks": [
      {
        "name": "Desjardins",
        "country": "CA",
        "csv_format": {
          "delimiter": ",",
          "date_format": "%Y-%m-%d",
          "columns": ["date", "description", "amount", "balance"]
        },
        "sample_headers": ["Date", "Description", "Amount", "Balance"]
      },
      {
        "name": "TD Canada Trust",
        "country": "CA",
        "csv_format": {
          "delimiter": ",",
          "date_format": "%m/%d/%Y",
          "columns": ["date", "description", "amount", "category"]
        }
      }
    ]
  }
```

### 8. Configuration Endpoints

**GET** `/api/v1/config`

Get current importer configuration.

```yaml
Response:
  {
    "targets": {
      "actual": {
        "enabled": true,
        "configured": true,
        "endpoint": "http://actual:5006",
        "has_auth": true
      },
      "firefly-iii": {
        "enabled": true,
        "configured": true,
        "endpoint": "http://firefly-iii:8080",
        "has_auth": true
      },
      "wallos": {
        "enabled": true,
        "configured": false,
        "endpoint": "http://wallos/api/subscriptions/get_subscriptions.php",
        "has_auth": false
      },
      "ihatemoney": {
        "enabled": true,
        "configured": false,
        "endpoint": "http://ihatemoney:8000",
        "has_auth": false
      }
    }
  }
```

## Data Transformation Specifications

### Input CSV Format (Generic)

The API expects CSV files with the following columns (configurable per bank):

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| date | string | Yes | Transaction date (ISO 8601 or configurable format) |
| description | string | Yes | Merchant/description from statement |
| amount | decimal | Yes | Transaction amount (negative for expenses) |
| currency | string | No | Currency code (defaults to CAD) |
| category | string | No | Bank's categorization (if available) |
| reference | string | No | Transaction reference number |

### Output Format: Firefly III

```json
POST /api/v1/transactions
{
  "transactions": [
    {
      "type": "withdrawal",
      "date": "2024-12-15",
      "amount": "-45.99",
      "description": "AMAZON WEB SERVICES",
      "source_id": 1,
      "destination_name": "AWS",
      "category_name": "Software/Subscriptions",
      "tags": ["subscription"],
      "notes": "Imported from credit card statement"
    }
  ],
  "apply_rules": true,
  "fire_webhooks": false
}
```

### Output Format: Actual Budget

```json
POST /api/transactions-import
{
  "accountId": "account_uuid",
  "transactions": [
    {
      "date": "2024-12-15",
      "amount": -45.99,
      "payee": "AWS",
      "category": "Software/Subscriptions",
      "notes": "Imported from credit card statement",
      "imported_payee": "AMAZON WEB SERVICES"
    }
  ]
}
```

### Output Format: Wallos

Wallos is for **subscriptions only**. The API will:
1. Detect recurring transactions from the CSV
2. Create subscriptions via `/api/subscriptions/add_subscription.php`

```json
POST /api/subscriptions/add_subscription.php
{
  "name": "Amazon Web Services",
  "price": 45.99,
  "currency_id": 1,
  "frequency": 1,
  "cycle": 3,  // Monthly
  "next_payment": "2025-01-15",
  "category_id": 1,
  "payment_method_id": 1,
  "api_key": "user_api_key"
}
```

### Output Format: IHateMoney

IHateMoney is for **shared expenses**. The API will:
1. Ask user to select which transactions represent shared expenses
2. Create bills via `/api/projects/{id}/bills`

```json
POST /api/projects/household/bills
Authorization: Basic project_id:private_code
{
  "date": "2024-12-15",
  "what": "Shared dinner at restaurant",
  "payer": 1,
  "payed_for": [1, 2],
  "amount": 85.50
}
```

## Docker Compose Configuration

```yaml
services:
  finance-importer:
    build: .
    container_name: finance-importer
    restart: unless-stopped
    ports:
      - "8001:8000"
    volumes:
      - ./storage:/app/storage
      - ./config:/app/config
    environment:
      - TZ=America/Toronto
      # Target app configurations
      - ACTUAL_URL=http://actual:5006
      - FIREFLY_URL=http://firefly-iii:8080
      - WALLOS_URL=http://wallos
      - IHATEMONEY_URL=http://ihatemoney:8000
      # API Keys (use Docker secrets in production)
      - ACTUAL_TOKEN=${ACTUAL_TOKEN}
      - FIREFLY_TOKEN=${FIREFLY_TOKEN}
      - WALLOS_API_KEY=${WALLOS_API_KEY}
      - IHATEMONEY_PROJECT_ID=${IHATEMONEY_PROJECT_ID}
      - IHATEMONEY_TOKEN=${IHATEMONEY_TOKEN}
    networks:
      - thinknetwork
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.importer.rule=Host(`importer.thinkcenter.dev`)"
      - "traefik.http.routers.importer.entrypoints=websecure"
      - "traefik.http.services.importer.loadbalancer.server.port=8000"

networks:
  thinknetwork:
    external: true
```

## Configuration Files

### config/banks.yaml

```yaml
banks:
  desjardins:
    name: Desjardins
    country: CA
    csv_format:
      delimiter: ","
      date_format: "%Y-%m-%d"
      quote_char: '"'
      columns:
        - date
        - description
        - amount
        - balance
    column_mapping:
      date: 0
      description: 1
      amount: 2
      balance: 3

  td_canada_trust:
    name: TD Canada Trust
    country: CA
    csv_format:
      delimiter: ","
      date_format: "%m/%d/%Y"
      columns:
        - date
        - description
        - amount
        - category
```

### config/mappings.yaml

```yaml
# Category mappings from bank categories to app-specific categories
categories:
  firefly-iii:
    "GROCERY STORES": "Food: Groceries"
    "RESTAURANTS": "Food: Dining Out"
    "GAS STATIONS": "Transportation: Fuel"
    "UTILITIES": "Bills: Utilities"

  actual:
    "GROCERY STORES": "Food/Groceries"
    "RESTAURANTS": "Food/Dining Out"
    "GAS STATIONS": "Transportation/Fuel"

payees:
  # Normalize payee names
  "AMAZON": "Amazon"
  "AMAZON WEB SERVICES": "AWS"
  "NO FRILLS": "No Frills"
  "SHELL CANADA": "Shell"

# Subscription detection patterns
subscriptions:
  - pattern: "(?i)amazon|aws|netflix|spotify|youtube"
    category: "Subscriptions"
    cycle: monthly
  - pattern: "(?i)insurance.*monthly"
    category: "Bills: Insurance"
    cycle: monthly
```

## Implementation Notes

### Authentication Strategy

Each target app has different authentication:

| App | Auth Method | Storage |
|-----|-------------|---------|
| Actual | Bearer token | Environment variable |
| Firefly III | Bearer token (Personal Access Token) | Environment variable |
| Wallos | API key (per user) | Environment variable |
| IHateMoney | Basic auth or Bearer token | Environment variable |

### Duplicate Detection

- **Actual**: Built-in deduplication, can be disabled
- **Firefly III**: Duplicate detection API endpoint
- **Wallos**: Check by name + price + cycle
- **IHateMoney**: Check by date + amount + payer

### Error Handling

All errors return with appropriate HTTP status codes:

```yaml
400 Bad Request:
  - Invalid CSV format
  - Missing required fields

401 Unauthorized:
  - Invalid API credentials
  - Expired tokens

404 Not Found:
  - Job ID not found
  - Target app not configured

422 Unprocessable Entity:
  - Transaction validation failed
  - Duplicate transaction

500 Internal Server Error:
  - Target API unavailable
  - Processing error
```

### Rate Limiting

```yaml
# Recommended rate limits per target
rate_limits:
  actual: 100 requests/minute
  firefly_iii: 60 requests/minute
  wallos: 30 requests/minute
  ihatemoney: 60 requests/minute
```

## Security Considerations

1. **API Credentials**: Store in Docker secrets or vault
2. **File Upload**: Validate file types (CSV only), size limits (50MB)
3. **Input Validation**: Sanitize all CSV data
4. **HTTPS Only**: All API communications over HTTPS
5. **Audit Logging**: Log all imports with user/timestamp
6. **CORS**: Restrict to trusted origins

## Future Enhancements

1. **Machine Learning**: Auto-categorize transactions using ML
2. **Receipt OCR**: Extract data from receipt images
3. **Bank Sync**: Direct OFX download from banks
4. **Scheduled Imports**: Cron-based automatic imports
5. **Webhooks**: Notify on import completion
6. **Dashboard**: Visualization of import history
7. **Reconciliation**: Compare balances across apps
