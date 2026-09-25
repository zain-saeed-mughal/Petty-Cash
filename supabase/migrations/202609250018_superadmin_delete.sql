BEGIN;
-- Super-admin deletion removes the transaction from active lists and reports.
-- Keep the complete record and actor for subsequent financial reconciliation.
CREATE TABLE IF NOT EXISTS public.request_deletion_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id text NOT NULL,
  deleted_by uuid NOT NULL,
  deleted_at timestamptz NOT NULL DEFAULT now(),
  request_snapshot jsonb NOT NULL
);
ALTER TABLE public.request_deletion_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.request_deletion_audit FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.request_deletion_audit TO authenticated;
GRANT ALL ON public.request_deletion_audit TO service_role;
DROP POLICY IF EXISTS superadmin_deletion_audit ON public.request_deletion_audit;
CREATE POLICY superadmin_deletion_audit ON public.request_deletion_audit FOR SELECT TO authenticated
 USING(public.current_user_role()='super_admin');

CREATE OR REPLACE FUNCTION public.delete_request(request_id text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE target public.requests;
BEGIN
 IF public.current_user_role() IS DISTINCT FROM 'super_admin' THEN
  RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
 END IF;
 SELECT * INTO target FROM public.requests WHERE id=request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 INSERT INTO public.request_deletion_audit(request_id,deleted_by,request_snapshot)
 VALUES(target.id,auth.uid(),to_jsonb(target));
 DELETE FROM public.requests WHERE id=target.id;
END $$;
REVOKE ALL ON FUNCTION public.delete_request(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.delete_request(text) TO authenticated;
COMMIT;
