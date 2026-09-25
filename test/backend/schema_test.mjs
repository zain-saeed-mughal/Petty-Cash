import {PGlite} from '../../.dart_tool/backend_tests/node_modules/@electric-sql/pglite/dist/index.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const sql=fs.readFileSync('supabase/migrations/202609240001_secure_app.sql','utf8').replace('CREATE EXTENSION IF NOT EXISTS pgcrypto;','');
const db=new PGlite();
await db.exec("CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS; CREATE SCHEMA auth; CREATE SCHEMA storage; CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,raw_app_meta_data jsonb DEFAULT '{}',raw_user_meta_data jsonb DEFAULT '{}'); CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$; CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]); CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text,name text,owner uuid); ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY; CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql AS $$ SELECT string_to_array($1,'/') $$; GRANT USAGE ON SCHEMA public,auth,storage TO authenticated,service_role; GRANT SELECT,INSERT,DELETE ON storage.objects TO authenticated;");
await db.exec(sql); await db.exec(sql);
for (const file of fs.readdirSync('supabase/migrations').filter(f => f.endsWith('.sql') && !f.includes('001_')).sort()) {
 const migration = fs.readFileSync('supabase/migrations/'+file,'utf8').replaceAll('CREATE EXTENSION IF NOT EXISTS pgcrypto;','');
 await db.exec(migration); await db.exec(migration);
}
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
await denied('null review version',()=>as(finance,"SELECT review_request($1,NULL,'Paid',NULL,false)",[id]));
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
await as(staff,"SELECT register_device_language('localized-device-1234','web','ur')");
assert.equal((await db.query("SELECT language_code FROM device_tokens WHERE token='localized-device-1234'")).rows[0].language_code,'ur');
await denied('unsupported language',()=>as(staff,"SELECT register_device_language('localized-device-1234','web','fr')"));
await denied('inactive device registration',()=>as(inactive,"SELECT register_device_language('inactive-device-1234','web','ur')"));
await denied('client push claims',()=>as(staff,'SELECT * FROM claim_push_batch()'));
await db.exec('SET ROLE service_role');
const firstBatch = await db.query('SELECT * FROM claim_push_batch()');
assert.ok(firstBatch.rows.length>0);
assert.equal((await db.query('SELECT * FROM claim_push_batch()')).rows.length,0);
await db.exec('RESET ROLE');
assert.ok((await db.query('SELECT * FROM push_outbox')).rows.every(r=>r.attempts===1));
console.log('PASS localized device registration, protected outbox and retry lease');
await denied('foreign receipt upload',()=>as(staff,"INSERT INTO storage.objects(bucket_id,name,owner) VALUES('receipts',$1,$2)",[finance+'/bad.jpg',staff]));
await as(staff,"INSERT INTO storage.objects(bucket_id,name,owner) VALUES('receipts',$1,$2)",[staff+'/receipt.jpg',staff]);
assert.equal((await as(inactive,'SELECT * FROM storage.objects')).rows.length,0);
assert.equal((await as(finance,'SELECT * FROM storage.objects')).rows.length,1);
await as(staff,"SELECT submit_request('f0010000-0000-0000-0000-000000000001','Receipt request',22,'Stationery',$1)",[staff+'/receipt.jpg']);
await as(staff,"DELETE FROM storage.objects WHERE name=$1",[staff+'/receipt.jpg']);
assert.equal((await db.query('SELECT * FROM storage.objects')).rows.length,1);
console.log('PASS private receipts and referenced receipt retention');
const statuses=['Pending','Approved','Rejected','Paid','Pending Settlement','Settled'];
for (const [i,status] of statuses.entries()) {
 const requestId='de100000-0000-0000-0000-00000000000'+i;
 await as(staff,"SELECT submit_request($1,'Delete test',25,'Testing',NULL,'advance')",[requestId]);
 await db.query('UPDATE requests SET status=$1 WHERE id=$2',[status,requestId]);
 await denied('non-admin '+status+' deletion',()=>as(finance,'SELECT delete_request($1)',[requestId]));
 await as(superId,'SELECT delete_request($1)',[requestId]);
 assert.equal((await db.query('SELECT id FROM requests WHERE id=$1',[requestId])).rows.length,0);
 const audit=(await db.query('SELECT * FROM request_deletion_audit WHERE request_id=$1',[requestId])).rows[0];
 assert.equal(audit.request_snapshot.status,status); assert.equal(audit.deleted_by,superId);
}
assert.equal((await as(staff,'SELECT * FROM request_deletion_audit')).rows.length,0);
await denied('deletion audit modification',()=>as(superId,'DELETE FROM request_deletion_audit'));
console.log('PASS super-admin deletion for all 6 statuses with protected audit retention');
// Included by schema_test.mjs before closing its isolated database.
const settlementId='77777777-7777-4777-8777-777777777777';
await as(staff,"SELECT submit_request($1,'Settlement regression',100,'Office',NULL,'advance')",[settlementId]);
await as(finance,"SELECT review_request($1,0,'Paid',NULL,false)",[settlementId]);
for (const bad of [null,-1,101,'NaN','Infinity','-Infinity',10.123]) {
 await denied('invalid settlement '+bad,()=>as(staff,"SELECT settle_advance_request($1,1,$2,'Cash','note')",[settlementId,bad]));
}
await denied('invalid return method',()=>as(staff,"SELECT settle_advance_request($1,1,50,'INVALID','note')",[settlementId]));
await denied('missing return method',()=>as(staff,"SELECT settle_advance_request($1,1,50,NULL,'note')",[settlementId]));
await denied('oversized note',()=>as(staff,"SELECT settle_advance_request($1,1,50,'Cash',$2)",[settlementId,'x'.repeat(2001)]));
await as(staff,"SELECT settle_advance_request($1,1,50.25,'Cash','First')",[settlementId]);
const noticesBefore=(await db.query('SELECT count(*)::int n FROM notifications WHERE related_request_id=$1',[settlementId])).rows[0].n;
await as(staff,"SELECT settle_advance_request($1,2,60.75,'Card','Corrected')",[settlementId]);
const noticesAfter=(await db.query('SELECT count(*)::int n FROM notifications WHERE related_request_id=$1',[settlementId])).rows[0].n;
assert.equal(noticesAfter-noticesBefore,3); // requester + finance + super-admin
await denied('stale settlement verification',()=>as(finance,'SELECT verify_advance_settlement($1,2)',[settlementId]));
await as(finance,'SELECT verify_advance_settlement($1,3)',[settlementId]);
let settled=(await db.query('SELECT * FROM requests WHERE id=$1',[settlementId])).rows[0];
assert.equal(settled.status,'Settled'); assert.equal(Number(settled.settlement_amount),60.75); assert.ok(settled.paidAt);
await as(superId,"SELECT review_request($1,4,'Pending','Reopen to correct',true)",[settlementId]);
settled=(await db.query('SELECT * FROM requests WHERE id=$1',[settlementId])).rows[0];
assert.equal(settled.settlement_amount,null);assert.equal(settled.is_settled,false);
await db.query("UPDATE requests SET status='Pending Settlement',settlement_amount=NULL WHERE id=$1",[settlementId]);
await denied('legacy invalid settlement verification',()=>as(finance,'SELECT verify_advance_settlement($1,5)',[settlementId]));
console.log('PASS settlement bounds, update notifications, stale verification and reopening cleanup');

