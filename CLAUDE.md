# CLAUDE.md - Project Guide for AI Assistants

## Project Overview

**DocketWatch / Court-Beta** is a court case tracking and management system for legal research and celebrity case discovery. It monitors court cases across multiple jurisdictions, automatically matches them against a celebrity database, and manages notifications and document review workflows.

## Tech Stack

- **Backend:** Adobe ColdFusion (CFML) — `.cfm` templates and `.cfc` components
- **Database:** Microsoft SQL Server (`docketwatch` database, datasource: `Reach`)
- **Frontend:** Bootstrap 5, jQuery, DataTables, Font Awesome
- **Python scripts:** Web scraping (Selenium, BeautifulSoup) and PDF processing (PyMuPDF, ReportLab)
- **Auth:** Windows NT Authentication (`cfNTAuthenticate`) against `tmz` domain

## Directory Structure

```
/court-beta/
├── Application.cfc            # App config, auth, session management, environment detection
├── index.cfm                  # Main dashboard with case grid (DataTables)
├── case_details.cfm           # Individual case detail view
├── case_update.cfm            # Case edit/save operations
├── navbar.cfm                 # Shared navigation component
├── includes/                  # Reusable components
│   ├── functions.cfm          #   Utility functions (normalization, matching)
│   ├── parseCaseDetails.cfm   #   Case detail parsing
│   └── findNoCase.cfm         #   Case-insensitive search helper
├── css/
│   └── tmz-brand.css          # Primary stylesheet
├── docketwatch/               # Environment-specific redirect
├── *_ajax.cfm                 # AJAX data endpoints (return JSON)
├── celebrity_*.cfm            # Celebrity management pages
├── process_*.cfm              # Background processing scripts
├── *.py                       # Python scraping and PDF utilities
└── followed_cases.json        # Case tracking data
```

## Key Conventions

### Naming
- **Files:** lowercase with underscores (`case_details.cfm`, `case_matches_ajax.cfm`)
- **AJAX endpoints:** source filename with `_ajax` suffix
- **Functions:** `fnc` prefix (`fncNormalizeCaseName`, `fncIsMatch`)
- **Foreign keys:** `fk_` prefix (`fk_tool`, `fk_celebrity`, `fk_court`)
- **CF variables:** camelCase; **SQL columns:** snake_case

### Coding Patterns
- SQL queries are inline within CFM templates (no ORM)
- Always use `cfqueryparam` for query parameters (SQL injection prevention)
- Query names should be descriptive (`getCase`, `getCelebrities`, `insertCelebMatches`)
- Comments use ColdFusion syntax: `<!--- comment --->`
- Status changes (soft deletes) preferred over hard deletes
- Boolean fields use SQL `bit` type (0/1)

### Environment Detection
`Application.cfc` auto-detects the environment from the server domain:
- **docketwatch** mode vs **tmztools** mode
- File paths and datasource names adjust accordingly

### Database
- Database: `docketwatch` on SQL Server
- Key tables: `cases`, `case_events`, `celebrities`, `case_celebrity_matches`, `courts`, `counties`, `tools`, `users`, `case_email_recipients`, `case_priority`
- Use fully qualified table names: `docketwatch.dbo.[table_name]`
- Temporal columns: `created_at`, `last_updated`, `last_found`, `last_scraped`

## Build / Run / Test

There is **no formal build system, test suite, or linter**. The app runs directly on a ColdFusion application server.

- **ColdFusion pages:** Served directly by the CF engine — no compilation step needed
- **Python scripts:** Invoked via `run_python_script.cfm` or run manually
- **Deployment:** Direct file copy to server paths
- **Database migrations:** Manual SQL — no migration framework

## Important Files

| File | Purpose |
|------|---------|
| `Application.cfc` | App lifecycle, auth, environment config |
| `index.cfm` | Main dashboard — case grid with filters |
| `case_details.cfm` | Full case view (largest file ~98KB) |
| `includes/functions.cfm` | Shared utility functions |
| `docketwatch_monitor.cfm` | Monitoring dashboard (~39KB) |
| `process_cases.cfm` | Batch case processing |
| `script.py` | LA court case scraper (Selenium) |
| `script_nyc.py` | NYC court case scraper (NYSCEF) |
| `court_scrape.py` | Court data scraper (BeautifulSoup) |
| `pdf.py` / `pdf_docx.py` | PDF highlight extraction |

## Data Sources

- **LA County Courts** (lacourt.org) — primary source
- **NYSCEF** (New York State Court Electronic Filing) — NYC cases
- **PACER** (Public Access to Court Electronic Records) — federal documents

## Security Notes

- Never hardcode credentials in committed files
- Always use `cfqueryparam` for all SQL query parameters
- Python scripts that access the database should use parameterized queries
- Sensitive config (datasource passwords, server IPs) lives in ColdFusion Admin, not in code
