// @ts-ignore: Deno npm specifier
import { type SupabaseClient } from "npm:@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: cors });

async function removeUserReceipts(db: SupabaseClient, uid: string) {
  const bucket = db.storage.from("receipts");
  const paths: string[] = [];
  const collect = async (folder: string): Promise<void> => {
    let offset = 0;
    while (true) {
      const { data, error } = await bucket.list(folder, {
        limit: 1000,
        offset,
      });
      if (error) throw error;
      const entries = data ?? [];
      for (const entry of entries) {
        const path = `${folder}/${entry.name}`;
        if (entry.id === null) await collect(path);
        else paths.push(path);
      }
      if (entries.length < 1000) break;
      offset += entries.length;
    }
  };
  await collect(uid);
  for (let offset = 0; offset < paths.length; offset += 100) {
    const { error } = await bucket.remove(paths.slice(offset, offset + 100));
    if (error) throw error;
  }
}

async function removeQueuedReceipts(db: SupabaseClient, uid: string) {
  const paths: string[] = [];
  while (true) {
    const { data, error } = await db.from("account_deletion_receipts")
      .select("path").eq("account_uid", uid)
      .order("path")
      .range(paths.length, paths.length + 999);
    if (error) throw error;
    paths.push(...(data ?? []).map((row) => row.path as string));
    if ((data ?? []).length < 1000) break;
  }
  for (let offset = 0; offset < paths.length; offset += 100) {
    const { error: removeError } = await db.storage.from("receipts")
      .remove(paths.slice(offset, offset + 100));
    if (removeError) throw removeError;
  }
  if (paths.length > 0) {
    const { error: clearError } = await db.from("account_deletion_receipts")
      .delete().eq("account_uid", uid);
    if (clearError) throw clearError;
  }
}

