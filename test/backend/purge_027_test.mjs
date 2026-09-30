import { PGlite } from '../../.dart_tool/backend_tests/node_modules/@electric-sql/pglite/dist/index.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
await db.exec(`
  CREATE ROLE anon;
  CREATE ROLE authenticated;
  CREATE ROLE service_role BYPASSRLS;
  CREATE SCHEMA auth;
  CREATE SCHEMA storage;
  CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,raw_app_meta_data jsonb DEFAULT '{}',raw_user_meta_data jsonb DEFAULT '{}');
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('request.jwt.claim.role',true),'') $$;
  CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
  CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text,name text,owner uuid);
  ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
  CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql AS $$ SELECT string_to_array($1,'/') $$;
  GRANT USAGE ON SCHEMA public,auth,storage TO authenticated,service_role;
  GRANT SELECT,INSERT,DELETE ON storage.objects TO authenticated;
`);
const original = fs.readFileSync('supabase/migrations/202609240001_secure_app.sql', 'utf8')
  .replace('CREATE EXTENSION IF NOT EXISTS pgcrypto;', '');
await db.exec(original);
for (const file of fs.readdirSync('supabase/migrations').filter(
  (name) => name.endsWith('.sql') && !name.includes('001_') && name < '202609300029',
).sort()) {
  await db.exec(fs.readFileSync(`supabase/migrations/${file}`, 'utf8')
    .replaceAll('CREATE EXTENSION IF NOT EXISTS pgcrypto;', ''));
}

const office = '00000000-0000-0000-0000-000000000001';
const otherOffice = '00000000-0000-0000-0000-000000000002';
const finance = '00000000-0000-0000-0000-000000000003';
for (const [id, role] of [
  [office, 'office_boy'], [otherOffice, 'office_boy'], [finance, 'finance'],
]) {
  await db.query('INSERT INTO auth.users(id,email,raw_app_meta_data,raw_user_meta_data) VALUES($1,$2,$3,$4)', [
    id, `${id}@example.test`,
    JSON.stringify({ petty_cash_role: role, petty_cash_active: true }),
    JSON.stringify({ name: role }),
  ]);
}
async function as(id, query, params = []) {
  await db.exec('SET ROLE authenticated');
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)", [id]);
  await db.exec("SELECT set_config('request.jwt.claim.role','authenticated',false)");
  try { return await db.query(query, params); }
  finally { await db.exec('RESET ROLE'); }
}
const advance = 'a0000000-0000-4000-8000-000000000001';
const expense = 'e0000000-0000-4000-8000-000000000001';
const request = 'f0000000-0000-4000-8000-000000000001';
const earlierDeletedRequest = 'f0000000-0000-4000-8000-000000000002';
await as(finance, "SELECT give_advance($1,$2,100,'Cash','Petty cash')", [advance, office]);
await as(office, "SELECT confirm_advance($1,'Cash')", [advance]);
await as(office, "SELECT submit_payment_expense($1,'float','Paper',20,'Office',NULL,$2)", [expense, advance]);
await as(office, "SELECT submit_request($1,'Legacy paper',10,'Office',NULL)", [request]);
await as(office, "SELECT submit_request($1,'Older deleted purchase',12,'Office',NULL)", [earlierDeletedRequest]);
await db.query(`
  INSERT INTO request_deletion_audit(request_id,deleted_by,request_snapshot)
  SELECT id,$2,to_jsonb(r) FROM requests r WHERE id=$1
`, [earlierDeletedRequest, finance]);
await db.query('DELETE FROM requests WHERE id=$1', [earlierDeletedRequest]);
assert.equal((await db.query('SELECT count(*)::int n FROM request_deletion_audit WHERE request_id=$1', [earlierDeletedRequest])).rows[0].n, 1);
await as(finance, "SELECT give_advance($1,$2,50,'Card','Other person')", [
  'a0000000-0000-4000-8000-000000000002', otherOffice,
]);

await assert.rejects(as(office, 'SELECT delete_office_boy_data($1)', [office]));
assert.ok((await db.query('SELECT count(*)::int n FROM float_ledger WHERE office_boy_id=$1', [office])).rows[0].n > 0);

await db.exec('SET ROLE service_role');
await db.exec("SELECT set_config('request.jwt.claim.role','service_role',false)");
try { await db.query('SELECT delete_office_boy_data($1)', [office]); }
finally { await db.exec('RESET ROLE'); }

for (const table of ['requests', 'advance_requests', 'advances', 'expenses', 'float_ledger', 'payment_activity']) {
  const column = table === 'requests' ? '"requestedBy"' : 'office_boy_id';
  assert.equal((await db.query(`SELECT count(*)::int n FROM ${table} WHERE ${column}=$1`, [office])).rows[0].n, 0, table);
}
assert.equal((await db.query('SELECT "isActive" FROM users WHERE uid=$1', [office])).rows[0].isActive, false);
assert.equal((await db.query('SELECT count(*)::int n FROM request_deletion_audit WHERE request_id=$1', [earlierDeletedRequest])).rows[0].n, 0);
assert.equal((await db.query('SELECT count(*)::int n FROM notifications WHERE related_request_id=$1', [earlierDeletedRequest])).rows[0].n, 0);
assert.equal((await db.query('SELECT count(*)::int n FROM advances WHERE office_boy_id=$1', [otherOffice])).rows[0].n, 1);
await db.query('DELETE FROM auth.users WHERE id=$1', [office]);
assert.equal((await db.query('SELECT count(*)::int n FROM users WHERE uid=$1', [office])).rows[0].n, 0);
await db.close();
console.log('PASS service-only purge removes current and earlier-deleted records while preserving other users');
