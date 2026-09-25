CREATE OR REPLACE FUNCTION public.request_notifications() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO public.notifications(user_id,title,message,related_request_id)
  SELECT uid,'New expense request',NEW."requesterName"||' submitted a request for PKR '||NEW.amount,NEW.id
  FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
 ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
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
