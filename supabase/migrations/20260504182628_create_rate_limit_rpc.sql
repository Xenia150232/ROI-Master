/*
  # Rate Limit RPC Functions

  Two server-side functions callable via Supabase REST API with the anon key:

  1. `increment_ip_rate_limit(p_ip_hash text, p_daily_limit int)`
     - Atomically upserts the counter for today's date
     - Returns { allowed: bool, call_count: int, remaining: int }
     - Uses SECURITY DEFINER so it can write to ip_rate_limits despite RLS

  2. `get_ip_rate_limit(p_ip_hash text, p_daily_limit int)`
     - Read-only check, returns remaining calls without incrementing
     - Used by the ping/probe endpoint
*/

CREATE OR REPLACE FUNCTION increment_ip_rate_limit(
  p_ip_hash   text,
  p_daily_limit integer DEFAULT 30
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count  integer;
  v_today  date := CURRENT_DATE;
BEGIN
  -- Atomic upsert: insert row or increment existing count for today
  INSERT INTO ip_rate_limits (ip_hash, call_date, call_count, updated_at)
    VALUES (p_ip_hash, v_today, 1, now())
  ON CONFLICT (ip_hash, call_date)
    DO UPDATE SET
      call_count = ip_rate_limits.call_count + 1,
      updated_at = now()
  RETURNING call_count INTO v_count;

  RETURN json_build_object(
    'allowed',     v_count <= p_daily_limit,
    'call_count',  v_count,
    'remaining',   GREATEST(0, p_daily_limit - v_count)
  );
END;
$$;

CREATE OR REPLACE FUNCTION get_ip_rate_limit(
  p_ip_hash     text,
  p_daily_limit integer DEFAULT 30
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  SELECT call_count INTO v_count
    FROM ip_rate_limits
   WHERE ip_hash = p_ip_hash
     AND call_date = CURRENT_DATE;

  RETURN json_build_object(
    'call_count', COALESCE(v_count, 0),
    'remaining',  GREATEST(0, p_daily_limit - COALESCE(v_count, 0))
  );
END;
$$;

-- Grant execute to anon and authenticated roles so the Netlify function
-- can call these via the REST API with the anon key
GRANT EXECUTE ON FUNCTION increment_ip_rate_limit(text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_ip_rate_limit(text, integer) TO anon, authenticated;
