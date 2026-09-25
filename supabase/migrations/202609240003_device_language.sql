BEGIN;
ALTER TABLE public.device_tokens ADD COLUMN IF NOT EXISTS language_code text NOT NULL DEFAULT 'en'
  CHECK (language_code IN ('en','ur'));
-- The two-argument endpoint stays available for older clients.
CREATE OR REPLACE FUNCTION public.register_device_language(device_token text, device_platform text, device_language text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF device_language IS NULL OR device_language NOT IN ('en','ur') THEN RAISE EXCEPTION 'Invalid language'; END IF;
 IF device_platform IS NULL OR device_platform NOT IN ('web','android','iOS') THEN RAISE EXCEPTION 'Invalid platform'; END IF;
 PERFORM public.register_device(device_token,device_platform);
 UPDATE public.device_tokens SET language_code=device_language WHERE token=device_token AND user_id=auth.uid();
END $$;
REVOKE ALL ON FUNCTION public.register_device_language(text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.register_device_language(text,text,text) TO authenticated;
COMMIT;
