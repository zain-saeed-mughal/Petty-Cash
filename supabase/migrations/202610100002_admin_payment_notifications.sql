-- Admin and Super Admin receive each new core payment event across all offices.
-- The activity id makes this fan-out idempotent without changing payment RPCs.
BEGIN;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS source_activity_id bigint
  REFERENCES public.core_payment_activity(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS notifications_activity_recipient_unique
  ON public.notifications (source_activity_id, user_id)
  WHERE source_activity_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.notify_admins_of_core_payment_activity()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  actor_name text;
  event_title text;
  event_message text;
BEGIN
  SELECT name INTO actor_name FROM public.users WHERE uid = NEW.actor_id;
  actor_name := coalesce(nullif(actor_name, ''), 'A team member');

  event_title := CASE NEW.action
    WHEN 'requested' THEN 'Payment request submitted'
    WHEN 'direct_allot_pending' THEN 'Advance sent for approval'
    WHEN 'approved_by_boy' THEN 'Advance received'
    WHEN 'declined_by_boy' THEN 'Advance declined'
    WHEN 'cleared' THEN 'Advance sent'
    WHEN 'item_added' THEN 'Purchase submitted'
    WHEN 'item_approved' THEN 'Purchase approved'
    WHEN 'item_approve' THEN 'Purchase approved'
    WHEN 'item_rejected' THEN 'Purchase rejected'
    WHEN 'item_reject' THEN 'Purchase rejected'
    WHEN 'approve' THEN 'Repayment approved'
    WHEN 'reject' THEN 'Repayment rejected'
    WHEN 'paid' THEN 'Repayment paid'
    ELSE 'Payment updated'
  END;
  event_message := actor_name || ': ' || event_title || '. Tap to view details.';

  INSERT INTO public.notifications (
    user_id, title, message, related_core_advance_id,
    related_reimbursement_id, source_activity_id
  )
  SELECT u.uid, event_title, event_message,
    NEW.advance_request_id, NEW.reimbursement_id, NEW.id
  FROM public.users AS u
  WHERE u."isActive" AND u.role IN ('admin', 'super_admin')
    AND u.uid <> NEW.actor_id
  ON CONFLICT (source_activity_id, user_id)
    WHERE source_activity_id IS NOT NULL DO NOTHING;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS petty_cash_admin_core_activity ON public.core_payment_activity;
CREATE TRIGGER petty_cash_admin_core_activity
AFTER INSERT ON public.core_payment_activity
FOR EACH ROW EXECUTE FUNCTION public.notify_admins_of_core_payment_activity();

REVOKE ALL ON FUNCTION public.notify_admins_of_core_payment_activity()
  FROM PUBLIC, anon, authenticated;

-- Existing notification-to-outbox trigger may be missing in older installs.
CREATE OR REPLACE FUNCTION public.queue_push() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  INSERT INTO public.push_outbox(id) VALUES (NEW.id) ON CONFLICT DO NOTHING;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS petty_cash_queue_push ON public.notifications;
CREATE TRIGGER petty_cash_queue_push AFTER INSERT ON public.notifications
FOR EACH ROW EXECUTE FUNCTION public.queue_push();
REVOKE ALL ON FUNCTION public.queue_push() FROM PUBLIC, anon, authenticated;

-- Keep the worker's linked-record payload compatible with older databases.
DROP FUNCTION IF EXISTS public.claim_push_batch();
CREATE FUNCTION public.claim_push_batch()
RETURNS TABLE (
  id uuid, user_id uuid, request_id text,
  core_advance_id uuid, reimbursement_id uuid
)
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  WITH claimed AS (
    SELECT o.id FROM public.push_outbox AS o
    WHERE o.sent_at IS NULL AND o.attempts < 8 AND o.available_at <= now()
    ORDER BY o.available_at LIMIT 50 FOR UPDATE SKIP LOCKED
  ), leased AS (
    UPDATE public.push_outbox AS o
    SET attempts = o.attempts + 1,
        available_at = now() + interval '5 minutes'
    FROM claimed WHERE o.id = claimed.id RETURNING o.id
  )
  SELECT n.id, n.user_id, n.related_request_id,
    n.related_core_advance_id, n.related_reimbursement_id
  FROM leased JOIN public.notifications AS n USING (id)
$$;
REVOKE ALL ON FUNCTION public.claim_push_batch()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_push_batch() TO service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
