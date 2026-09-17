-- Run this SQL in your Supabase SQL Editor to create the necessary tables for Petty Cash Manager

-- 1. Create Users Table
CREATE TABLE public.users (
  uid UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'office_boy',
  "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  "isActive" BOOLEAN DEFAULT TRUE
);

-- Enable Row Level Security (RLS) for Users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all authenticated users" ON public.users FOR SELECT TO authenticated USING (true);
CREATE POLICY "Enable insert/update for authenticated users" ON public.users FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 2. Create Requests Table
CREATE TABLE public.requests (
  id TEXT PRIMARY KEY,
  "requestedBy" UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  "requesterName" TEXT NOT NULL,
  "requesterEmail" TEXT,
  "itemDescription" TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  reason TEXT NOT NULL,
  "billImageUrl" TEXT,
  status TEXT NOT NULL DEFAULT 'Pending',
  "rejectionReason" TEXT,
  "reviewedBy" UUID REFERENCES public.users(uid) ON DELETE SET NULL,
  "reviewedByName" TEXT,
  "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  "auditLogs" JSONB DEFAULT '[]'::jsonb
);

-- Enable Row Level Security (RLS) for Requests
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all authenticated users" ON public.requests FOR SELECT TO authenticated USING (true);
CREATE POLICY "Enable insert/update for authenticated users" ON public.requests FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users" ON public.requests FOR DELETE TO authenticated USING (true);

-- 3. Create Storage Bucket for Receipts
INSERT INTO storage.buckets (id, name, public) VALUES ('receipts', 'receipts', true) ON CONFLICT DO NOTHING;

CREATE POLICY "Enable read access for all" ON storage.objects FOR SELECT USING (bucket_id = 'receipts');
CREATE POLICY "Enable insert for authenticated users" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'receipts');
