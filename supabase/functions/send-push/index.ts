import { createClient } from "npm:@supabase/supabase-js@2";
type ServiceAccount={client_email:string;private_key:string;project_id:string};
const bytes=(s:string)=>new TextEncoder().encode(s);
const b64=(b:Uint8Array)=>btoa(String.fromCharCode(...b)).replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_");
async function accessToken(account:ServiceAccount){
 const now=Math.floor(Date.now()/1000);
 const payload=b64(bytes(JSON.stringify({alg:"RS256",typ:"JWT"})))+"."+
  b64(bytes(JSON.stringify({iss:account.client_email,scope:"https://www.googleapis.com/auth/firebase.messaging",aud:"https://oauth2.googleapis.com/token",iat:now,exp:now+3600})));
 const pem=account.private_key.replace(/-----[^-]+-----/g,"").replace(/\s/g,"");
 const key=await crypto.subtle.importKey("pkcs8",Uint8Array.from(atob(pem),c=>c.charCodeAt(0)),{name:"RSASSA-PKCS1-v1_5",hash:"SHA-256"},false,["sign"]);
 const signature=await crypto.subtle.sign("RSASSA-PKCS1-v1_5",key,bytes(payload));
 const response=await fetch("https://oauth2.googleapis.com/token",{method:"POST",
  headers:{"Content-Type":"application/x-www-form-urlencoded"},
  body:new URLSearchParams({grant_type:"urn:ietf:params:oauth:grant-type:jwt-bearer",assertion:payload+"."+b64(new Uint8Array(signature))}),
  signal:AbortSignal.timeout(15000),
 });
 if(!response.ok)throw new Error("Firebase credentials could not be authorized");
 return (await response.json()).access_token as string;
}
Deno.serve(async(req)=>{
 const secret=Deno.env.get("PUSH_WORKER_SECRET");
 if(!secret||req.headers.get("x-worker-secret")!==secret)return Response.json({error:"Unauthorized"},{status:401});
 if(req.method!=="POST")return new Response(null,{status:405});
 try{
  const account=JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")??"{}") as ServiceAccount;
  if(!account.project_id||!account.private_key||!account.client_email)throw new Error("Firebase sender is not configured");
  const token=await accessToken(account);
  const db=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}});
  const {data:batch,error}=await db.rpc("claim_push_batch");
  if(error)throw error;
  let completed=0;
  for(const job of batch??[]){
   try{
    const {data:user,error:userError}=await db.from("users").select("isActive").eq("uid",job.user_id).maybeSingle();
    if(userError)throw userError;
    const {data:devices,error:deviceError}=await db.from("device_tokens").select("token").eq("user_id",job.user_id);
    if(deviceError)throw deviceError;
    if(user?.isActive){
     for(const device of devices??[]){
      const response=await fetch("https://fcm.googleapis.com/v1/projects/"+encodeURIComponent(account.project_id)+"/messages:send",{
       method:"POST",headers:{Authorization:"Bearer "+token,"Content-Type":"application/json"},
       body:JSON.stringify({message:{
        token:device.token,
        // Lock-screen content stays generic; app fetches protected details after sign-in.
        notification:{title:"Petty Cash update",body:"Open Petty Cash to view your notification."},
        data:{request_id:job.request_id??"",user_id:job.user_id},
        android:{priority:"high"},apns:{payload:{aps:{sound:"default"}}},
       }}),signal:AbortSignal.timeout(15000)});
      if(!response.ok){
       const result=await response.json();
       const unregistered=result.error?.details?.some((d:{errorCode?:string})=>d.errorCode==="UNREGISTERED");
       if(unregistered)await db.from("device_tokens").delete().eq("token",device.token).eq("user_id",job.user_id);
       else throw new Error("FCM delivery failed: "+response.status);
      }
     }
    }
    const {error:saveError}=await db.from("push_outbox").update({sent_at:new Date().toISOString(),last_error:null}).eq("id",job.id);
    if(saveError)throw saveError;
    completed++;
   }catch(error){
    await db.from("push_outbox").update({last_error:error instanceof Error?error.message:"Delivery failed"}).eq("id",job.id);
   }
  }
  return Response.json({claimed:batch?.length??0,completed});
 }catch(error){
  console.error("push worker failed",error instanceof Error?error.message:"Unknown error");
  return Response.json({error:"Push worker is not ready. Check server configuration."},{status:503});
 }
});

