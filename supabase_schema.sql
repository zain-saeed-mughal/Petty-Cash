-- Petty Cash Manager schema
-- Safe defaults: no plaintext credential storage, private storage bucket, and role-aware access controls.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Users table
CREATE TABLE IF NOT EXISTS public.users (
  uid UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL DEFAULT 'office_boy' CHECK (role IN ('super_admin', 'admin', 'finance', 'office_boy')),
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "isActive" BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT users_email_check CHECK (length(trim(email)) > 0)
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role
  FROM public.users
  WHERE uid = auth.uid()
    AND "isActive" = TRUE
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;

DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Authenticated users can read their own profile" ON public.users;
DROP POLICY IF EXISTS "Admins and finance can read active team profiles" ON public.users;
DROP POLICY IF EXISTS "Super-admins can manage all users" ON public.users;
DROP POLICY IF EXISTS "Authenticated users can manage their own profile" ON public.users;
DROP POLICY IF EXISTS "Authenticated users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own visible profile fields" ON public.users;

CREATE POLICY "Users can read own profile"
ON public.users FOR SELECT
TO authenticated
USING (uid = auth.uid());

CREATE POLICY "Admins can read team profiles"
ON public.users FOR SELECT
TO authenticated
USING (public.current_user_role() IN ('super_admin', 'admin', 'finance'));

CREATE POLICY "Super-admins can manage users"
ON public.users FOR ALL
TO authenticated
USING (public.current_user_role() = 'super_admin')
WITH CHECK (public.current_user_role() = 'super_admin');

CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE
TO authenticated
USING (uid = auth.uid())
WITH CHECK (uid = auth.uid() AND name IS NOT NULL AND length(trim(email)) > 0);

CREATE POLICY "Authenticated users can insert own profile"
ON public.users FOR INSERT
TO authenticated
WITH CHECK (uid = auth.uid());

-- 2. Requests table
CREATE TABLE IF NOT EXISTS public.requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "requestedBy" UUID NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  "requesterName" TEXT NOT NULL,
  "requesterEmail" TEXT,
  "itemDescription" TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0 AND amount = amount::numeric),
  reason TEXT NOT NULL,
  "billImageUrl" TEXT,
  status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Paid')),
  "rejectionReason" TEXT,
  "reviewedBy" UUID REFERENCES public.users(uid) ON DELETE SET NULL,
  "reviewedByName" TEXT,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "auditLogs" JSONB NOT NULL DEFAULT '[]'::jsonb
);

ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own requests" ON public.requests;
DROP POLICY IF EXISTS "Admins and finance can read all requests" ON public.requests;
DROP POLICY IF EXISTS "Staff can create requests" ON public.requests;
DROP POLICY IF EXISTS "Request owners can update own pending requests" ON public.requests;
DROP POLICY IF EXISTS "Finance and supers can review requests" ON public.requests;
DROP POLICY IF EXISTS "Only super-admins can hard-delete requests" ON public.requests;

CREATE POLICY "Users can read own requests"
ON public.requests FOR SELECT
TO authenticated
USING ("requestedBy" = auth.uid());

CREATE POLICY "Admins and finance can read all requests"
ON public.requests FOR SELECT
TO authenticated
USING (
  public.current_user_role() IN ('super_admin', 'admin', 'finance')
);

CREATE POLICY "Staff can create requests"
ON public.requests FOR INSERT
TO authenticated
WITH CHECK (
  "requestedBy" = auth.uid()
  AND "requesterName" IS NOT NULL
  AND length(trim("itemDescription")) > 0
  AND amount > 0
);

CREATE POLICY "Request owners can update own pending requests"
ON public.requests FOR UPDATE
TO authenticated
USING ("requestedBy" = auth.uid() AND status = 'Pending')
WITH CHECK (
  "requestedBy" = auth.uid()
  AND status = 'Pending'
);

CREATE POLICY "Finance and supers can review requests"
ON public.requests FOR UPDATE
TO authenticated
USING (
  public.current_user_role() IN ('super_admin', 'finance')
)
WITH CHECK (
  public.current_user_role() IN ('super_admin', 'finance')
  AND status IN ('Approved', 'Rejected', 'Paid')
);

CREATE POLICY "Only super-admins can hard-delete requests"
ON public.requests FOR DELETE
TO authenticated
USING (
  public.current_user_role() = 'super_admin'
);

-- 3. Notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  "relatedRequestId" UUID,
  "isRead" BOOLEAN NOT NULL DEFAULT FALSE,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "System can insert notifications for users" ON public.notifications;

CREATE POLICY "Users can read own notifications"
ON public.notifications FOR SELECT
TO authenticated
USING ("user_id" = auth.uid());

CREATE POLICY "Users can update own notifications"
ON public.notifications FOR UPDATE
TO authenticated
USING ("user_id" = auth.uid())
WITH CHECK ("user_id" = auth.uid());

CREATE POLICY "System can insert notifications for users"
ON public.notifications FOR INSERT
TO authenticated
WITH CHECK (
  "user_id" = auth.uid()
  OR public.current_user_role() IN ('super_admin', 'admin', 'finance')
);

-- 4. Private receipts bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Authenticated users can upload to receipts" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view receipts they own" ON storage.objects;
DROP POLICY IF EXISTS "Finance/admin/super-admin can view all receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own receipt objects" ON storage.objects;

CREATE POLICY "Authenticated users can upload to receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'receipts');

CREATE POLICY "Authenticated users can view receipts they own"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'receipts' AND owner = auth.uid());

CREATE POLICY "Finance/admin/super-admin can view all receipts"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'receipts'
  AND public.current_user_role() IN ('super_admin', 'admin', 'finance')
);

CREATE POLICY "Users can delete their own receipt objects"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'receipts' AND owner = auth.uid());

-- Optional helper: create signed URLs from the app using Supabase SDK for temporary access.
