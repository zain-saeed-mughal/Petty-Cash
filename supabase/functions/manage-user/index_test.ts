import { createHandler } from "./handler.ts";

function fixture(
  role = "super_admin",
  rpcError: unknown = null,
  receiptError: unknown = null,
  targetRole = "office_boy",
) {
  const writes: unknown[] = [];
  const rpcCalls: unknown[] = [];
  const storageCalls: unknown[] = [];
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
          return Promise.resolve({ data: { user: { id } }, error: null });
        },
        deleteUser: (id: string) => {
          writes.push({ deleteUser: id });
          return Promise.resolve({ data: { user: null }, error: null });
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
              data: {
                uid: id,
                role: id === "actor" ? role : targetRole,
                isActive: true,
              },
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

Deno.test("Super-admin creates accounts with 6 and 8 character passwords", async () => {
  const f = fixture();
  for (const password of ["abc123", "abcd1234"]) {
    equal((await f.send({ ...account, password })).status, 200);
  }
  equal(f.writes.length, 2);
});
Deno.test("Server rejects missing, short and over-eight-character passwords", async () => {
  const f = fixture();
  for (const password of [undefined, "12345", "123456789", "123456789012"]) {
    equal((await f.send({ ...account, password })).status, 400);
  }
  equal(f.writes.length, 0);
});
Deno.test("Editing an account retains the password when blank, or accepts an eight-character replacement", async () => {
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
  equal((f.writes[0] as { deleteUser: string }).deleteUser, "staff");
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
Deno.test("Failed database cleanup never deletes receipts or the auth account", async () => {
  const f = fixture("super_admin", new Error("cleanup failed"));
  equal((await f.send({ action: "delete", uid: "staff" })).status, 500);
  equal(f.storageCalls.length, 0);
  equal(f.writes.length, 0);
});
Deno.test("Failed receipt cleanup never deletes the auth account", async () => {
  const f = fixture("super_admin", null, new Error("storage failed"));
  equal((await f.send({ action: "delete", uid: "staff" })).status, 500);
  equal(f.storageCalls.length, 2);
  equal(f.writes.length, 0);
});