export const createHandler =
  (db: SupabaseClient) => async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    if (req.method !== "POST") {
      return reply({ error: "Method not allowed" }, 405);
    }
    try {
      const bearer = req.headers.get("Authorization")?.replace(
        /^Bearer\s+/i,
        "",
      );
      if (!bearer) return reply({ error: "Sign in to continue" }, 401);
      const { data: identity, error: authError } = await db.auth.getUser(
        bearer,
      );
      if (authError || !identity.user) {
        return reply({ error: "Session expired" }, 401);
      }
      const { data: actor, error: actorError } = await db.from("users").select(
        "uid,role,isActive,office_id",
      ).eq("uid", identity.user.id).single();
      if (
        actorError || !actor?.isActive ||
        !["admin", "super_admin"].includes(actor.role)
      ) return reply({ error: "Not authorized" }, 403);
      const body = await req.json();
      const { action, uid } = body;
      if (body.isActive !== undefined && typeof body.isActive !== "boolean") {
        return reply({ error: "Account active state must be true or false" }, 400);
      }
      if (!["create", "update", "deactivate", "delete"].includes(action)) {
        return reply({ error: "Invalid action" }, 400);
      }
      let target: Record<string, unknown> | null = null;
      if (action !== "create") {
        const { data, error } = await db.from("users").select(
          "uid,name,email,role,isActive,office_id",
        ).eq("uid", uid).single();
        if (error || !data) return reply({ error: "User not found" }, 404);
        target = data;
        if (
          actor.role === "admin" &&
          !["office_boy", "finance"].includes(String(data.role))
        ) return reply({ error: "You cannot manage this role" }, 403);
        if (action === "deactivate" && uid === actor.uid) {
          return reply(
            { error: "You cannot deactivate your own account" },
            400,
          );
        }
      }
      if (action === "deactivate") {
        // Preserve history. Auth and the profile are updated atomically by the DB trigger.
        const { error } = await db.auth.admin.updateUserById(uid, {
          ban_duration: "876000h",
          app_metadata: {
            petty_cash_role: target!.role,
            petty_cash_active: false,
          },
        });
        if (error) return reply({ error: error.message }, 400);
        return reply({ ok: true });
      }
      if (action === "delete") {
        if (actor.role !== "super_admin") {
          return reply({
            error: "Only super-admins can delete users completely",
          }, 403);
        }
        if (uid === actor.uid) {
          return reply({ error: "You cannot delete your own account" }, 400);
        }
        // The Edge Function may be deployed before the SQL patch. Fail without
        // disabling the account until the transactional migration is present.
        const { error: schemaError } = await db.from("account_deletion_receipts")
          .select("account_uid").limit(1);
        if (schemaError) {
          return reply({ error: "Run the account deletion SQL patch first" }, 409);
        }
        // Disable sign-in before any irreversible cleanup. Every following step
        // can be retried with the same uid if storage, SQL, or Auth fails.
        const { error: banError } = await db.auth.admin.updateUserById(uid, {
          ban_duration: "876000h",
          app_metadata: {
            petty_cash_role: target!.role,
            petty_cash_active: false,
            petty_cash_office_id: target!.office_id,
          },
        });
        if (banError) return reply({ error: banError.message }, 400);
        const { error: purgeError } = await db.rpc("delete_user_financial_data", {
          p_uid: uid,
        });
        if (purgeError) return reply({ error: `Account disabled. Delete incomplete: ${purgeError.message}. Retry deletion.` }, 500);
        try {
          await removeQueuedReceipts(db, uid);
          await removeUserReceipts(db, uid);
        } catch (storageError) {
          console.error("Receipt cleanup failed:", storageError);
          return reply({ error: "Account disabled. Receipt cleanup is incomplete; retry deletion." }, 500);
        }
        const { error: deleteError } = await db.auth.admin.deleteUser(uid);
        if (deleteError) return reply({ error: `Account disabled. Retry deletion: ${deleteError.message}` }, 500);
        return reply({ ok: true });
      }
      const name = String(body.name ?? "").trim(),
        email = String(body.email ?? "").trim().toLowerCase();
      const role = String(body.role ?? ""),
        password = body.password == null ? null : String(body.password);
      const officeId = body.officeId == null ? null : String(body.officeId);
      const nextActive = body.isActive === undefined
        ? (action === "create" ? true : target!.isActive === true)
        : body.isActive;
      const assignedOfficeId = officeId ??
        (action === "create" ? String(actor.office_id) : String(target?.office_id));
      if (
        action === "update" && assignedOfficeId !== target?.office_id &&
        actor.role !== "super_admin"
      ) {
        return reply({ error: "Only a super-admin can change an account's office" }, 403);
      }
      if (actor.role === "admin" && assignedOfficeId !== actor.office_id) {
        return reply({ error: "Admins can only manage accounts in their office" }, 403);
      }
      if (officeId !== null) {
        if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(officeId)) {
          return reply({ error: "Select a valid office" }, 400);
        }
        const { data: office, error: officeError } = await db.from("offices")
          .select("id").eq("id", officeId).single();
        if (officeError || !office) return reply({ error: "Office not found" }, 400);
      }
      if (
        !name || name.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
      ) return reply({ error: "Enter a valid name and email" }, 400);
      if (
        !["office_boy", "finance", "admin", "super_admin", "manager"].includes(role) ||
        (actor.role === "admin" && !["office_boy", "finance"].includes(role))
      ) return reply({ error: "Role is not allowed" }, 403);
      if (
        uid === actor.uid && (role !== actor.role || nextActive === false)
      ) {
        return reply(
          { error: "Ask another super-admin to change your access" },
          400,
        );
      }
      if (
        (action === "create" || password) &&
        (!password || password.length < 6 || password.length > 8)
      ) return reply({ error: "Use a password with 6 to 8 characters" }, 400);
      const attributes: Record<string, unknown> = {
        user_metadata: { name },
        app_metadata: {
          petty_cash_role: role,
          petty_cash_active: nextActive,
          petty_cash_office_id: assignedOfficeId,
        },
      };
      if (password) {
        attributes.password = password;
      }
      if (action === "create") {
        attributes.email = email;
      } else if (email && target && email !== String(target.email).toLowerCase()) {
        attributes.email = email;
      }
      if (action === "create") {
        const result = await db.auth.admin.createUser({
          ...attributes,
          email_confirm: true,
        });
        if (result.error) return reply({ error: result.error.message }, 400);
        return reply({ ok: true, uid: result.data.user?.id });
      }

      if (action === "update") {
        // sync_auth_profile updates public.users in the same Auth transaction.
        // Never report success after a failed or skipped Auth update.
        const authUpdate: Record<string, unknown> = {
          user_metadata: { name },
          app_metadata: {
            petty_cash_role: role,
            petty_cash_active: nextActive,
            petty_cash_office_id: assignedOfficeId,
          },
        };
        if (password) authUpdate.password = password;
        if (email !== String(target!.email).toLowerCase()) authUpdate.email = email;
        if (nextActive !== target!.isActive) {
          authUpdate.ban_duration = nextActive === false ? "876000h" : "none";
        }
        const { error: authUpdateError } = await db.auth.admin.updateUserById(uid, authUpdate);
        if (authUpdateError) return reply({ error: authUpdateError.message }, 400);
        const { data: saved, error: profileError } = await db.from("users")
          .select("name,email,role,isActive,office_id").eq("uid", uid).single();
        if (profileError || !saved || saved.name !== name || saved.email !== email ||
          saved.role !== role || saved.isActive !== nextActive ||
          saved.office_id !== assignedOfficeId) {
          return reply({ error: "Account update could not be verified. Please retry." }, 500);
        }
        return reply({ ok: true, uid });
      }

      return reply({ error: "Invalid action" }, 400);
    } catch (error) {
      console.error(
        "manage-user request failed",
        error instanceof Error ? error.name : "unknown",
      );
      return reply({
        error: "The account could not be updated. Please try again.",
      }, 500);
    }
  };
