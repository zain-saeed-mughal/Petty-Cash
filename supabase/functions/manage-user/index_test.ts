import { createHandler } from "./handler.ts";

function fixture(
  role = "super_admin",
  rpcError: unknown = null,
  receiptError: unknown = null,
  targetRole = "office_boy",
  authUpdateError: unknown = null,
  authDeleteError: unknown = null,
  profileSync = true,
  targetActive = true,
) {
  const writes: unknown[] = [];
  const rpcCalls: unknown[] = [];
  const storageCalls: unknown[] = [];
  const officeId = "00000000-0000-0000-0000-000000000001";
  const target = {
    uid: "staff", name: "Test User", email: "user@example.test",
    role: targetRole, isActive: targetActive, office_id: officeId,
  };
  const client = {
    auth: {
      getUser: () =>
        Promise.resolve({ data: { user: { id: "actor" } }, error: null }),
      admin: {
        createUser: (body: unknown) => {
          writes.push(body);
          return Promise.resolve({
            data: { user: { id: "new" } },
            error: null,
          });
        },
        updateUserById: (id: string, body: unknown) => {
          writes.push({ id, body });
          if (authUpdateError) return Promise.resolve({ data: null, error: authUpdateError });
          if (id === "staff" && profileSync) {
            const update = body as Record<string, unknown>;
            const meta = update.app_metadata as Record<string, unknown>;
            if (update.email) target.email = String(update.email);
            if (update.user_metadata) target.name = String((update.user_metadata as Record<string, unknown>).name);
            if (meta) {
              target.role = String(meta.petty_cash_role);
              target.isActive = meta.petty_cash_active !== false;
              target.office_id = String(meta.petty_cash_office_id);
            }
          }
          return Promise.resolve({ data: { user: { id } }, error: null });
        },
        deleteUser: (id: string) => {
          writes.push({ deleteUser: id });
          return Promise.resolve({ data: { user: null }, error: authDeleteError });
        },
      },
    },
    rpc: (name: string, args: unknown) => {
      rpcCalls.push({ name, args });
      return Promise.resolve({ error: rpcError });
    },
    storage: {
      from: (bucket: string) => ({
        list: (path: string, options: unknown) => {
          storageCalls.push({ list: bucket, path, options });
          return Promise.resolve({
            data: [{ name: "receipt.jpg", id: "object" }],
            error: null,
          });
        },
        remove: (paths: string[]) => {
          storageCalls.push({ remove: bucket, paths });
          return Promise.resolve({ data: [], error: receiptError });
        },
      }),
    },
    from: () => ({
      select: () => ({
        eq: (_key: string, id: string) => ({
          single: () =>
            Promise.resolve({
              data: id === "actor" ? {
                uid: id, role, isActive: true, office_id: officeId,
              } : target,
              error: null,
            }),
        }),
      }),
    }),
  };
  const handler = createHandler(client as never);
  const send = (body: unknown) =>
    handler(
      new Request("https://example.test/manage-user", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-token",
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      }),
    );
  return { send, writes, rpcCalls, storageCalls };
}
const account = {
  action: "create",
  name: "Test User",
  email: "user@example.test",
  role: "office_boy",
};
function equal(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}

