-- =============================================================================
-- Migration: 202610090000_advance_approval_flow_sync.sql
-- Description:
--   1. Ensures direct advance allotments from Finance start in 'awaiting_office_boy_approval'
--      status with cleared_at = NULL and NO ledger credit until the Office Boy approves.
--   2. When Office Boy approves, status transitions to 'cleared', cleared_at = now(),
--      and the advance ledger is credited so it appears in available balance.
--   3. When Office Boy requests an advance, status starts as 'pending'. Only when
--      Finance clears it does status transition to 'cleared' and credits the balance.
-- =============================================================================

-- 1. direct_allot_advance_v2
CREATE OR REPLACE FUNCTION public.direct_allot_advance_v2(
  p_id uuid, p_office_boy_id uuid, p_amount numeric, p_purpose text, p_method text
) RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  actor public.users;
  boy public.users;
  result public.advance_requests;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid = auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'finance' THEN
    RAISE EXCEPTION 'Only Finance can allot advances' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO boy FROM public.users WHERE uid = p_office_boy_id AND "isActive" AND role = 'office_boy';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active office boy not found';
  END IF;

  IF p_id IS NULL OR NOT public.payment_amount_valid(p_amount)
    OR length(trim(coalesce(p_purpose, ''))) NOT BETWEEN 1 AND 2000
    OR p_method NOT IN ('cash', 'card')
  THEN
    RAISE EXCEPTION 'Check the amount, purpose and payment details';
  END IF;

  SELECT * INTO result FROM public.advance_requests WHERE id = p_id;
  IF FOUND THEN
    RETURN result;
  END IF;

  -- Advance is inserted in 'awaiting_office_boy_approval' status with cleared_at = NULL.
  -- Notice: NO entry is made in advance_ledger yet.
  INSERT INTO public.advance_requests(
    id, office_boy_id, office_id, amount, amount_requested, purpose,
    status, payment_method_requested, flow_version, cleared_by, cleared_method, cleared_at
  )
  VALUES (
    p_id, boy.uid, boy.office_id, p_amount, p_amount, trim(p_purpose),
    'awaiting_office_boy_approval', p_method, 2, actor.uid, p_method, NULL
  )
  RETURNING * INTO result;

  INSERT INTO public.core_payment_activity(advance_request_id, office_boy_id, office_id, actor_id, action, detail)
  VALUES (result.id, result.office_boy_id, result.office_id, actor.uid, 'direct_allot_pending', jsonb_build_object('method', p_method));

  INSERT INTO public.notifications(user_id, title, message, related_core_advance_id)
  VALUES (boy.uid, 'Advance needs approval', 'Finance sent you an advance of PKR ' || p_amount || '. Tap to approve.', result.id);

  RETURN result;
END $$;

-- 2. respond_to_direct_advance_v2
CREATE OR REPLACE FUNCTION public.respond_to_direct_advance_v2(
  p_id uuid, p_decision text
) RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  actor public.users;
  result public.advance_requests;
  finance public.users;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid = auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'office_boy' THEN
    RAISE EXCEPTION 'Only an Office Boy can approve advances' USING ERRCODE = '42501';
  END IF;

  IF p_decision NOT IN ('approve', 'decline') THEN
    RAISE EXCEPTION 'Decision must be approve or decline';
  END IF;

  SELECT * INTO result FROM public.advance_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Advance not found';
  END IF;
  IF result.office_boy_id <> actor.uid THEN
    RAISE EXCEPTION 'Not your advance';
  END IF;
  IF result.status <> 'awaiting_office_boy_approval' THEN
    RAISE EXCEPTION 'Advance is not awaiting approval';
  END IF;

  SELECT * INTO finance FROM public.users WHERE uid = result.cleared_by;

  IF p_decision = 'approve' THEN
    -- Status becomes 'cleared' and cleared_at becomes now()
    UPDATE public.advance_requests
    SET status = 'cleared', cleared_at = now()
    WHERE id = p_id
    RETURNING * INTO result;

    -- Funds are officially credited to the office boy's balance here
    INSERT INTO public.advance_ledger(advance_request_id, office_boy_id, office_id, entry_type, amount, actor_id)
    VALUES (result.id, result.office_boy_id, result.office_id, 'credit', result.amount_requested, actor.uid);

    INSERT INTO public.core_payment_activity(advance_request_id, office_boy_id, office_id, actor_id, action)
    VALUES (result.id, result.office_boy_id, result.office_id, actor.uid, 'approved_by_boy');

    IF finance.uid IS NOT NULL THEN
      INSERT INTO public.notifications(user_id, title, message, related_core_advance_id)
      VALUES (finance.uid, 'Advance approved', actor.name || ' approved the PKR ' || result.amount_requested || ' advance.', result.id);
    END IF;
  ELSE
    UPDATE public.advance_requests
    SET status = 'declined'
    WHERE id = p_id
    RETURNING * INTO result;

    INSERT INTO public.core_payment_activity(advance_request_id, office_boy_id, office_id, actor_id, action)
    VALUES (result.id, result.office_boy_id, result.office_id, actor.uid, 'declined_by_boy');

    IF finance.uid IS NOT NULL THEN
      INSERT INTO public.notifications(user_id, title, message, related_core_advance_id)
      VALUES (finance.uid, 'Advance declined', actor.name || ' declined the PKR ' || result.amount_requested || ' advance.', result.id);
    END IF;
  END IF;

  RETURN result;
END $$;

-- 3. Grants
GRANT EXECUTE ON FUNCTION public.direct_allot_advance_v2(uuid, uuid, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_direct_advance_v2(uuid, text) TO authenticated;

-- 4. advance_balances_v2 (Only count approved items towards spent)
CREATE OR REPLACE FUNCTION public.advance_balances_v2()
RETURNS TABLE(advance_request_id uuid, office_boy_id uuid, office_id uuid, total numeric, spent numeric, remaining numeric, item_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  role_name text;
BEGIN
  role_name := public.current_user_role();
  IF role_name IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501'; END IF;

  RETURN QUERY SELECT
    a.id,
    a.office_boy_id,
    a.office_id,
    a.amount_requested,
    coalesce(sum(CASE WHEN i.status = 'approved' THEN i.amount_spent ELSE 0 END), 0),
    greatest(0, a.amount_requested - coalesce(sum(CASE WHEN i.status = 'approved' THEN i.amount_spent ELSE 0 END), 0)),
    count(CASE WHEN i.status = 'approved' THEN i.id END)
  FROM public.advance_requests a
  LEFT JOIN public.advance_items i ON i.advance_request_id = a.id
  WHERE a.flow_version = 2 AND a.status IN ('cleared', 'fully_utilized')
    AND (role_name IN ('finance', 'admin', 'super_admin')
      OR (a.office_boy_id = auth.uid() AND a.office_id = public.current_office_id()))
  GROUP BY a.id, a.office_boy_id, a.office_id, a.amount_requested, a.created_at
  ORDER BY a.created_at DESC;
END $$;

GRANT EXECUTE ON FUNCTION public.advance_balances_v2() TO authenticated;
