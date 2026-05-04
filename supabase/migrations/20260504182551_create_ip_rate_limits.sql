/*
  # IP Rate Limiting Table

  Stores per-IP daily AI call counts for the chat widget rate limiter.

  ## New Tables
  - `ip_rate_limits`
    - `ip_hash` (text, primary key) — SHA-256 hash of the client IP (never store raw IPs)
    - `call_date` (date) — UTC date of the tracked day
    - `call_count` (integer) — number of AI calls made on that date
    - `updated_at` (timestamptz) — last update timestamp

  ## Security
  - RLS enabled; no public access policies — only the service role key (used by the
    Netlify serverless function) can read and write this table.
    Public/anon users have zero access.

  ## Notes
  - Rows are upserted (insert or increment) on each AI call.
  - Old rows (previous days) are left in place; the app ignores them by filtering on call_date.
  - A periodic cleanup can be run manually or via a cron job; the table will stay small
    regardless since each IP has at most one row per day.
*/

CREATE TABLE IF NOT EXISTS ip_rate_limits (
  ip_hash   text        NOT NULL,
  call_date date        NOT NULL DEFAULT CURRENT_DATE,
  call_count integer    NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ip_hash, call_date)
);

ALTER TABLE ip_rate_limits ENABLE ROW LEVEL SECURITY;

-- No public policies — only service_role key bypasses RLS (used by the Netlify function)
