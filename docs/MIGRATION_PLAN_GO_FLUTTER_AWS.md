# DocketWatch Migration Plan: Go + Flutter Web + AWS

**Date:** 2026-02-28
**Migration Type:** Big-bang rewrite
**Target Stack:** Go backend, Flutter Web frontend, PostgreSQL on AWS

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [AWS Infrastructure](#2-aws-infrastructure)
3. [Go Backend Design](#3-go-backend-design)
4. [Flutter Web Frontend](#4-flutter-web-frontend)
5. [Database Migration (SQL Server → PostgreSQL)](#5-database-migration)
6. [Python Integration](#6-python-integration)
7. [Authentication](#7-authentication)
8. [Migration Phases](#8-migration-phases)
9. [API Design](#9-api-design)
10. [Risk Assessment](#10-risk-assessment)

---

## 1. Architecture Overview

### Current Stack
```
Browser → ColdFusion (CFML on IIS/Windows) → SQL Server
                 ↓
         Python scripts (subprocess)
         PACER RSS feeds (HTTP)
         Gemini API (HTTP)
```

### Target Stack
```
Browser → CloudFront CDN → Flutter Web (S3)
                              ↓ (REST/gRPC)
                          ALB → Go API (ECS Fargate)
                              ↓
                        RDS PostgreSQL
                              ↓
                    Python workers (ECS Tasks / Lambda)
                    PACER RSS feeds
                    Gemini API
```

### Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Frontend | Flutter Web (SPA) | Single codebase, strong typing, rich widgets |
| Backend | Go (net/http or Chi router) | Fast, low memory, great concurrency for background tasks |
| Database | PostgreSQL on RDS | Open-source, JSON support, better tooling on AWS |
| Python | Keep as workers, called via SQS/gRPC | Gemini SDK + OCR libraries are Python-native |
| Auth | AWS Cognito (replace NT Auth) | Cloud-native, supports SSO/SAML if needed |
| File storage | S3 | Replace Windows file shares (U:\ drive) |
| Background tasks | Go workers + SQS queues | Replace ColdFusion scheduled tasks |
| Search | PostgreSQL full-text (upgrade to OpenSearch later if needed) | Replaces CFML full-text search |

---

## 2. AWS Infrastructure

### Core Services

```
┌─────────────────────────────────────────────────────────────┐
│                        Route 53 (DNS)                       │
│                    docketwatch.tmz.tv                        │
└──────────┬──────────────────────────────────┬───────────────┘
           │                                  │
     ┌─────▼─────┐                    ┌───────▼───────┐
     │ CloudFront │                    │      ALB      │
     │   (CDN)    │                    │  (API Gateway) │
     │            │                    │               │
     │ Flutter Web│                    │ api.docket... │
     │ static SPA │                    │               │
     │ (S3 origin)│                    └───────┬───────┘
     └────────────┘                            │
                                       ┌───────▼───────┐
                                       │  ECS Fargate   │
                                       │   (Go API)     │
                                       │                │
                                       │ - REST API     │
                                       │ - WebSocket    │
                                       │ - BG workers   │
                                       └──┬─────┬──┬───┘
                                          │     │  │
                          ┌───────────────┘     │  └──────────────┐
                          │                     │                 │
                   ┌──────▼──────┐     ┌────────▼────────┐ ┌─────▼─────┐
                   │ RDS Postgres │     │   S3 Buckets    │ │    SQS    │
                   │  (primary)   │     │                 │ │  Queues   │
                   │              │     │ - docs/PDFs     │ │           │
                   │ + read       │     │ - uploads/      │ │ - summarize│
                   │   replica    │     │ - flutter-web/  │ │ - ocr     │
                   └──────────────┘     └─────────────────┘ │ - match   │
                                                            └─────┬─────┘
                                                                  │
                                                          ┌───────▼───────┐
                                                          │  ECS Tasks /  │
                                                          │  Lambda       │
                                                          │  (Python)     │
                                                          │               │
                                                          │ - OCR/PDF     │
                                                          │ - Gemini AI   │
                                                          │ - FACT_GUARD  │
                                                          └───────────────┘
```

### AWS Service Map

| Service | Purpose | Config |
|---------|---------|--------|
| **Route 53** | DNS | docketwatch.tmz.tv |
| **CloudFront** | CDN for Flutter Web SPA | S3 origin, HTTPS |
| **S3** | Flutter static files + document storage | 3 buckets: `dw-frontend`, `dw-documents`, `dw-uploads` |
| **ALB** | API load balancer | Path-based routing, health checks |
| **ECS Fargate** | Go API containers | Auto-scaling 2-8 tasks, 0.5 vCPU / 1GB |
| **ECS Tasks** | Python worker containers | On-demand, triggered by SQS |
| **RDS PostgreSQL** | Primary database | db.r6g.large, Multi-AZ, 16.x |
| **SQS** | Job queues (summarize, OCR, match) | Standard queues, DLQ for failures |
| **Cognito** | Authentication | User pool, replace NT Auth |
| **Secrets Manager** | API keys (Gemini, PACER) | Rotate-capable |
| **CloudWatch** | Logging + monitoring | Structured JSON logs |
| **ECR** | Container registry | Go API + Python worker images |

### Estimated Monthly Cost (Baseline)

| Service | Est. Cost |
|---------|-----------|
| ECS Fargate (Go API, 2 tasks) | ~$60 |
| ECS Tasks (Python workers, on-demand) | ~$20 |
| RDS PostgreSQL (db.r6g.large, Multi-AZ) | ~$350 |
| S3 + CloudFront | ~$15 |
| ALB | ~$25 |
| SQS, Cognito, Secrets Manager | ~$10 |
| CloudWatch | ~$20 |
| **Total** | **~$500/mo** |

---

## 3. Go Backend Design

### Project Structure

```
docketwatch-api/
├── cmd/
│   ├── api/                    # Main API server
│   │   └── main.go
│   └── worker/                 # Background worker
│       └── main.go
├── internal/
│   ├── config/                 # Configuration (env vars, AWS Secrets Manager)
│   │   └── config.go
│   ├── auth/                   # Cognito JWT middleware
│   │   ├── middleware.go
│   │   └── cognito.go
│   ├── handler/                # HTTP handlers (grouped by domain)
│   │   ├── cases.go            # /api/cases/*
│   │   ├── events.go           # /api/events/*
│   │   ├── documents.go        # /api/documents/*
│   │   ├── celebrities.go      # /api/celebrities/*
│   │   ├── matches.go          # /api/matches/*
│   │   ├── tools.go            # /api/tools/*
│   │   ├── users.go            # /api/users/*
│   │   ├── monitor.go          # /api/monitor/*
│   │   ├── summarize.go        # /api/summarize/*
│   │   ├── headlines.go        # /api/headlines/*
│   │   ├── reference.go        # /api/states, /api/counties, /api/courts
│   │   └── tasks.go            # /api/tasks/*
│   ├── service/                # Business logic layer
│   │   ├── case_service.go
│   │   ├── event_service.go
│   │   ├── document_service.go
│   │   ├── celebrity_service.go
│   │   ├── match_service.go
│   │   ├── summarize_service.go
│   │   ├── monitor_service.go
│   │   └── notification_service.go
│   ├── repository/             # Database access (pgx)
│   │   ├── case_repo.go
│   │   ├── event_repo.go
│   │   ├── document_repo.go
│   │   ├── celebrity_repo.go
│   │   ├── match_repo.go
│   │   ├── court_repo.go
│   │   ├── user_repo.go
│   │   └── task_repo.go
│   ├── model/                  # Domain models (structs)
│   │   ├── case.go
│   │   ├── event.go
│   │   ├── document.go
│   │   ├── celebrity.go
│   │   ├── match.go
│   │   ├── court.go
│   │   ├── user.go
│   │   └── task.go
│   ├── worker/                 # Background job handlers
│   │   ├── rss_poller.go       # PACER RSS feed polling
│   │   ├── celebrity_matcher.go
│   │   ├── cleanup.go
│   │   ├── email_notifier.go
│   │   └── sqs_consumer.go     # SQS queue consumer
│   └── storage/                # S3 file operations
│       └── s3.go
├── migrations/                 # SQL migration files (golang-migrate)
│   ├── 001_initial_schema.up.sql
│   ├── 001_initial_schema.down.sql
│   └── ...
├── Dockerfile
├── docker-compose.yml          # Local dev (Go + Postgres + LocalStack)
├── go.mod
├── go.sum
└── Makefile
```

### Key Go Libraries

| Library | Purpose |
|---------|---------|
| `github.com/go-chi/chi/v5` | HTTP router |
| `github.com/jackc/pgx/v5` | PostgreSQL driver (native, not database/sql) |
| `github.com/golang-migrate/migrate/v4` | Database migrations |
| `github.com/aws/aws-sdk-go-v2` | AWS SDK (S3, SQS, Secrets Manager, Cognito) |
| `github.com/golang-jwt/jwt/v5` | JWT parsing for Cognito tokens |
| `github.com/rs/zerolog` | Structured logging |
| `github.com/go-playground/validator/v10` | Request validation |

### ColdFusion → Go Endpoint Mapping

#### Pages → Go API Endpoints (Flutter consumes these)

| ColdFusion Page | Go API Endpoint | Method |
|----------------|-----------------|--------|
| `index.cfm` + `cases_ajax.cfm` | `GET /api/cases` | Paginated, filtered list |
| `case_details.cfm` | `GET /api/cases/{id}` | Full case with relations |
| `case_events.cfm` + `case_events_data.cfm` | `GET /api/events` | Unacknowledged events |
| `celebrity_gallery.cfm` + `celeb_gallery_ajax.cfm` | `GET /api/celebrities` | Paginated gallery |
| `celebrity_details.cfm` | `GET /api/celebrities/{id}` | Full celebrity profile |
| `case_matches.cfm` + `case_matches_ajax.cfm` | `GET /api/matches` | Celebrity-case matches |
| `docketwatch_monitor.cfm` + `*_data.cfm` | `GET /api/monitor/events` | Live monitor feed |
| `ai_success_dashboard.cfm` | `GET /api/dashboard/ai` | AI metrics |
| `tools/summarize/index.cfm` | `POST /api/documents/summarize` | Upload + summarize |
| `calendar.cfm` | `GET /api/hearings` | Calendar data |
| `error_log.cfm` | `GET /api/admin/errors` | Error log viewer |
| `scheduled_task_log.cfm` | `GET /api/admin/tasks` | Task history |

#### AJAX Write Endpoints → Go API Mutations

| ColdFusion Endpoint | Go API Endpoint | Method |
|--------------------|-----------------|--------|
| `insert_new_case.cfm` / `case_add.cfm` | `POST /api/cases` | Create case |
| `save_case_update.cfm` | `PUT /api/cases/{id}` | Update case |
| `update_case_status.cfm` | `PATCH /api/cases/{id}/status` | Change status |
| `update_case_status_list.cfm` | `PATCH /api/cases/bulk-status` | Bulk status |
| `ajax_acknowledgeEvent.cfm` | `POST /api/events/{id}/acknowledge` | Acknowledge |
| `ajax_getPacerDoc.cfm` | `POST /api/documents/{id}/download-pacer` | PACER download |
| `ajax_generateSummary.cfm` | `POST /api/documents/{id}/summarize` | Generate summary |
| `ajax/upload_and_summarize.cfm` | `POST /api/documents/upload` | Upload PDF |
| `ajax/ask_document_question.cfm` | `POST /api/documents/{id}/ask` | Q&A |
| `ajax/save_qc_feedback.cfm` | `POST /api/documents/{id}/qc-feedback` | Save QC |
| `ajax/save_prompt_feedback.cfm` | `POST /api/documents/{id}/prompt-feedback` | Save feedback |
| `ajax/load_conversation_history.cfm` | `GET /api/documents/{id}/conversations` | Chat history |
| `insert_case_celebrity.cfm` | `POST /api/matches` | Link celebrity |
| `delete_case_celebrity.cfm` | `DELETE /api/matches/{id}` | Remove match |
| `update_match_status.cfm` | `PATCH /api/matches/{id}/status` | Update match |
| `insert_new_celebrity.cfm` | `POST /api/celebrities` | Add celebrity |
| `insert_case_subscriber.cfm` | `POST /api/cases/{id}/subscribers` | Subscribe |
| `delete_case_subscriber.cfm` | `DELETE /api/cases/{id}/subscribers/{uid}` | Unsubscribe |
| `save_column_visibility.cfm` | `PUT /api/users/me/preferences` | Save prefs |
| `save_tool.cfm` | `POST /api/tools` | Create/update tool |
| `save_headline_update.cfm` | `PUT /api/headlines/{id}` | Edit headline |

#### Reference Data Endpoints

| ColdFusion | Go API | Method |
|-----------|--------|--------|
| `get_states.cfm` | `GET /api/reference/states` | List states |
| `get_counties.cfm` | `GET /api/reference/counties` | List counties |
| `get_courthouses.cfm` | `GET /api/reference/courts` | List courts |
| `get_tools.cfm` | `GET /api/reference/tools` | List tools |
| `get_celebrities.cfm` | `GET /api/reference/celebrities` | Celebrity dropdown |

#### Background Tasks → Go Workers

| ColdFusion Task | Go Worker |
|----------------|-----------|
| `check_case_updates.cfm` | `worker/rss_poller.go` — cron job polling PACER RSS |
| `process_celebrity_matches.cfm` | `worker/celebrity_matcher.go` — SQS triggered |
| `process_cases.cfm` | `worker/rss_poller.go` — case processing pipeline |
| `daily_removal.cfm` | `worker/cleanup.go` — scheduled cleanup |
| `cleanup_removed_unfiled_pdfs.cfm` | `worker/cleanup.go` — S3 + DB cleanup |
| `email_match.cfm` | `worker/email_notifier.go` — SES email notifications |
| `encoding_cleanup.cfm` | Not needed (proper encoding from day 1) |

---

## 4. Flutter Web Frontend

### Project Structure

```
docketwatch-web/
├── lib/
│   ├── main.dart
│   ├── app.dart                    # MaterialApp, routing, theme
│   ├── config/
│   │   ├── api_config.dart         # Base URL, headers
│   │   ├── theme.dart              # Light/dark themes
│   │   └── routes.dart             # Route definitions
│   ├── models/                     # Data models (freezed / json_serializable)
│   │   ├── case_model.dart
│   │   ├── event_model.dart
│   │   ├── document_model.dart
│   │   ├── celebrity_model.dart
│   │   ├── match_model.dart
│   │   ├── court_model.dart
│   │   └── user_model.dart
│   ├── services/                   # API client layer
│   │   ├── api_client.dart         # HTTP client (dio)
│   │   ├── auth_service.dart       # Cognito auth
│   │   ├── case_service.dart
│   │   ├── event_service.dart
│   │   ├── document_service.dart
│   │   ├── celebrity_service.dart
│   │   └── monitor_service.dart
│   ├── providers/                  # State management (Riverpod)
│   │   ├── case_provider.dart
│   │   ├── event_provider.dart
│   │   ├── auth_provider.dart
│   │   └── filter_provider.dart
│   ├── screens/                    # Full pages
│   │   ├── dashboard/              # index.cfm replacement
│   │   │   └── dashboard_screen.dart
│   │   ├── case_detail/            # case_details.cfm
│   │   │   └── case_detail_screen.dart
│   │   ├── events/                 # case_events.cfm
│   │   │   └── events_screen.dart
│   │   ├── celebrities/            # celebrity_gallery.cfm + details
│   │   │   ├── gallery_screen.dart
│   │   │   └── detail_screen.dart
│   │   ├── matches/                # case_matches.cfm
│   │   │   └── matches_screen.dart
│   │   ├── monitor/                # docketwatch_monitor.cfm
│   │   │   └── monitor_screen.dart
│   │   ├── summarize/              # tools/summarize/index.cfm
│   │   │   └── summarize_screen.dart
│   │   ├── calendar/               # calendar.cfm
│   │   │   └── calendar_screen.dart
│   │   ├── admin/                  # error_log, tasks, tools
│   │   │   ├── error_log_screen.dart
│   │   │   ├── tasks_screen.dart
│   │   │   └── tools_screen.dart
│   │   ├── headlines/              # damz_headlines.cfm
│   │   │   └── headlines_screen.dart
│   │   └── login/
│   │       └── login_screen.dart
│   └── widgets/                    # Reusable components
│       ├── data_table.dart         # Replaces jQuery DataTables
│       ├── case_card.dart
│       ├── event_card.dart
│       ├── celebrity_chip.dart
│       ├── pdf_viewer.dart
│       ├── file_upload.dart
│       ├── filter_bar.dart
│       ├── summary_card.dart
│       └── navigation_rail.dart
├── web/
│   └── index.html
├── test/
├── pubspec.yaml
└── analysis_options.yaml
```

### Key Flutter Packages

| Package | Purpose |
|---------|---------|
| `dio` | HTTP client |
| `riverpod` | State management |
| `go_router` | Declarative routing |
| `freezed` / `json_serializable` | Immutable models + JSON |
| `data_table_2` | Advanced data tables (replaces jQuery DataTables) |
| `syncfusion_flutter_calendar` | Calendar widget |
| `file_picker` | PDF upload |
| `flutter_pdfview` or `pdfx` | In-app PDF viewing |
| `amazon_cognito_identity_dart_2` | Cognito auth |

### ColdFusion Page → Flutter Screen Mapping

| ColdFusion Page | Flutter Screen | Notes |
|----------------|----------------|-------|
| `index.cfm` | `DashboardScreen` | Data table with filters, bulk actions |
| `case_details.cfm` | `CaseDetailScreen` | Tabbed view: events, docs, celebrities, subscribers |
| `case_events.cfm` | `EventsScreen` | Alert cards with acknowledge buttons |
| `celebrity_gallery.cfm` | `GalleryScreen` | Grid of celebrity cards with filters |
| `celebrity_details.cfm` | `CelebrityDetailScreen` | Profile + linked cases |
| `case_matches.cfm` | `MatchesScreen` | Sortable match table |
| `docketwatch_monitor.cfm` | `MonitorScreen` | Real-time feed (WebSocket) with dark theme |
| `ai_success_dashboard.cfm` | `AiDashboardScreen` | Charts + metrics |
| `tools/summarize/index.cfm` | `SummarizeScreen` | Drag-and-drop upload, live progress |
| `calendar.cfm` | `CalendarScreen` | Monthly/weekly hearing calendar |
| `error_log.cfm` | `ErrorLogScreen` | Filterable log table |
| `scheduled_task_log.cfm` | `TasksScreen` | Task history table |
| `tools.cfm` | `ToolsScreen` | Tool management CRUD |
| `damz_headlines.cfm` | `HeadlinesScreen` | Headline review/edit |
| `dwloginform.cfm` | `LoginScreen` | Cognito login form |

---

## 5. Database Migration

### SQL Server → PostgreSQL Type Mapping

| SQL Server Type | PostgreSQL Type |
|----------------|-----------------|
| `INT IDENTITY` | `SERIAL` or `INT GENERATED ALWAYS AS IDENTITY` |
| `UNIQUEIDENTIFIER` | `UUID` (use `gen_random_uuid()`) |
| `NVARCHAR(MAX)` | `TEXT` |
| `NVARCHAR(n)` | `VARCHAR(n)` |
| `BIT` | `BOOLEAN` |
| `DATETIME2(7)` | `TIMESTAMPTZ` |
| `DATETIME` | `TIMESTAMPTZ` |
| `MONEY` | `NUMERIC(19,4)` |
| `VARBINARY(MAX)` | `BYTEA` |
| `FLOAT` | `DOUBLE PRECISION` |

### Core Tables to Migrate

```sql
-- 1. cases
CREATE TABLE cases (
    id              SERIAL PRIMARY KEY,
    case_number     VARCHAR(100) NOT NULL,
    case_name       TEXT,
    case_type       VARCHAR(50),
    court_code      VARCHAR(20) REFERENCES courts(court_code),
    status          VARCHAR(20) DEFAULT 'Review',
    owner           VARCHAR(100),
    tool_id         INT REFERENCES tools(id),
    filing_date     DATE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 2. case_events
CREATE TABLE case_events (
    id                  SERIAL PRIMARY KEY,
    fk_case             INT NOT NULL REFERENCES cases(id),
    event_date          DATE,
    event_description   TEXT,
    event_url           TEXT,
    is_doc              BOOLEAN DEFAULT FALSE,
    acknowledged        BOOLEAN DEFAULT FALSE,
    acknowledged_at     TIMESTAMPTZ,
    acknowledged_by     VARCHAR(100),
    processing          BOOLEAN DEFAULT FALSE,
    storyworthy         BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 3. documents
CREATE TABLE documents (
    id                          SERIAL PRIMARY KEY,
    doc_uid                     UUID DEFAULT gen_random_uuid(),
    fk_case_event               INT REFERENCES case_events(id),
    pdf_title                   TEXT,
    rel_path                    TEXT,
    s3_key                      TEXT,        -- NEW: S3 object key
    file_size                   INT,
    sha256_hash                 VARCHAR(64),
    ocr_text                    TEXT,
    summary_ai                  TEXT,
    summary_ai_html             TEXT,
    summary_ai_extraction_json  JSONB,       -- JSONB instead of TEXT
    model_name                  VARCHAR(50),
    processing_ms               INT,
    tokens_input                INT,
    tokens_output               INT,
    created_at                  TIMESTAMPTZ DEFAULT NOW()
);

-- 4. celebrities
CREATE TABLE celebrities (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    tmz_celeb_id    INT,
    image_url       TEXT,
    verified        BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 5. case_celebrity_matches
CREATE TABLE case_celebrity_matches (
    id              SERIAL PRIMARY KEY,
    fk_case         INT NOT NULL REFERENCES cases(id),
    fk_celebrity    INT NOT NULL REFERENCES celebrities(id),
    match_status    VARCHAR(20) DEFAULT 'Pending',
    match_score     NUMERIC(5,2),
    matched_by      VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(fk_case, fk_celebrity)
);

-- 6. courts
CREATE TABLE courts (
    id              SERIAL PRIMARY KEY,
    court_code      VARCHAR(20) UNIQUE NOT NULL,
    court_name      TEXT NOT NULL,
    address         TEXT,
    fk_county       INT REFERENCES counties(id),
    court_type      VARCHAR(50)
);

-- 7. counties + states
CREATE TABLE states (
    state_code  VARCHAR(2) PRIMARY KEY,
    state_name  VARCHAR(100) NOT NULL
);

CREATE TABLE counties (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    state_code  VARCHAR(2) REFERENCES states(state_code)
);

-- 8. users
CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(100) UNIQUE NOT NULL,
    email       VARCHAR(255),
    first_name  VARCHAR(100),
    last_name   VARCHAR(100),
    role        VARCHAR(20) DEFAULT 'user',
    cognito_sub VARCHAR(255) UNIQUE,  -- NEW: Cognito user ID
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 9. AI/Monitoring tables
CREATE TABLE gemini_api_log (
    id                  SERIAL PRIMARY KEY,
    script_name         VARCHAR(200),
    model_name          VARCHAR(50),
    input_tokens        INT,
    output_tokens       INT,
    success             BOOLEAN,
    error_message       TEXT,
    processing_time_ms  INT,
    cost_estimate       NUMERIC(10,6),
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE summary_qc_feedback (
    id              SERIAL PRIMARY KEY,
    fk_document     INT REFERENCES documents(id),
    rating          VARCHAR(20),
    notes           TEXT,
    upload_sha256   VARCHAR(64),
    username        VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE document_prompts (
    id              SERIAL PRIMARY KEY,
    fk_document     INT REFERENCES documents(id),
    session_id      UUID,
    prompt_text     TEXT,
    response_text   TEXT,
    cited_fields    JSONB,
    model_name      VARCHAR(50),
    tokens_input    INT,
    tokens_output   INT,
    rating          INT,
    feedback        TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Supporting tables
CREATE TABLE tools (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    tool_type       VARCHAR(50),
    api_endpoint    TEXT,
    credentials     JSONB,      -- encrypted at app level
    active          BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE case_email_recipients (
    id          SERIAL PRIMARY KEY,
    fk_case     INT NOT NULL REFERENCES cases(id),
    username    VARCHAR(100) NOT NULL,
    notify      BOOLEAN DEFAULT TRUE,
    UNIQUE(fk_case, username)
);

CREATE TABLE articles (
    id              SERIAL PRIMARY KEY,
    fk_case         INT REFERENCES cases(id),
    headline        TEXT,
    subhead         TEXT,
    body_html       TEXT,
    image_url       TEXT,
    model_name      VARCHAR(50),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE scheduled_task_log (
    id              SERIAL PRIMARY KEY,
    task_name       VARCHAR(200),
    status          VARCHAR(20),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    duration_ms     INT,
    result          TEXT,
    error_message   TEXT
);

CREATE TABLE user_preferences (
    id              SERIAL PRIMARY KEY,
    fk_user         INT REFERENCES users(id),
    preference_key  VARCHAR(100),
    preference_value JSONB,
    UNIQUE(fk_user, preference_key)
);

-- Indexes
CREATE INDEX idx_cases_status ON cases(status);
CREATE INDEX idx_cases_court_code ON cases(court_code);
CREATE INDEX idx_case_events_fk_case ON case_events(fk_case);
CREATE INDEX idx_case_events_acknowledged ON case_events(acknowledged);
CREATE INDEX idx_documents_fk_case_event ON documents(fk_case_event);
CREATE INDEX idx_documents_doc_uid ON documents(doc_uid);
CREATE INDEX idx_case_celebrity_matches_fk_case ON case_celebrity_matches(fk_case);
CREATE INDEX idx_case_celebrity_matches_fk_celebrity ON case_celebrity_matches(fk_celebrity);
CREATE INDEX idx_gemini_api_log_created ON gemini_api_log(created_at);
CREATE INDEX idx_documents_extraction_json ON documents USING GIN(summary_ai_extraction_json);

-- Full-text search indexes
CREATE INDEX idx_cases_fts ON cases USING GIN(to_tsvector('english', case_name || ' ' || case_number));
CREATE INDEX idx_documents_fts ON documents USING GIN(to_tsvector('english', COALESCE(ocr_text, '')));
```

### Data Migration Tool

Use `pgloader` for automated SQL Server → PostgreSQL migration:

```bash
# pgloader config (migrate.load)
LOAD DATABASE
    FROM mssql://user:pass@sqlserver-host/docketwatch
    INTO postgresql://user:pass@rds-host/docketwatch
ALTER SCHEMA 'dbo' RENAME TO 'public'
SET maintenance_work_mem to '512MB'
;
```

After migration:
1. Verify row counts match
2. Run integrity checks (foreign keys)
3. Test all queries against PostgreSQL
4. Migrate file paths → S3 keys in `documents.s3_key`

---

## 6. Python Integration

### Architecture: Go ↔ Python via SQS

```
Go API                        SQS Queue                     Python Worker
──────                        ─────────                     ─────────────
POST /documents/upload  ──►  sqs:dw-summarize-queue  ──►  summarize_worker.py
POST /documents/{id}/ask ──► sqs:dw-qa-queue         ──►  qa_worker.py
POST /documents/{id}/    ──► sqs:dw-ocr-queue        ──►  ocr_worker.py
  download-pacer

Python writes results directly to RDS PostgreSQL.
Go API polls for completion or gets notified via SQS response queue.
```

### Python Worker Dockerfile

```dockerfile
FROM python:3.12-slim

RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY python/ .

CMD ["python", "worker.py"]
```

### Python Files to Adapt

| Current File | New Worker | Changes Needed |
|-------------|------------|----------------|
| `summarize_upload_cli.py` | `summarize_worker.py` | Read from SQS, write to PostgreSQL (psycopg2), read PDF from S3 |
| `answer_from_json.py` | `qa_worker.py` | Read from SQS, use psycopg2, write response to DB |
| `combined_pacer_pdf_processor.py` | `pacer_worker.py` | Download to S3 instead of filesystem |
| `delete_unfiled_pdfs.py` | Absorbed into Go `cleanup` worker | Delete from S3, simple enough for Go |

### Key Python Changes

1. **Replace `pyodbc`** with `psycopg2` (PostgreSQL)
2. **Replace filesystem** ops with `boto3` S3 operations
3. **Replace CLI args** with SQS message parsing
4. **Add structured logging** (JSON to CloudWatch)
5. **Keep Gemini API** code unchanged

---

## 7. Authentication

### Replace NT Auth with AWS Cognito

| Current (NT Auth) | New (Cognito) |
|-------------------|---------------|
| `cfnTAuthenticate` on "tmz" domain | Cognito User Pool |
| Session cookie (4hr timeout) | JWT access token (1hr) + refresh token (30d) |
| `getAuthUser()` returns username | JWT `sub` claim + custom `username` attribute |
| `Application.cfc` session check | Go middleware validates JWT |
| `?bypass=1` for AJAX | API key for service-to-service calls |

### Cognito Setup

```
User Pool: docketwatch-users
├── Sign-in: username + password
├── MFA: Optional TOTP
├── Custom attributes: username, role, department
├── App client: docketwatch-web (public, PKCE flow)
└── Domain: auth.docketwatch.tmz.tv
```

### Go Auth Middleware

```go
func AuthMiddleware(cognitoIssuer, clientID string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            token := r.Header.Get("Authorization") // "Bearer <jwt>"
            claims, err := validateCognitoJWT(token, cognitoIssuer, clientID)
            if err != nil {
                http.Error(w, "Unauthorized", 401)
                return
            }
            ctx := context.WithValue(r.Context(), "user", claims)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

### Migration Path for Users

1. Export users from NT/Active Directory
2. Bulk create in Cognito (CSV import or `AdminCreateUser`)
3. Force password reset on first login
4. Map existing `username` field to Cognito custom attribute

---

## 8. Migration Phases

### Phase 1: Foundation (Weeks 1-3)

**Goal:** Runnable Go API skeleton + PostgreSQL schema + AWS infra

- [ ] Set up AWS infrastructure (Terraform/CDK)
  - VPC, subnets, security groups
  - RDS PostgreSQL instance
  - ECS cluster + task definitions
  - S3 buckets
  - Cognito user pool
  - SQS queues
- [ ] Create Go project skeleton (`cmd/api`, `internal/`)
- [ ] Write PostgreSQL migration files (all tables from Section 5)
- [ ] Implement auth middleware (Cognito JWT)
- [ ] Implement health check endpoint
- [ ] Set up CI/CD pipeline (GitHub Actions → ECR → ECS)
- [ ] Docker Compose for local dev (Go + PostgreSQL + LocalStack)

**Deliverable:** `GET /health` returns 200 on ECS, database migrations run

---

### Phase 2: Core Data API (Weeks 4-7)

**Goal:** All CRUD endpoints for cases, events, documents, celebrities

- [ ] **Cases API** (12 endpoints)
  - `GET/POST /api/cases`
  - `GET/PUT/DELETE /api/cases/{id}`
  - `PATCH /api/cases/{id}/status`
  - `PATCH /api/cases/bulk-status`
  - `POST /api/cases/{id}/subscribers`
  - `DELETE /api/cases/{id}/subscribers/{uid}`
  - `GET /api/cases/{id}/summary`
- [ ] **Events API** (4 endpoints)
  - `GET /api/events` (unacknowledged)
  - `GET /api/cases/{id}/events`
  - `POST /api/events/{id}/acknowledge`
  - `POST /api/events/bulk-acknowledge`
- [ ] **Documents API** (8 endpoints)
  - `GET /api/documents/{id}`
  - `POST /api/documents/upload`
  - `POST /api/documents/{id}/summarize`
  - `POST /api/documents/{id}/download-pacer`
  - `POST /api/documents/{id}/ask`
  - `GET /api/documents/{id}/conversations`
  - `POST /api/documents/{id}/qc-feedback`
  - `POST /api/documents/{id}/prompt-feedback`
- [ ] **Celebrities API** (5 endpoints)
  - `GET/POST /api/celebrities`
  - `GET /api/celebrities/{id}`
  - `GET /api/celebrities/search`
- [ ] **Matches API** (4 endpoints)
  - `GET/POST /api/matches`
  - `DELETE /api/matches/{id}`
  - `PATCH /api/matches/{id}/status`
- [ ] **Reference Data API** (5 endpoints)
  - `GET /api/reference/states`
  - `GET /api/reference/counties`
  - `GET /api/reference/courts`
  - `GET /api/reference/tools`
  - `GET /api/reference/celebrities`
- [ ] Server-side pagination, sorting, filtering (replaces DataTables server-side)
- [ ] Write Go tests for all endpoints

**Deliverable:** Full REST API exercisable via curl/Postman

---

### Phase 3: Python Workers (Weeks 5-7, parallel with Phase 2)

**Goal:** Python scripts running as SQS consumers on ECS

- [ ] Adapt `summarize_upload_cli.py` → `summarize_worker.py`
  - Read job from SQS
  - Download PDF from S3
  - Run FACT_GUARD pipeline
  - Write results to PostgreSQL
  - Send completion message
- [ ] Adapt `answer_from_json.py` → `qa_worker.py`
  - Read question from SQS
  - Query PostgreSQL for extraction JSON
  - Call Gemini API
  - Write answer to PostgreSQL
- [ ] Adapt `combined_pacer_pdf_processor.py` → `pacer_worker.py`
  - Download PDF from PACER
  - Upload to S3
  - Write metadata to PostgreSQL
- [ ] Build Python Docker image with OCR dependencies
- [ ] Test end-to-end: Go API → SQS → Python → PostgreSQL
- [ ] Set up DLQ for failed jobs

**Deliverable:** Summarization, Q&A, and PACER download working through SQS

---

### Phase 4: Background Workers in Go (Weeks 7-8)

**Goal:** Replace ColdFusion scheduled tasks

- [ ] RSS poller (`worker/rss_poller.go`)
  - Poll PACER RSS feeds on schedule
  - Insert new case events
  - Queue document downloads
- [ ] Celebrity matcher (`worker/celebrity_matcher.go`)
  - Port `fncNormalizeCaseName` + `fncIsMatch` to Go
  - Run on new case events
- [ ] Cleanup worker (`worker/cleanup.go`)
  - Daily removal of old/unfiled docs
  - S3 object cleanup
- [ ] Email notifier (`worker/email_notifier.go`)
  - SES integration for case update emails
- [ ] Task scheduler using Go cron library or ECS scheduled tasks

**Deliverable:** All background processing automated

---

### Phase 5: Flutter Web Frontend (Weeks 6-12, parallel with Phases 3-4)

**Goal:** Complete Flutter Web SPA replacing all ColdFusion pages

- [ ] **Week 6-7: Scaffolding**
  - Flutter project setup
  - Routing (go_router)
  - Auth flow (Cognito)
  - API client (dio)
  - State management (Riverpod)
  - Theme (light/dark, matching TMZ brand)
  - Navigation rail/drawer
- [ ] **Week 8-9: Core Screens**
  - Dashboard (cases data table with filters)
  - Case detail (tabbed: events, documents, celebrities, subscribers)
  - Events screen (alert cards + acknowledge)
  - Document viewer (PDF display + AI summary panel)
- [ ] **Week 9-10: Celebrity & Matching**
  - Celebrity gallery (grid with filters)
  - Celebrity detail
  - Matches screen
  - Celebrity search/link modals
- [ ] **Week 10-11: Tools & Monitoring**
  - Monitor screen (WebSocket live feed, dark theme)
  - Summarize tool (drag-drop upload, progress, Q&A chat)
  - Calendar (hearing schedule)
  - Headlines screen
- [ ] **Week 11-12: Admin & Polish**
  - Error log viewer
  - Task history
  - Tool management
  - User preferences
  - Responsive layout testing
  - Loading states, error states, empty states

**Deliverable:** Full Flutter Web app deployed to S3/CloudFront

---

### Phase 6: Data Migration & Cutover (Weeks 12-13)

**Goal:** Migrate production data and switch over

- [ ] Run `pgloader` migration from SQL Server → RDS PostgreSQL
- [ ] Migrate files from Windows file shares → S3
  - `U:\docketwatch\docs\cases\*` → `s3://dw-documents/cases/*`
  - `U:\docketwatch\uploads\*` → `s3://dw-uploads/*`
- [ ] Migrate users from Active Directory → Cognito
- [ ] Verify data integrity (row counts, foreign keys, spot checks)
- [ ] Update DNS (Route 53)
- [ ] Smoke test all screens and workflows
- [ ] Keep old system read-only for 2 weeks as rollback

**Deliverable:** Production traffic on new stack

---

## 9. API Design

### Standard Response Format

```json
{
  "data": { ... },
  "meta": {
    "page": 1,
    "per_page": 25,
    "total": 150,
    "total_pages": 6
  }
}
```

### Error Response Format

```json
{
  "error": {
    "code": "CASE_NOT_FOUND",
    "message": "Case with ID 999 not found",
    "details": null
  }
}
```

### Pagination & Filtering

All list endpoints support:
```
GET /api/cases?page=1&per_page=25&sort=created_at&order=desc
    &status=Tracked
    &tool_id=3
    &state=CA
    &celebrity_id=42
    &q=search+term
```

This replaces DataTables server-side processing with a standard REST pattern that Flutter can consume directly.

---

## 10. Risk Assessment

### High Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Data loss during migration | Critical | Run pgloader in dry-run mode first; maintain SQL Server read-only for 2 weeks post-cutover |
| Feature parity gaps | High | Catalog every ColdFusion page (done — 139 files), check off each during Flutter build |
| Python worker reliability | High | DLQ for failed SQS messages; CloudWatch alarms on error rates |
| Authentication disruption | High | Pre-migrate users to Cognito; test SSO flow thoroughly |
| Performance regression | Medium | Load test Go API before cutover; RDS read replicas if needed |

### Medium Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Flutter Web performance with large tables | Medium | Virtual scrolling, server-side pagination |
| S3 latency vs local filesystem | Medium | CloudFront caching for frequently accessed PDFs |
| Team Go/Flutter learning curve | Medium | Start with core CRUD endpoints; use established patterns |
| PACER integration differences | Medium | Test PACER RSS polling against staging before cutover |

### What Gets Dropped (Intentionally)

| Item | Reason |
|------|--------|
| `encoding_cleanup.cfm` | Proper UTF-8 handling from day 1 in Go |
| `log_fix.cfm` / `log_fix_name.cfm` | Structured logging (CloudWatch) eliminates need |
| `run_python_script.cfm` | Dev-only tool, use ECS exec or CLI |
| `api_calls_insert.cfm` | One-time migration script, not needed |
| Duplicate endpoints (`case_add` vs `add_blank_case` vs `add_case2`) | Consolidate to single `POST /api/cases` |
| `?bypass=1` auth bypass | Replace with proper API key auth for service calls |
| NT Authentication | Replaced by Cognito |
| Windows file shares | Replaced by S3 |

---

## Timeline Summary

| Phase | Weeks | Focus |
|-------|-------|-------|
| 1. Foundation | 1-3 | AWS infra, Go skeleton, DB schema, CI/CD |
| 2. Core Data API | 4-7 | All REST endpoints in Go |
| 3. Python Workers | 5-7 | SQS consumers (parallel with Phase 2) |
| 4. Go Background Workers | 7-8 | RSS polling, matching, cleanup, email |
| 5. Flutter Web | 6-12 | All screens (parallel with Phases 3-4) |
| 6. Data Migration & Cutover | 12-13 | pgloader, S3 migration, DNS switch |

**Total estimated duration: ~13 weeks**
