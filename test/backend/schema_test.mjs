import {PGlite} from '../../.dart_tool/backend_tests/node_modules/@electric-sql/pglite/dist/index.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const sql=fs.readFileSync('supabase/migrations/202609240001_secure_app.sql','utf8').replace('CREATE EXTENSION IF NOT EXISTS pgcrypto;','');
const db=new PGlite();
await db.exec("CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS; CREATE SCHEMA auth; CREATE SCHEMA storage; CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,raw_app_meta_data jsonb DEFAULT '{}',raw_user_meta_data jsonb DEFAULT '{}'); CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$; CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]); CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text,name text,owner uuid); ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY; CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql AS $$ SELECT string_to_array($1,'/') $$; GRANT USAGE ON SCHEMA public,auth,storage TO authenticated,service_role; GRANT SELECT,INSERT,DELETE ON storage.objects TO authenticated;");
await db.exec(sql); await db.exec(sql);
console.log('PASS fresh schema and repeat migration');
const staff='00000000-0000-0000-0000-000000000001',finance='00000000-0000-0000-0000-000000000002',superId='00000000-0000-0000-0000-000000000003',inactive='00000000-0000-0000-0000-000000000004';
for(const [id,role,active] of [[staff,'office_boy',true],[finance,'finance',true],[superId,'super_admin',true],[inactive,'office_boy',false]]){
 await db.query("INSERT INTO auth.users(id,email,raw_app_meta_data,raw_user_meta_data) VALUES($1,$2,$3,$4)",[id,id+'@example.test',JSON.stringify({petty_cash_role:role,petty_cash_active:active}),JSON.stringify({name:role})]);
}
async function as(id,query,params=[]){
 await db.exec("SET ROLE authenticated");
 await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[id]);
 try{return await db.query(query,params);}finally{await db.exec("RESET ROLE");}
}
async function denied(label,action){
 let error;try{await action();}catch(e){error=e;}
 assert.ok(error,label+' must fail');console.log('PASS '+label+' denied ('+error.code+')');
}
await denied('self role escalation',()=>as(staff,"UPDATE users SET role='super_admin' WHERE uid=$1",[staff]));
await denied('self reactivation',()=>as(inactive,'UPDATE users SET "isActive"=true WHERE uid=$1',[inactive]));
const id='10000000-0000-0000-0000-000000000001';
await denied('direct paid insert',()=>as(staff,'INSERT INTO requests(id,"requestedBy","requesterName","itemDescription",amount,reason,status) VALUES($1,$2,\'staff\',\'paper\',10,\'office\',\'Paid\')',[id,staff]));
await denied('inactive submission',()=>as(inactive,'SELECT submit_request($1,\'paper\',10,\'office\',NULL)',[id]));
await denied('NaN amount',()=>as(staff,"SELECT submit_request($1,'paper','NaN','office',NULL)",[id]));
await denied('extra decimals',()=>as(staff,"SELECT submit_request($1,'paper',1.001,'office',NULL)",[id]));
await as(staff,"SELECT submit_request($1,'paper',10.25,'office',NULL)",[id]);
await as(staff,"SELECT submit_request($1,'paper',10.25,'office',NULL)",[id]);
assert.equal((await db.query("SELECT count(*)::int n FROM requests")).rows[0].n,1);
assert.equal((await db.query("SELECT count(*)::int n FROM notifications")).rows[0].n,2);
console.log('PASS idempotent submission and server notifications');
await denied('staff payment',()=>as(staff,"SELECT review_request($1,0,'Paid',NULL,false)",[id]));
await as(finance,"SELECT review_request($1,0,'Paid',NULL,false)",[id]);
await denied('stale payment overwrite',()=>as(finance,"SELECT review_request($1,0,'Rejected','stale',false)",[id]));
await denied('paid to rejected without override',()=>as(finance,"SELECT review_request($1,1,'Rejected','stale',false)",[id]));
let row=(await db.query('SELECT * FROM requests WHERE id=$1',[id])).rows[0];
assert.equal(row.status,'Paid');assert.equal(row.auditLogs.length,2);assert.ok(row.paidAt);assert.equal(row.version,1);
await as(superId,"SELECT review_request($1,1,'Pending','Reopen to verify receipt',true)",[id]);
row=(await db.query('SELECT * FROM requests WHERE id=$1',[id])).rows[0];
assert.equal(row.status,'Pending');assert.equal(row.auditLogs.length,3);assert.equal(row.paidAt,null);
console.log('PASS version checks, immutable audit append and explicit override');
await denied('last super-admin disabled',()=>db.query("UPDATE auth.users SET raw_app_meta_data=raw_app_meta_data||'{\"petty_cash_active\":false}' WHERE id=$1",[superId]));
await db.query("UPDATE auth.users SET email='new@example.test' WHERE id=$1",[staff]);
assert.equal((await db.query("SELECT email FROM users WHERE uid=$1",[staff])).rows[0].email,'new@example.test');
console.log('PASS auth/profile email synchronization');
await as(staff,"SELECT register_device('test-device-token-12345','android')");
await as(finance,"SELECT register_device('test-device-token-12345','android')");
assert.equal((await db.query('SELECT user_id FROM device_tokens')).rows[0].user_id,finance);
await as(staff,"SELECT unregister_device('test-device-token-12345')");
assert.equal((await db.query('SELECT count(*)::int n FROM device_tokens')).rows[0].n,1);
await as(finance,"SELECT unregister_device('test-device-token-12345')");
assert.equal((await db.query('SELECT count(*)::int n FROM device_tokens')).rows[0].n,0);
console.log('PASS device ownership and logout cleanup');
let notification=(await as(staff,'SELECT id FROM notifications LIMIT 1')).rows[0];
assert.ok(notification);
await as(staff,'UPDATE notifications SET is_read=true WHERE id=$1',[notification.id]);
await as(staff,'DELETE FROM notifications WHERE id=$1',[notification.id]);
assert.equal((await as(staff,'SELECT id FROM notifications WHERE id=$1',[notification.id])).rows.length,0);
await denied('notification recipient tampering',()=>as(staff,'UPDATE notifications SET user_id=$1',[finance]));
console.log('PASS notification read/delete permissions');
await db.close();
console.log('All schema security and workflow tests passed.');

