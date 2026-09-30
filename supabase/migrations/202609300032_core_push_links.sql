BEGIN;

DROP FUNCTION IF EXISTS public.claim_push_batch();
CREATE FUNCTION public.claim_push_batch()
RETURNS TABLE(id uuid,user_id uuid,request_id text,
  core_advance_id uuid,reimbursement_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
  WITH claimed AS (
    SELECT o.id FROM public.push_outbox o
    WHERE o.sent_at IS NULL AND o.attempts < 8 AND o.available_at <= now()
    ORDER BY o.available_at LIMIT 50 FOR UPDATE SKIP LOCKED
  ), leased AS (
    UPDATE public.push_outbox o
    SET attempts=o.attempts+1,available_at=now()+interval '5 minutes'
    FROM claimed WHERE o.id=claimed.id RETURNING o.id
  )
  SELECT n.id,n.user_id,n.related_request_id,
    n.related_core_advance_id,n.related_reimbursement_id
  FROM leased JOIN public.notifications n USING(id)
$$;
REVOKE ALL ON FUNCTION public.claim_push_batch() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_push_batch() TO service_role;

NOTIFY pgrst,'reload schema';
COMMIT;