async function syncAs(uid,cursor=0,size=2) {
 return (await as(uid,'SELECT sync_requests($1,$2) AS result',[cursor,size])).rows[0].result;
}
await denied('inactive sync',()=>syncAs(inactive));
await denied('invalid sync size',()=>syncAs(staff,0,501));
await denied('direct change-feed access',()=>as(staff,'SELECT * FROM request_changes'));
let cursor=0, changes=[];
for (;;) {
 const page=await syncAs(staff,cursor); changes.push(...page.changes);cursor=page.cursor;
 if (!page.has_more) break;
}
assert.ok(changes.length>0);
assert.ok(changes.every(c=>c.deleted || c.request.requestedBy===staff));
assert.equal((await syncAs(staff,cursor)).changes.length,0);
await as(finance,"SELECT submit_request('66666666-6666-4666-8666-666666666666','Private request',1,'Office',NULL)");
let privatePage=await syncAs(staff,cursor);
assert.equal(privatePage.changes.length,0);cursor=privatePage.cursor;
assert.ok((await syncAs(superId)).changes.length>0);
await as(superId,'SELECT delete_request($1)',[settlementId]);
const deletion=await syncAs(staff,cursor);
assert.equal(deletion.changes.length,1);
assert.equal(deletion.changes[0].id,settlementId);assert.equal(deletion.changes[0].deleted,true);
assert.equal(deletion.changes[0].request,null);
// Reapplying the migration must preserve the cursor and not resend history.
await db.exec(fs.readFileSync('supabase/migrations/202609250023_incremental_requests.sql','utf8'));
assert.equal((await syncAs(staff,deletion.cursor)).changes.length,0);
console.log('PASS incremental pages, no-change refresh, role isolation, deletion tombstones and cursor retention');

await db.close();
console.log('All schema security and workflow tests passed.');


