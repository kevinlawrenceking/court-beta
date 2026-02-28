-- Rollback initial schema
BEGIN;

DROP TRIGGER IF EXISTS trg_cases_updated_at ON cases;
DROP FUNCTION IF EXISTS update_updated_at();

DROP TABLE IF EXISTS error_logs;
DROP TABLE IF EXISTS user_preferences;
DROP TABLE IF EXISTS user_activity;
DROP TABLE IF EXISTS scheduled_task_log;
DROP TABLE IF EXISTS articles;
DROP TABLE IF EXISTS document_prompts;
DROP TABLE IF EXISTS summary_qc_feedback;
DROP TABLE IF EXISTS gemini_api_log;
DROP TABLE IF EXISTS hearings;
DROP TABLE IF EXISTS case_links;
DROP TABLE IF EXISTS case_email_recipients;
DROP TABLE IF EXISTS case_celebrity_matches;
DROP TABLE IF EXISTS attachments;
DROP TABLE IF EXISTS documents;
DROP TABLE IF EXISTS case_events;
DROP TABLE IF EXISTS case_priority;
DROP TABLE IF EXISTS cases;
DROP TABLE IF EXISTS celebrity_names;
DROP TABLE IF EXISTS celebrities;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS tools;
DROP TABLE IF EXISTS courts;
DROP TABLE IF EXISTS counties;
DROP TABLE IF EXISTS states;

COMMIT;
