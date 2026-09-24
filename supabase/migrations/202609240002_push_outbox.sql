BEGIN;
CREATE TABLE IF NOT EXISTS public.push_outbox(
 id uuid PRIMARY KEY REFERENCES public.notifications(id) ON DELETE CASCADE,
 attempts integer NOT NULL DEFAULT 0,
 available_at timestamptz NOT NULL DEFAULT now(),
 sent_at timestamptz,last_error text
);
ALTER TABLE public.push_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.push_outbox FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.push_outbox TO service_role;
CREATE INDEX IF NOT EXISTS push_outbox_pending_idx ON public.push_outbox(available_at) WHERE sent_at IS NULL;
CREATE OR REPLACE FUNCTION public.queue_push() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN INSERT INTO public.push_outbox(id) VALUES(NEW.id) ON CONFLICT DO NOTHING; RETURN NEW; END $$;
DROP TRIGGER IF EXISTS petty_cash_queue_push ON public.notifications;
CREATE TRIGGER petty_cash_queue_push AFTER INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.queue_push();
CREATE OR REPLACE FUNCTION public.claim_push_batch() RETURNS TABLE(id uuid,user_id uuid,request_id text)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 WITH claimed AS (
  SELECT o.id FROM public.push_outbox o WHERE o.sent_at IS NULL AND o.attempts<8 AND o.available_at<=now()
  ORDER BY o.available_at LIMIT 50 FOR UPDATE SKIP LOCKED
 ), leased AS (
  UPDATE public.push_outbox o SET attempts=o.attempts+1,available_at=now()+interval '5 minutes'
  FROM claimed WHERE o.id=claimed.id RETURNING o.id
 )
 SELECT n.id,n.user_id,n.related_request_id FROM leased JOIN public.notifications n USING(id)
$$;
REVOKE ALL ON FUNCTION public.queue_push(),public.claim_push_batch() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_push_batch() TO service_role;
COMMIT;

