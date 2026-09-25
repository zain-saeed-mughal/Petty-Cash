BEGIN;
-- A transactional counter avoids sequence/commit-order gaps in the change feed.
CREATE TABLE IF NOT EXISTS public.request_sync_clock (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 revision bigint NOT NULL DEFAULT 0
);
INSERT INTO public.request_sync_clock(singleton) VALUES(true) ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS public.request_changes (
 request_id text PRIMARY KEY,
 owner_id uuid NOT NULL,
 revision bigint NOT NULL,
 deleted boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS request_changes_revision_idx ON public.request_changes(revision);
CREATE INDEX IF NOT EXISTS request_changes_owner_revision_idx ON public.request_changes(owner_id,revision);
ALTER TABLE public.request_sync_clock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.request_sync_clock,public.request_changes FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.request_sync_clock,public.request_changes TO service_role;

CREATE OR REPLACE FUNCTION public.track_request_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE next_revision bigint; row_id text; row_owner uuid;
BEGIN
 UPDATE public.request_sync_clock SET revision=revision+1 WHERE singleton RETURNING revision INTO next_revision;
 IF TG_OP='DELETE' THEN row_id:=OLD.id; row_owner:=OLD."requestedBy";
 ELSE row_id:=NEW.id; row_owner:=NEW."requestedBy"; END IF;
 INSERT INTO public.request_changes(request_id,owner_id,revision,deleted)
 VALUES(row_id,row_owner,next_revision,TG_OP='DELETE')
 ON CONFLICT(request_id) DO UPDATE SET owner_id=EXCLUDED.owner_id,revision=EXCLUDED.revision,deleted=EXCLUDED.deleted;
 RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS petty_cash_request_changes ON public.requests;
CREATE TRIGGER petty_cash_request_changes AFTER INSERT OR UPDATE OR DELETE ON public.requests
 FOR EACH ROW EXECUTE FUNCTION public.track_request_change();

-- Backfill existing requests once; rerunning the migration keeps cursors valid.
DO $$ DECLARE r record; next_revision bigint; BEGIN
 FOR r IN SELECT id,"requestedBy" FROM public.requests
 WHERE NOT EXISTS(SELECT 1 FROM public.request_changes c WHERE c.request_id=requests.id)
 ORDER BY id LOOP
  UPDATE public.request_sync_clock SET revision=revision+1 WHERE singleton RETURNING revision INTO next_revision;
  INSERT INTO public.request_changes(request_id,owner_id,revision) VALUES(r.id,r."requestedBy",next_revision);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.sync_requests(after_revision bigint DEFAULT 0,page_size integer DEFAULT 500)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor_role text; ceiling bigint; batch jsonb; last_revision bigint; batch_count integer;
BEGIN
 actor_role:=public.current_user_role();
 IF actor_role IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 IF after_revision IS NULL OR after_revision<0 OR page_size IS NULL OR page_size NOT BETWEEN 1 AND 500 THEN
  RAISE EXCEPTION 'Invalid sync cursor or page size';
 END IF;
 SELECT revision INTO ceiling FROM public.request_sync_clock WHERE singleton;
 IF after_revision>ceiling THEN RAISE EXCEPTION 'Invalid sync cursor or page size'; END IF;
 WITH page AS (
  SELECT c.* FROM public.request_changes c
  WHERE c.revision>after_revision AND c.revision<=ceiling
   AND (actor_role IN ('admin','super_admin','finance') OR c.owner_id=auth.uid())
  ORDER BY c.revision LIMIT page_size
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.request_id,
  'deleted',p.deleted OR r.id IS NULL,'request',CASE WHEN NOT p.deleted AND r.id IS NOT NULL THEN to_jsonb(r) ELSE NULL END)
  ORDER BY p.revision),'[]'::jsonb),max(p.revision),count(*)
 INTO batch,last_revision,batch_count FROM page p LEFT JOIN public.requests r ON r.id=p.request_id;
 RETURN jsonb_build_object('changes',batch,'cursor',CASE WHEN batch_count<page_size THEN ceiling ELSE last_revision END,
  'has_more',batch_count=page_size);
END $$;
REVOKE ALL ON FUNCTION public.track_request_change(),public.sync_requests(bigint,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sync_requests(bigint,integer) TO authenticated;
COMMIT;
