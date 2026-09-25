import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
const cors = {"Access-Control-Allow-Origin":"*", "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods":"POST, OPTIONS"};
const reply = (body: unknown, status=200) => Response.json(body,{status,headers:cors});
export const createHandler = (db: SupabaseClient) => async (req: Request): Promise<Response> => {
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 if(req.method!=="POST") return reply({error:"Method not allowed"},405);
 try {
  const bearer=req.headers.get("Authorization")?.replace(/^Bearer\s+/i,"");
  if(!bearer) return reply({error:"Sign in to continue"},401);
  const {data:identity,error:authError}=await db.auth.getUser(bearer);
  if(authError||!identity.user) return reply({error:"Session expired"},401);
  const {data:actor,error:actorError}=await db.from("users").select("uid,role,isActive").eq("uid",identity.user.id).single();
  if(actorError||!actor?.isActive||!["admin","super_admin"].includes(actor.role)) return reply({error:"Not authorized"},403);
  const body=await req.json();
  const {action,uid}=body;
  if(!["create","update","deactivate"].includes(action)) return reply({error:"Invalid action"},400);
  let target: Record<string,unknown>|null=null;
  if(action!=="create"){
   const {data,error}=await db.from("users").select("uid,role,isActive").eq("uid",uid).single();
   if(error||!data) return reply({error:"User not found"},404);
   target=data;
   if(actor.role==="admin"&&!["office_boy","finance"].includes(String(data.role))) return reply({error:"You cannot manage this role"},403);
   if(action==="deactivate"&&uid===actor.uid) return reply({error:"You cannot deactivate your own account"},400);
  }
  if(action==="deactivate"){
   // Preserve history. Auth and the profile are updated atomically by the DB trigger.
   const {error}=await db.auth.admin.updateUserById(uid,{
    ban_duration:"876000h",app_metadata:{petty_cash_role:target!.role,petty_cash_active:false}
   });
   if(error) return reply({error:error.message},400);
   return reply({ok:true});
  }
  const name=String(body.name??"").trim(), email=String(body.email??"").trim().toLowerCase();
  const role=String(body.role??""), password=body.password==null?null:String(body.password);
  if(!name||name.length>120||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply({error:"Enter a valid name and email"},400);
  if(!["office_boy","finance","admin","super_admin"].includes(role)||(actor.role==="admin"&&!["office_boy","finance"].includes(role))) return reply({error:"Role is not allowed"},403);
  if(uid===actor.uid && (role!==actor.role||body.isActive===false)) return reply({error:"Ask another super-admin to change your access"},400);
  if((action==="create"||password)&&(!password||password.length<6||password.length>8)) return reply({error:"Use a password with 6 to 8 characters"},400);
  const attributes={
   email,user_metadata:{name},app_metadata:{petty_cash_role:role,petty_cash_active:body.isActive!==false},
   ...(password?{password}:{}),
  };
  const result=action==="create"
   ? await db.auth.admin.createUser({...attributes,email_confirm:true})
   : await db.auth.admin.updateUserById(uid,{...attributes,ban_duration:body.isActive===false?"876000h":"none"});
  if(result.error) return reply({error:result.error.message},400);
  return reply({ok:true,uid:result.data.user?.id});
 }catch(error){
  console.error("manage-user request failed",error instanceof Error?error.name:"unknown");
  return reply({error:"The account could not be updated. Please try again."},500);
 }
};

Deno.serve(createHandler(createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {auth:{persistSession:false,autoRefreshToken:false}})));
