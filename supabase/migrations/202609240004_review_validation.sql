BEGIN;
CREATE OR REPLACE FUNCTION public.submit_request(request_id text,item_description text,request_amount numeric,request_reason text,receipt_path text DEFAULT NULL)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 IF request_id IS NULL OR request_id !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN RAISE EXCEPTION 'Invalid request reference'; END IF;
 IF request_amount IS NULL OR request_amount::text IN ('NaN','Infinity','-Infinity') OR request_amount<=0 OR request_amount>=10000000000 OR request_amount<>round(request_amount,2) THEN RAISE EXCEPTION 'Enter a positive amount with at most two decimal places'; END IF;
 IF item_description IS NULL OR request_reason IS NULL OR length(trim(item_description)) NOT BETWEEN 1 AND 500 OR length(trim(request_reason)) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'Description and reason are required'; END IF;
 IF receipt_path IS NOT NULL AND (receipt_path NOT LIKE actor.uid::text||'/%' OR receipt_path LIKE '%..%') THEN RAISE EXCEPTION 'Invalid receipt path'; END IF;
 -- A retry after a network timeout must not create a second payment request.
 SELECT * INTO result FROM public.requests WHERE id=request_id;
 IF FOUND THEN
  IF result."requestedBy"<>actor.uid OR result.amount<>request_amount OR result."itemDescription"<>trim(item_description) OR result.reason<>trim(request_reason) OR result."billImageUrl" IS DISTINCT FROM receipt_path THEN RAISE EXCEPTION 'Request reference already used'; END IF;
  RETURN result;
 END IF;
 INSERT INTO public.requests(id,"requestedBy","requesterName","requesterEmail","itemDescription",amount,reason,"billImageUrl","auditLogs")
 VALUES(request_id,actor.uid,actor.name,actor.email,trim(item_description),request_amount,trim(request_reason),receipt_path,
 jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Created request','performerId',actor.uid,'performerName',actor.name)))
 RETURNING * INTO result;
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
 IF length(review_note)>2000 THEN RAISE EXCEPTION 'Review reason is too long'; END IF;
 IF new_status IS NULL OR new_status NOT IN ('Pending','Approved','Rejected','Paid') OR new_status=result.status THEN RAISE EXCEPTION 'Invalid status transition'; END IF;
 IF is_override THEN
  IF actor.role<>'super_admin' OR coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A super-admin and an override reason are required' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT ((result.status='Pending' AND new_status IN ('Approved','Rejected','Paid')) OR (result.status='Approved' AND new_status IN ('Paid','Rejected'))) THEN RAISE EXCEPTION 'This request can no longer be reviewed'; END IF;
 END IF;
 IF new_status='Rejected' AND coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A rejection reason is required'; END IF;
 UPDATE public.requests SET status=new_status,"rejectionReason"=CASE WHEN new_status='Rejected' THEN trim(review_note) END,
 "reviewedBy"=actor.uid,"reviewedByName"=actor.name,"updatedAt"=now(),version=version+1,
 "paidAt"=CASE WHEN new_status='Paid' THEN now() ELSE NULL END,
 "auditLogs"="auditLogs"||jsonb_build_array(jsonb_build_object('timestamp',now(),'action',CASE WHEN is_override THEN 'Status overridden to ' ELSE 'Status changed to ' END||new_status,'performerId',actor.uid,'performerName',actor.name,'notes',nullif(trim(review_note),'')))
 WHERE id=request_id RETURNING * INTO result;
 RETURN result;
END $$;

COMMIT;