Deno.test("Super-admin creates accounts with 6 to 8 character passwords", async () => {
  const f = fixture();
  for (const password of ["abc123", "abcd1234"]) {
    equal((await f.send({ ...account, password })).status, 200);
  }
  equal(f.writes.length, 2);
});
Deno.test("Server rejects missing, short and overlong passwords", async () => {
  const f = fixture();
  for (const password of [undefined, "12345", "123456789", "A".repeat(129)]) {
    equal((await f.send({ ...account, password })).status, 400);
  }
  equal(f.writes.length, 0);
});
Deno.test("Editing an account retains the password when blank, or accepts a 6 to 8 character replacement", async () => {
  const f = fixture();
  equal(
    (await f.send({
      ...account,
      action: "update",
      uid: "staff",
      password: null,
    })).status,
    200,
  );
  equal(
    (await f.send({
      ...account,
      action: "update",
      uid: "staff",
      password: "abcd1234",
    })).status,
    200,
  );
  const first = f.writes[0] as { body: { password?: string } };
  equal(first.body.password, undefined);
  equal((first.body as { email?: string }).email, undefined);
});
Deno.test("Staff cannot create users and admin cannot grant super-admin", async () => {
  const staff = fixture("office_boy"), admin = fixture("admin");
  equal((await staff.send({ ...account, password: "abcd1234" })).status, 403);
  equal(
    (await admin.send({
      ...account,
      role: "super_admin",
      password: "abcd1234",
    })).status,
    403,
  );
  equal(staff.writes.length + admin.writes.length, 0);
});
Deno.test("Super-admin deletes Office Boy data, receipts, then the auth account", async () => {
  const f = fixture();
  equal((await f.send({ action: "delete", uid: "staff" })).status, 200);
  equal(f.rpcCalls.length, 1);
  equal((f.rpcCalls[0] as { name: string }).name, "delete_office_boy_data");
  equal(f.storageCalls.length, 2);
  equal((f.writes[1] as { deleteUser: string }).deleteUser, "staff");
});
Deno.test("Admin cannot permanently delete an Office Boy account", async () => {
  const f = fixture("admin");
  equal((await f.send({ action: "delete", uid: "staff" })).status, 403);
  equal(f.rpcCalls.length, 0);
  equal(f.writes.length, 0);
});
Deno.test("Super-admin cannot use Office Boy purge for another role", async () => {
  const f = fixture("super_admin", null, null, "finance");
  equal((await f.send({ action: "delete", uid: "staff" })).status, 400);
  equal(f.rpcCalls.length, 0);
  equal(f.writes.length, 0);
});
Deno.test("Failed database cleanup leaves the account disabled and Auth intact", async () => {
  const f = fixture("super_admin", new Error("cleanup failed"));
  equal((await f.send({ action: "delete", uid: "staff" })).status, 500);
  equal(f.storageCalls.length, 0);
  equal(f.writes.length, 1);
});
Deno.test("Failed receipt cleanup never deletes the auth account", async () => {
  const f = fixture("super_admin", null, new Error("storage failed"));
  equal((await f.send({ action: "delete", uid: "staff" })).status, 500);
  equal(f.storageCalls.length, 2);
  equal(f.rpcCalls.length, 1);
  equal(f.writes.length, 1);
});

Deno.test("Auth update errors never report account-edit success", async () => {
  const f = fixture("super_admin", null, null, "office_boy", new Error("Auth failed"));
  equal((await f.send({ ...account, action: "update", uid: "staff", password: null })).status, 400);
});

Deno.test("Missing profile sync never reports account-edit success", async () => {
  const f = fixture("super_admin", null, null, "office_boy", null, null, false);
  equal((await f.send({ ...account, name: "Changed Name", action: "update", uid: "staff", password: null })).status, 500);
});

Deno.test("Editing an inactive account without an active flag does not reactivate it", async () => {
  const f = fixture("super_admin", null, null, "office_boy", null, null, true, false);
  equal((await f.send({ ...account, action: "update", uid: "staff", password: null })).status, 200);
  const update = (f.writes[0] as { body: { app_metadata: { petty_cash_active: boolean }, ban_duration?: string } }).body;
  equal(update.app_metadata.petty_cash_active, false);
  equal(update.ban_duration, undefined);
});

Deno.test("A failed Auth deletion leaves a disabled account that can be retried", async () => {
  const f = fixture("super_admin", null, null, "office_boy", null, new Error("Auth delete failed"));
  equal((await f.send({ action: "delete", uid: "staff" })).status, 500);
  equal(f.rpcCalls.length, 1);
  equal((f.writes[0] as { body: { ban_duration: string } }).body.ban_duration, "876000h");
});
