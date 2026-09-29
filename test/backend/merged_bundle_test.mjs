import {PGlite} from '../../.dart_tool/backend_tests/node_modules/@electric-sql/pglite/dist/index.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const bundle=fs.readFileSync('deployment/2026-09-29-payment-account/complete_setup.sql','utf8')
  .replaceAll('CREATE EXTENSION IF NOT EXISTS pgcrypto;','');
const db=new PGlite();
await db.exec("CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS; CREATE SCHEMA auth; CREATE SCHEMA storage; CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,raw_app_meta_data jsonb DEFAULT '{}',raw_user_meta_data jsonb DEFAULT '{}'); CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$; CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]); CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text,name text,owner uuid); ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY; CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql AS $$ SELECT string_to_array($1,'/') $$; GRANT USAGE ON SCHEMA public,auth,storage TO authenticated,service_role; GRANT SELECT,INSERT,DELETE ON storage.objects TO authenticated;");
await db.exec(bundle);
await db.exec(bundle);
for(const [id,role] of [
  ['00000000-0000-0000-0000-000000000001','office_boy'],
  ['00000000-0000-0000-0000-000000000002','finance'],
]) {
  await db.query('INSERT INTO auth.users(id,email,raw_app_meta_data,raw_user_meta_data) VALUES($1,$2,$3,$4)',
    [id,id+'@example.test',JSON.stringify({petty_cash_role:role,petty_cash_active:true}),JSON.stringify({name:role})]);
}
assert.ok((await db.query("SELECT to_regclass('public.advances') AS table_name")).rows[0].table_name);
await db.exec(fs.readFileSync('test/backend/live_payment_smoke.sql','utf8'));
assert.equal((await db.query('SELECT count(*)::int n FROM advances')).rows[0].n,0);
assert.equal((await db.query('SELECT count(*)::int n FROM float_ledger')).rows[0].n,0);
await db.close();
console.log('PASS merged SQL Editor bundle, repeat application and rollback-only payment flows');
