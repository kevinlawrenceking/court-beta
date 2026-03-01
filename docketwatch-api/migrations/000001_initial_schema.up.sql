-- DocketWatch Initial Schema for PostgreSQL
-- Migrated from SQL Server (docketwatch.dbo.*)

BEGIN;

-- Reference tables first (no foreign key deps)

CREATE TABLE states (
    state_code  VARCHAR(2) PRIMARY KEY,
    state_name  VARCHAR(100) NOT NULL
);

CREATE TABLE counties (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    state_code  VARCHAR(2) NOT NULL REFERENCES states(state_code)
);
CREATE INDEX idx_counties_state ON counties(state_code);

CREATE TABLE courts (
    id          SERIAL PRIMARY KEY,
    court_code  VARCHAR(20) UNIQUE NOT NULL,
    court_name  TEXT NOT NULL,
    address     TEXT,
    fk_county   INT REFERENCES counties(id),
    court_type  VARCHAR(50)
);
CREATE INDEX idx_courts_county ON courts(fk_county);

CREATE TABLE tools (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    tool_type       VARCHAR(50),
    api_endpoint    TEXT,
    credentials     JSONB,
    active          BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(100) UNIQUE NOT NULL,
    email       VARCHAR(255),
    first_name  VARCHAR(100),
    last_name   VARCHAR(100),
    role        VARCHAR(20) DEFAULT 'user',
    cognito_sub VARCHAR(255) UNIQUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Core case tables

CREATE TABLE celebrities (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    tmz_celeb_id    INT,
    image_url       TEXT,
    verified        BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_celebrities_name ON celebrities(name);
CREATE INDEX idx_celebrities_tmz_id ON celebrities(tmz_celeb_id);

CREATE TABLE celebrity_names (
    id              SERIAL PRIMARY KEY,
    fk_celebrity    INT NOT NULL REFERENCES celebrities(id) ON DELETE CASCADE,
    name_variation  VARCHAR(200) NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_celebrity_names_fk ON celebrity_names(fk_celebrity);

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
CREATE INDEX idx_cases_status ON cases(status);
CREATE INDEX idx_cases_court_code ON cases(court_code);
CREATE INDEX idx_cases_tool_id ON cases(tool_id);
CREATE INDEX idx_cases_owner ON cases(owner);
CREATE INDEX idx_cases_case_number ON cases(case_number);
CREATE INDEX idx_cases_fts ON cases USING GIN(
    to_tsvector('english', COALESCE(case_name, '') || ' ' || COALESCE(case_number, ''))
);

CREATE TABLE case_priority (
    id          SERIAL PRIMARY KEY,
    fk_case     INT UNIQUE NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    priority    INT DEFAULT 0,
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE case_events (
    id                  SERIAL PRIMARY KEY,
    fk_case             INT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
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
CREATE INDEX idx_case_events_fk_case ON case_events(fk_case);
CREATE INDEX idx_case_events_acknowledged ON case_events(acknowledged);
CREATE INDEX idx_case_events_created ON case_events(created_at DESC);
CREATE INDEX idx_case_events_date ON case_events(event_date DESC);

CREATE TABLE documents (
    id                          SERIAL PRIMARY KEY,
    doc_uid                     UUID DEFAULT gen_random_uuid() UNIQUE,
    fk_case_event               INT REFERENCES case_events(id) ON DELETE SET NULL,
    pdf_title                   TEXT,
    rel_path                    TEXT,
    s3_key                      TEXT,
    file_size                   INT,
    sha256_hash                 VARCHAR(64),
    ocr_text                    TEXT,
    summary_ai                  TEXT,
    summary_ai_html             TEXT,
    summary_ai_extraction_json  JSONB,
    model_name                  VARCHAR(50),
    processing_ms               INT,
    tokens_input                INT,
    tokens_output               INT,
    created_at                  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_documents_fk_event ON documents(fk_case_event);
CREATE INDEX idx_documents_doc_uid ON documents(doc_uid);
CREATE INDEX idx_documents_sha256 ON documents(sha256_hash);
CREATE INDEX idx_documents_extraction ON documents USING GIN(summary_ai_extraction_json);
CREATE INDEX idx_documents_fts ON documents USING GIN(
    to_tsvector('english', COALESCE(ocr_text, ''))
);

CREATE TABLE attachments (
    id              SERIAL PRIMARY KEY,
    fk_case_event   INT NOT NULL REFERENCES case_events(id) ON DELETE CASCADE,
    file_name       TEXT,
    s3_key          TEXT,
    file_size       INT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_attachments_event ON attachments(fk_case_event);

-- Relationship tables

CREATE TABLE case_celebrity_matches (
    id              SERIAL PRIMARY KEY,
    fk_case         INT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    fk_celebrity    INT NOT NULL REFERENCES celebrities(id) ON DELETE CASCADE,
    match_status    VARCHAR(20) DEFAULT 'Pending',
    match_score     NUMERIC(5,2),
    matched_by      VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(fk_case, fk_celebrity)
);
CREATE INDEX idx_ccm_case ON case_celebrity_matches(fk_case);
CREATE INDEX idx_ccm_celebrity ON case_celebrity_matches(fk_celebrity);
CREATE INDEX idx_ccm_status ON case_celebrity_matches(match_status);

CREATE TABLE case_email_recipients (
    id          SERIAL PRIMARY KEY,
    fk_case     INT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    username    VARCHAR(100) NOT NULL,
    notify      BOOLEAN DEFAULT TRUE,
    UNIQUE(fk_case, username)
);
CREATE INDEX idx_cer_case ON case_email_recipients(fk_case);

CREATE TABLE case_links (
    id              SERIAL PRIMARY KEY,
    fk_case_from    INT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    fk_case_to      INT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(fk_case_from, fk_case_to)
);

CREATE TABLE hearings (
    id              SERIAL PRIMARY KEY,
    fk_case         INT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    hearing_date    TIMESTAMPTZ,
    hearing_type    VARCHAR(100),
    location        TEXT,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_hearings_case ON hearings(fk_case);
CREATE INDEX idx_hearings_date ON hearings(hearing_date);

-- AI / Monitoring tables

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
CREATE INDEX idx_gemini_log_created ON gemini_api_log(created_at DESC);
CREATE INDEX idx_gemini_log_model ON gemini_api_log(model_name);

CREATE TABLE summary_qc_feedback (
    id              SERIAL PRIMARY KEY,
    fk_document     INT REFERENCES documents(id) ON DELETE SET NULL,
    rating          VARCHAR(20),
    notes           TEXT,
    upload_sha256   VARCHAR(64),
    model_name      VARCHAR(50),
    username        VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_qc_document ON summary_qc_feedback(fk_document);

CREATE TABLE document_prompts (
    id              SERIAL PRIMARY KEY,
    fk_document     INT REFERENCES documents(id) ON DELETE CASCADE,
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
CREATE INDEX idx_prompts_document ON document_prompts(fk_document);
CREATE INDEX idx_prompts_session ON document_prompts(session_id);

CREATE TABLE articles (
    id              SERIAL PRIMARY KEY,
    fk_case         INT REFERENCES cases(id) ON DELETE SET NULL,
    headline        TEXT,
    subhead         TEXT,
    body_html       TEXT,
    image_url       TEXT,
    model_name      VARCHAR(50),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_articles_case ON articles(fk_case);
CREATE INDEX idx_articles_created ON articles(created_at DESC);

-- Admin / Logging tables

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
CREATE INDEX idx_task_log_name ON scheduled_task_log(task_name);
CREATE INDEX idx_task_log_started ON scheduled_task_log(started_at DESC);

CREATE TABLE user_activity (
    id              SERIAL PRIMARY KEY,
    username        VARCHAR(100),
    action          VARCHAR(100),
    details         TEXT,
    ip_address      VARCHAR(45),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_activity_user ON user_activity(username);
CREATE INDEX idx_activity_created ON user_activity(created_at DESC);

CREATE TABLE user_preferences (
    id                  SERIAL PRIMARY KEY,
    fk_user             INT REFERENCES users(id) ON DELETE CASCADE,
    preference_key      VARCHAR(100),
    preference_value    JSONB,
    UNIQUE(fk_user, preference_key)
);
CREATE INDEX idx_prefs_user ON user_preferences(fk_user);

CREATE TABLE error_logs (
    id              SERIAL PRIMARY KEY,
    script_name     VARCHAR(200),
    error_type      VARCHAR(100),
    message         TEXT,
    detail          TEXT,
    severity        VARCHAR(20) DEFAULT 'error',
    resolved        BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_error_logs_created ON error_logs(created_at DESC);
CREATE INDEX idx_error_logs_resolved ON error_logs(resolved);

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cases_updated_at
    BEFORE UPDATE ON cases
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

COMMIT;
