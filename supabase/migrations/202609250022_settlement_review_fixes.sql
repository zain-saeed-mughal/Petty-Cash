BEGIN;
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
 IF result.status NOT IN ('Paid','Pending Settlement') OR result.request_type <> 'advance' THEN RAISE EXCEPTION 'Only paid or pending advances can be settled'; END IF;
 IF p_expected_version IS NULL OR result.version<>p_expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF p_settlement_amount IS NULL OR p_settlement_amount::text IN ('NaN','Infinity','-Infinity') OR p_settlement_amount<>round(p_settlement_amount,2) OR p_settlement_amount < 0 OR p_settlement_amount > result.amount THEN RAISE EXCEPTION 'Invalid settlement amount'; END IF;
 
 IF p_settlement_amount < result.amount AND (p_settlement_method IS NULL OR p_settlement_method NOT IN ('Cash','Card')) THEN RAISE EXCEPTION 'Choose a valid return method'; END IF;
 IF length(p_settlement_note)>2000 THEN RAISE EXCEPTION 'Settlement note is too long'; END IF;
 UPDATE public.requests SET 
    status = 'Pending Settlement',
    settlement_amount = p_settlement_amount,
    settlement_method = p_settlement_method,
    settlement_note = trim(p_settlement_note),
    settlement_date = now(),
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(jsonb_build_object('timestamp',now(),'action',CASE WHEN result.status='Pending Settlement' THEN 'Updated Settlement' ELSE 'Submitted Settlement' END,'performerId',actor.uid,'performerName',actor.name,'notes','Spent: ' || p_settlement_amount || ', Returned via ' || coalesce(p_settlement_method, 'None') || '. Note: ' || coalesce(p_settlement_note, '')))
 WHERE id=p_request_id RETURNING * INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.verify_advance_settlement(
    p_request_id text,
    p_expected_version integer
)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 IF actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'Not authorized'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF result.status <> 'Pending Settlement' OR result.request_type <> 'advance' THEN RAISE EXCEPTION 'Request is not pending settlement'; END IF;
 IF p_expected_version IS NULL OR result.version<>p_expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 
 IF result.settlement_amount IS NULL OR result.settlement_amount::text IN ('NaN','Infinity','-Infinity') OR result.settlement_amount < 0 OR result.settlement_amount > result.amount THEN RAISE EXCEPTION 'Invalid settlement amount'; END IF;
 IF result.settlement_amount < result.amount AND (result.settlement_method IS NULL OR result.settlement_method NOT IN ('Cash','Card')) THEN RAISE EXCEPTION 'Choose a valid return method'; END IF;
 UPDATE public.requests SET 
    status = 'Settled',
    is_settled = true,
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Settlement Verified','performerId',actor.uid,'performerName',actor.name))
 WHERE id=p_request_id RETURNING * INTO result;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.review_request(request_id text,expected_version integer,new_status text,review_note text DEFAULT NULL,is_override boolean DEFAULT false)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS NULL OR actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'You cannot review requests' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF expected_version IS NULL OR result.version<>expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF new_status IS NULL OR new_status NOT IN ('Pending','Approved','Rejected','Paid') OR new_status=result.status THEN RAISE EXCEPTION 'Invalid status transition'; END IF;
 IF is_override THEN
  IF actor.role<>'super_admin' OR coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A super-admin and an override reason are required' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT ((result.status='Pending' AND new_status IN ('Approved','Rejected','Paid')) OR (result.status='Approved' AND new_status IN ('Paid','Rejected'))) THEN RAISE EXCEPTION 'This request can no longer be reviewed'; END IF;
 END IF;
 IF new_status='Rejected' AND coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A rejection reason is required'; END IF;
 UPDATE public.requests SET status=new_status,"rejectionReason"=CASE WHEN new_status='Rejected' THEN trim(review_note) END,
 "reviewedBy"=actor.uid,"reviewedByName"=actor.name,"updatedAt"=now(),version=version+1,
 settlement_amount=NULL,settlement_method=NULL,settlement_note=NULL,settlement_date=NULL,is_settled=false,
 "paidAt"=CASE WHEN new_status='Paid' THEN now() ELSE NULL END,
 "auditLogs"="auditLogs"||jsonb_build_array(jsonb_build_object('timestamp',now(),'action',CASE WHEN is_override THEN 'Status overridden to ' ELSE 'Status changed to ' END||new_status,'performerId',actor.uid,'performerName',actor.name,'notes',nullif(trim(review_note),'')))
 WHERE id=request_id RETURNING * INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.request_notifications() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO public.notifications(user_id,title,message,related_request_id)
  SELECT uid,'New expense request',NEW."requesterName"||' submitted a request for PKR '||NEW.amount,NEW.id
  FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
 ELSIF NEW.status IS DISTINCT FROM OLD.status OR
   (NEW.status='Pending Settlement' AND
    ROW(NEW.settlement_amount,NEW.settlement_method,NEW.settlement_note,NEW.settlement_date)
      IS DISTINCT FROM ROW(OLD.settlement_amount,OLD.settlement_method,OLD.settlement_note,OLD.settlement_date)) THEN
  IF NEW.status = 'Pending Settlement' THEN
    -- Notify Finance/Admins
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    SELECT uid,'Advance Settlement',NEW."requesterName"||' submitted a settlement update.',NEW.id
    FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
    
    -- Notify Office Boy (Requester)
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    VALUES(NEW."requestedBy",'Settlement Submitted','Your settlement update has been submitted for review.',NEW.id);
    
  ELSIF NEW.status = 'Settled' THEN
    -- Notify Finance/Admins
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    SELECT uid,'Advance Settled',NEW."requesterName"||'''s advance has been fully settled and closed.',NEW.id
    FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
    
    -- Notify Office Boy (Requester)
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    VALUES(NEW."requestedBy",'Advance Settled','Your advance settlement was verified by Finance and is now closed.',NEW.id);
    
  ELSE
    -- Notify Office Boy of other status changes (Paid, Approved, Rejected)
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    VALUES(NEW."requestedBy",'Request '||NEW.status,'Your request for '||NEW."itemDescription"||' is now '||lower(NEW.status)||'.',NEW.id);
  END IF;
 END IF;
 RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS petty_cash_request_notifications ON public.requests;
CREATE TRIGGER petty_cash_request_notifications AFTER INSERT OR UPDATE OF status,settlement_amount,settlement_method,settlement_note,settlement_date ON public.requests FOR EACH ROW EXECUTE FUNCTION public.request_notifications();
REVOKE ALL ON FUNCTION public.settle_advance_request(text,integer,numeric,text,text), public.verify_advance_settlement(text,integer),public.review_request(text,integer,text,text,boolean),public.request_notifications() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.settle_advance_request(text,integer,numeric,text,text),public.verify_advance_settlement(text,integer),public.review_request(text,integer,text,text,boolean) TO authenticated;
COMMIT;
