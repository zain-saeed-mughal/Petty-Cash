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
  CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,
    raw_app_meta_data jsonb DEFAULT '{}',raw_user_meta_data jsonb DEFAULT '{}');
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$
    SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql AS $$
    SELECT nullif(current_setting('request.jwt.claim.role',true),'') $$;
  CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,
    file_size_limit bigint,allowed_mime_types text[]);
  CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_id text,name text,owner uuid);
  ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
  CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql AS $$
    SELECT string_to_array($1,'/') $$;
  GRANT USAGE ON SCHEMA public,auth,storage TO authenticated,service_role;
  GRANT SELECT,INSERT,DELETE ON storage.objects TO authenticated;
`);

for (const file of fs.readdirSync('supabase/migrations').filter(f => f.endsWith('.sql')).sort()) {
  const script = fs.readFileSync(`supabase/migrations/${file}`, 'utf8')
    .replaceAll('CREATE EXTENSION IF NOT EXISTS pgcrypto;', '');
  await db.exec(script);
  await db.exec(script);
}
const staff = '00000000-0000-0000-0000-000000000011';
const other = '00000000-0000-0000-0000-000000000012';
const finance = '00000000-0000-0000-0000-000000000013';
const admin = '00000000-0000-0000-0000-000000000014';
const superId = '00000000-0000-0000-0000-000000000015';
for (const [id, role] of [[staff,'office_boy'],[other,'office_boy'],
  [finance,'finance'],[admin,'admin'],[superId,'super_admin']]) {
  await db.query(`INSERT INTO auth.users(id,email,raw_app_meta_data,raw_user_meta_data)
    VALUES($1,$2,$3,$4)`, [id, `${id}@example.test`,
    JSON.stringify({petty_cash_role:role,petty_cash_active:true}),
    JSON.stringify({name:role})]);
}
async function as(id, query, params = [], role = 'authenticated') {
  await db.exec(`SET ROLE ${role}`);
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)", [id]);
  await db.query("SELECT set_config('request.jwt.claim.role',$1,false)", [role]);
  try { return await db.query(query, params); }
  finally { await db.exec('RESET ROLE'); }
}
async function denied(label, action) {
  let error;
  try { await action(); } catch (e) { error = e; }
  assert.ok(error, `${label} must be denied`);
}
const officeId = (await as(superId, "SELECT (create_office('Branch Two')).id AS id")).rows[0].id;
await as(superId, 'SELECT assign_user_office($1,$2)', [other, officeId]);
assert.equal((await as(other, 'SELECT office_id FROM users WHERE uid=$1', [other])).rows[0].office_id, officeId);
assert.equal((await as(staff, 'SELECT count(*)::int n FROM offices')).rows[0].n, 1);
assert.equal((await as(finance, 'SELECT count(*)::int n FROM offices')).rows[0].n, 2);

const first = 'a0000000-0000-4000-8000-000000000011';
await denied('Finance unsolicited advance', () => as(finance,
  'SELECT give_advance($1,$2,100,\'Cash\',NULL)', [first,staff]));
await denied('Card advance missing account', () => as(staff,
  "SELECT request_advance_v2($1,'Laptop',100,'card')", [first]));
await as(staff, "SELECT request_advance_v2($1,'Paper',100,'cash')", [first]);
await as(staff, "SELECT request_advance_v2($1,'Paper',100,'cash')", [first]);
assert.equal((await db.query('SELECT count(*)::int n FROM advance_requests WHERE id=$1',[first])).rows[0].n,1);
assert.equal((await as(other, 'SELECT id FROM advance_requests WHERE id=$1',[first])).rows.length,0);
assert.equal((await as(finance, 'SELECT id FROM advance_requests WHERE id=$1',[first])).rows.length,1);
await denied('Office Boy clears advance', () => as(staff,
  "SELECT clear_advance_request_v2($1,'cash')", [first]));
await denied('Finance changes requested method', () => as(finance,
  "SELECT clear_advance_request_v2($1,'card')", [first]));
await as(finance, "SELECT clear_advance_request_v2($1,'cash')", [first]);
await denied('Second advance credit', () => as(finance,
  "SELECT clear_advance_request_v2($1,'cash')", [first]));
assert.equal(Number((await as(staff,
  'SELECT remaining FROM advance_balances_v2() WHERE advance_request_id=$1',[first])).rows[0].remaining),100);

const itemA = 'b0000000-0000-4000-8000-000000000011';
const itemB = 'b0000000-0000-4000-8000-000000000012';
await denied('Overspending advance', () => as(staff,
  "SELECT log_advance_item_v2($1,$2,'Paper',101)", [itemA,first]));
await denied('Finance adds Office Boy purchase', () => as(finance,
  "SELECT log_advance_item_v2($1,$2,'Paper',30)", [itemA,first]));
await as(staff, "SELECT log_advance_item_v2($1,$2,'Paper',30)", [itemA,first]);
await as(staff, "SELECT log_advance_item_v2($1,$2,'Paper',30)", [itemA,first]);
assert.equal(Number((await as(staff,
  'SELECT remaining FROM advance_balances_v2() WHERE advance_request_id=$1',[first])).rows[0].remaining),70);
await as(staff, "SELECT log_advance_item_v2($1,$2,'Fuel',70)", [itemB,first]);
assert.equal((await db.query('SELECT status FROM advance_requests WHERE id=$1',[first])).rows[0].status,'fully_utilized');
assert.equal(Number((await as(staff,
  'SELECT remaining FROM advance_balances_v2() WHERE advance_request_id=$1',[first])).rows[0].remaining),0);
await denied('Direct ledger edit', () => as(staff, 'UPDATE advance_ledger SET amount=999 WHERE advance_request_id=$1',[first]));
await denied('Direct item deletion', () => as(staff, 'DELETE FROM advance_items WHERE id=$1',[itemA]));

const card = 'a0000000-0000-4000-8000-000000000012';
await as(other, "SELECT request_advance_v2($1,'Computer',250,'card','Other','IBAN 456')", [card]);
await as(finance, "SELECT clear_advance_request_v2($1,'card')", [card]);
assert.equal((await as(staff,'SELECT id FROM advance_requests WHERE id=$1',[card])).rows.length,0);
assert.equal((await as(finance,'SELECT id FROM advance_requests WHERE id=$1',[card])).rows.length,1);

const rejected = 'c0000000-0000-4000-8000-000000000011';
await as(staff, "SELECT submit_reimbursement_v2($1,'Taxi',50,'cash')", [rejected]);
await denied('Reject without reason', () => as(finance,
  "SELECT review_reimbursement_v2($1,'reject',NULL)", [rejected]));
await denied('Office Boy approves own claim', () => as(staff,
  "SELECT review_reimbursement_v2($1,'approve')", [rejected]));
await as(finance, "SELECT review_reimbursement_v2($1,'reject','No trip recorded')", [rejected]);
assert.equal((await as(staff, 'SELECT rejection_reason FROM reimbursement_requests WHERE id=$1',[rejected])).rows[0].rejection_reason,'No trip recorded');
await denied('Pay rejected claim', () => as(finance,
  "SELECT mark_reimbursement_paid_v2($1,'cash')", [rejected]));

const paid = 'c0000000-0000-4000-8000-000000000012';
await as(other, "SELECT submit_reimbursement_v2($1,'Cable',80,'card')", [paid]);
assert.equal((await as(staff,'SELECT id FROM reimbursement_requests WHERE id=$1',[paid])).rows.length,0);
await as(finance, "SELECT review_reimbursement_v2($1,'approve')", [paid]);
await as(finance, "SELECT mark_reimbursement_paid_v2($1,'card')", [paid]);
await denied('Duplicate payment', () => as(finance,
  "SELECT mark_reimbursement_paid_v2($1,'card')", [paid]));
assert.equal((await db.query('SELECT status FROM reimbursement_requests WHERE id=$1',[paid])).rows[0].status,'paid');
assert.equal((await as(admin,'SELECT count(*)::int n FROM reimbursement_requests')).rows[0].n,2);
assert.ok((await as(other,'SELECT count(*)::int n FROM core_payment_activity')).rows[0].n >= 4);

await as(superId, 'SELECT delete_office_boy_data($1)', [staff], 'service_role');
assert.equal((await db.query('SELECT count(*)::int n FROM advance_items WHERE office_boy_id=$1',[staff])).rows[0].n,0);
assert.equal((await db.query('SELECT count(*)::int n FROM reimbursement_requests WHERE office_boy_id=$1',[staff])).rows[0].n,0);
await db.close();
console.log('PASS requested advances, per-advance balance, repayment, office RLS, audit and purge');
