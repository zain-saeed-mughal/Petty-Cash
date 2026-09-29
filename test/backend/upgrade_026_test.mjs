import {PGlite} from '../../.dart_tool/backend_tests/node_modules/@electric-sql/pglite/dist/index.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const db=new PGlite();
await db.exec("CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS; CREATE SCHEMA auth; CREATE SCHEMA storage; CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,raw_app_meta_data jsonb DEFAULT '{}',raw_user_meta_data jsonb DEFAULT '{}'); CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$; CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]); CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text,name text,owner uuid); ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY; CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql AS $$ SELECT string_to_array($1,'/') $$; GRANT USAGE ON SCHEMA public,auth,storage TO authenticated,service_role; GRANT SELECT,INSERT,DELETE ON storage.objects TO authenticated;");
const original=fs.readFileSync('supabase/migrations/202609240001_secure_app.sql','utf8')
  .replace('CREATE EXTENSION IF NOT EXISTS pgcrypto;','');
await db.exec(original);
for(const file of fs.readdirSync('supabase/migrations').filter(f=>f.endsWith('.sql') && !f.includes('001_') && !f.includes('026_')).sort()){
  await db.exec(fs.readFileSync('supabase/migrations/'+file,'utf8')
    .replaceAll('CREATE EXTENSION IF NOT EXISTS pgcrypto;',''));
}
const office='00000000-0000-0000-0000-000000000001';
const finance='00000000-0000-0000-0000-000000000002';
for(const [id,role] of [[office,'office_boy'],[finance,'finance']]){
  await db.query('INSERT INTO auth.users(id,email,raw_app_meta_data,raw_user_meta_data) VALUES($1,$2,$3,$4)',
    [id,id+'@example.test',JSON.stringify({petty_cash_role:role,petty_cash_active:true}),JSON.stringify({name:role})]);
}
async function as(id,sql,params=[]){
  await db.exec('SET ROLE authenticated');
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[id]);
  try { return await db.query(sql,params); } finally { await db.exec('RESET ROLE'); }
}
const advance='a0000000-0000-4000-8000-000000000001';
const oldExpense='e0000000-0000-4000-8000-000000000001';
await as(finance,"SELECT give_advance($1,$2,100,'Cash','Existing advance')",[advance,office]);
await as(office,"SELECT confirm_advance($1,'Cash')",[advance]);
await as(office,"SELECT submit_payment_expense($1,'float','Existing purchase',20,'Office',NULL)",[oldExpense]);
const oldBalance=(await as(office,'SELECT available_balance FROM payment_overview()')).rows[0].available_balance;
const upgrade=fs.readFileSync('supabase/migrations/202609290026_advance_requests_and_allocation.sql','utf8');
await db.exec(upgrade);
await db.exec(upgrade);
assert.equal((await db.query('SELECT advance_id FROM expenses WHERE id=$1',[oldExpense])).rows[0].advance_id,null);
assert.equal((await as(office,'SELECT available_balance FROM payment_overview()')).rows[0].available_balance,oldBalance);
assert.equal((await db.query("SELECT count(*)::int n FROM float_ledger WHERE expense_id=$1 AND entry_type='hold'",[oldExpense])).rows[0].n,1);
assert.equal((await as(office,'SELECT available FROM advance_balance_overview() WHERE advance_id=$1',[advance])).rows[0].available,'100.00');
await db.close();
console.log('PASS migration 026 preserves historical unallocated expenses and ledger balance');
