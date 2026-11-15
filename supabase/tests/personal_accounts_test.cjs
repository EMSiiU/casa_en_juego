const { PGlite } = require("@electric-sql/pglite");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const admin = "00000000-0000-0000-0000-000000000001";
const member = "00000000-0000-0000-0000-000000000002";
const personal = "00000000-0000-0000-0000-000000000003";
const pending = "00000000-0000-0000-0000-000000000004";

const load = (name) =>
  fs.readFileSync(path.join(__dirname, "..", name), "utf8").replace(/^\uFEFF/, "");

async function main() {
  const db = new PGlite();
  try {
    await db.exec(`
      create role authenticated;
      create role anon;
      create schema auth;
      create table auth.users (
        id uuid primary key,
        email text,
        email_confirmed_at timestamptz,
        raw_user_meta_data jsonb
      );
      create function auth.uid() returns uuid language sql stable as
        'select nullif(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
      grant usage on schema auth to authenticated;
      grant execute on function auth.uid() to authenticated;
      insert into auth.users values
        ('${admin}', 'carlos@familia.es', now(), null),
        ('${member}', 'ana@familia.es', now(), null),
        ('${personal}', 'elena@example.com', now(), '{"name":"Elena","role":"admin"}'),
        ('${pending}', 'pat@example.com', null, null);
    `);
    await db.exec(load("phase_2.sql"));
    await db.exec(load("migrations/20261114000100_add_personal_accounts.sql"));
    await db.exec(load("migrations/20261114000200_rename_personal_profile.sql"));

    const asUser = async (id) => {
      await db.exec("set role authenticated");
      await db.query("select set_config('request.jwt.claim.sub', $1, false)", [id]);
    };
    const rows = async (sql) => (await db.query(sql)).rows;

    await asUser(personal);
    await db.exec("select public.ensure_personal_profile()");
    await db.exec("select public.ensure_personal_profile()");
    assert.deepEqual(await rows("select name, role, is_household_member from public.users"), [
      { name: "Elena", role: "sibling", is_household_member: false },
    ]);
    assert.deepEqual(await rows("select id from public.tasks"), []);
    assert.deepEqual(await rows("select public.rename_my_profile('  Elena Marín  ') as name"), [
      { name: "Elena Marín" },
    ]);
    assert.deepEqual(await rows("select name from public.users"), [{ name: "Elena Marín" }]);
    await assert.rejects(
      () => db.exec("select public.rename_my_profile(repeat('x', 101))"),
      /PROFILE_NAME_INVALID/,
    );
    await assert.rejects(
      () => db.exec("select public.rename_my_profile(E'\\t  ')"),
      /PROFILE_NAME_INVALID/,
    );
    await assert.rejects(
      () => db.exec("update public.users set name = 'Otra persona'"),
      /permission denied/,
    );
    await assert.rejects(
      () => db.exec("insert into public.seasons (name) values ('Otro ciclo')"),
      /row-level security/,
    );
    await assert.rejects(
      () => db.exec("update public.users set is_household_member = true"),
      /permission denied/,
    );

    await asUser(pending);
    await assert.rejects(
      () => db.exec("select public.ensure_personal_profile()"),
      /ACCOUNT_EMAIL_UNVERIFIED/,
    );
    assert.deepEqual(await rows("select id from public.users"), []);
    await assert.rejects(
      () => db.exec("select public.rename_my_profile('Nombre válido')"),
      /ACCOUNT_EMAIL_UNVERIFIED/,
    );

    await asUser(member);
    assert.equal((await rows("select id from public.users")).length, 2);
    assert.equal((await rows("select id from public.tasks")).length, 3);
    assert.deepEqual(await rows("select name from public.users order by name"), [
      { name: "Ana" }, { name: "Carlos" },
    ]);
    await asUser(admin);
    await db.exec("insert into public.seasons (name) values ('Ciclo existente')");
    assert.equal((await rows("select id from public.seasons")).length, 1);
    console.log("PASS: verified profile creation and rename, membership isolation and legacy access");
  } finally {
    await db.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
