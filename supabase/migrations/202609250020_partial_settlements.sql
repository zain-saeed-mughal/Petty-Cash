-- Update the settle function to allow updating an already pending settlement
CREATE OR REPLACE FUNCTION public.settle_advance_request(
    p_request_id text,
    p_expected_version integer,
    p_settlement_amount numeric,
    p_settlement_method text,
    p_settlement_note text
)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF result."requestedBy" <> actor.uid AND actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'Not authorized'; END IF;
 -- ALLOW Paid AND Pending Settlement to be updated
 IF result.status NOT IN ('Paid', 'Pending Settlement') OR result.request_type <> 'advance' THEN RAISE EXCEPTION 'Only paid or pending advances can be settled'; END IF;
 IF p_expected_version IS NULL OR result.version<>p_expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF p_settlement_amount < 0 OR p_settlement_amount > result.amount THEN RAISE EXCEPTION 'Invalid settlement amount'; END IF;
 
 UPDATE public.requests SET 
    status = 'Pending Settlement',
    settlement_amount = p_settlement_amount,
    settlement_method = p_settlement_method,
    settlement_note = trim(p_settlement_note),
    settlement_date = now(),
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Updated Settlement','performerId',actor.uid,'performerName',actor.name,'notes','Spent: ' || p_settlement_amount || ', Returned via ' || coalesce(p_settlement_method, 'None') || '. Note: ' || coalesce(p_settlement_note, '')))
 WHERE id=p_request_id RETURNING * INTO result;
 RETURN result;
END $$;
