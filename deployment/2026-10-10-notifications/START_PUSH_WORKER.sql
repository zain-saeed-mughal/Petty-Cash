-- Run after the Edge Function has FIREBASE_SERVICE_ACCOUNT and
-- PUSH_WORKER_SECRET, and Vault has petty_cash_push_worker_secret with the
-- same random value. No credential is stored in this file or in cron.job.
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM vault.decrypted_secrets
    WHERE name = 'petty_cash_push_worker_secret'
      AND length(decrypted_secret) >= 32
  ) THEN
    RAISE EXCEPTION 'Add petty_cash_push_worker_secret to Supabase Vault first';
  END IF;
END $$;

SELECT cron.schedule(
  'petty-cash-send-push',
  '* * * * *',
  $job$
    SELECT net.http_post(
      url := 'https://ysrwvlminsuvwswgpuhh.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-worker-secret', (
          SELECT decrypted_secret FROM vault.decrypted_secrets
          WHERE name = 'petty_cash_push_worker_secret'
        )
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 15000
    );
  $job$
);
