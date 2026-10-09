-- Read-only checks. Run in the Petty Cash project's SQL Editor.
SELECT
  (SELECT count(*) FROM public.users WHERE "isActive" AND role = 'admin') AS active_admins,
  (SELECT count(*) FROM public.users WHERE "isActive" AND role = 'super_admin') AS active_super_admins,
  (SELECT count(*) FROM public.device_tokens WHERE platform = 'android') AS android_tokens,
  (SELECT count(*) FROM public.device_tokens WHERE platform = 'iOS') AS ios_tokens,
  (SELECT count(*) FROM public.device_tokens WHERE platform = 'web') AS web_tokens,
  (SELECT count(*) FROM public.push_outbox WHERE sent_at IS NULL) AS queued_pushes,
  (SELECT count(*) FROM public.push_outbox WHERE sent_at IS NULL AND attempts >= 8) AS exhausted_pushes,
  (SELECT count(*) FROM public.notifications AS n JOIN public.users AS u ON u.uid = n.user_id
    WHERE u.role = 'admin' AND n.source_activity_id IS NOT NULL
      AND n.created_at > now() - interval '24 hours') AS recent_admin_alerts,
  (SELECT count(*) FROM public.notifications AS n JOIN public.users AS u ON u.uid = n.user_id
    WHERE u.role = 'super_admin' AND n.source_activity_id IS NOT NULL
      AND n.created_at > now() - interval '24 hours') AS recent_super_admin_alerts,
  EXISTS(SELECT 1 FROM cron.job WHERE jobname = 'petty-cash-send-push') AS worker_scheduled;

SELECT last_error, count(*) AS queued
FROM public.push_outbox
WHERE sent_at IS NULL AND last_error IS NOT NULL
GROUP BY last_error ORDER BY queued DESC LIMIT 10;
