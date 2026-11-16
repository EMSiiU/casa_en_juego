const { PGlite } = require("@electric-sql/pglite");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const admin = "00000000-0000-0000-0000-000000000001";
const member = "00000000-0000-0000-0000-000000000002";
const personal = "00000000-0000-0000-0000-000000000003";
const pending = "00000000-0000-0000-0000-000000000004";
const secondCreator = "00000000-0000-0000-0000-000000000005";
const newCreator = "00000000-0000-0000-0000-000000000006";

const load = (name) =>
  fs.readFileSync(path.join(__dirname, "..", name), "utf8").replace(/^\uFEFF/, "");

async function main() {
  const db = new PGlite();
  try {
    await db.exec(`
      create role authenticated;
      create role anon;
      create role service_role bypassrls;
      create schema auth;
      create table auth.users (
        id uuid primary key,
        email text,
        email_confirmed_at timestamptz,
        raw_user_meta_data jsonb,
        raw_app_meta_data jsonb
      );
      create function auth.uid() returns uuid language sql stable as
        'select nullif(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
      grant usage on schema auth to authenticated;
      grant execute on function auth.uid() to authenticated;
      create schema storage;
      create table storage.buckets (
        id text primary key, name text not null, public boolean,
        file_size_limit bigint, allowed_mime_types text[]
      );
      create table storage.objects (
        bucket_id text references storage.buckets(id),
        name text,
        primary key (bucket_id, name)
      );
      alter table storage.objects enable row level security;
      grant usage on schema storage to authenticated, anon;
      grant select, insert, update, delete on storage.objects to authenticated, anon;
      insert into auth.users values
        ('${admin}', 'carlos@familia.es', now(), null, '{"provider":"email"}'),
        ('${member}', 'ana@familia.es', now(), '{"provider":"email"}', '{"provider":"google"}'),
        ('${personal}', 'elena@example.com', now(), '{"name":"Elena","role":"admin"}', '{"provider":"email","providers":["email","google"]}'),
        ('${pending}', 'pat@example.com', null, null, '{"provider":"email"}'),
        ('${secondCreator}', 'toni@example.com', now(), null, '{"provider":"github"}'),
        ('${newCreator}', 'sam@example.com', now(), null, null);
    `);
    await db.exec(load("phase_2.sql"));
    for (const name of ["points_snapshot", "daily_task_limits", "push_notifications", "inactivity_reminders"]) {
      await db.exec(load(`migrations/20261022_add_${name}.sql`));
    }
    await db.exec(load("migrations/20261114000100_add_personal_accounts.sql"));
    await db.exec(load("migrations/20261114000200_rename_personal_profile.sql"));
    await db.exec(load("migrations/20261114000300_add_account_avatars.sql"));

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

    await db.exec("reset role");
    assert.deepEqual(await rows("select public, file_size_limit, allowed_mime_types from storage.buckets"), [
      { public: false, file_size_limit: 2097152, allowed_mime_types: ["image/jpeg", "image/png", "image/webp"] },
    ]);
    const avatarRow = (id) => `('account-avatars', '${id}/avatar')`;
    await asUser(personal);
    await db.exec(`insert into storage.objects values ${avatarRow(personal)}`);
    assert.equal((await rows(`update storage.objects set name = name returning name`)).length, 1);
    await assert.rejects(
      () => db.exec(`update storage.objects set name = '${personal}/second'`),
      /row-level security/,
    );
    await asUser(member);
    assert.deepEqual(await rows("select name from storage.objects"), []);
    assert.deepEqual(await rows("delete from storage.objects returning name"), []);
    await assert.rejects(
      () => db.exec(`insert into storage.objects values ${avatarRow(personal)}`),
      /row-level security/,
    );
    await db.exec("set role anon");
    assert.deepEqual(await rows("select name from storage.objects"), []);
    await asUser(personal);
    assert.deepEqual(await rows("delete from storage.objects returning name"), [
      { name: `${personal}/avatar` },
    ]);
    console.log("PASS: private avatar bucket and owner-only Storage policies");

    await asUser(member);
    const [legacySeason] = await rows("select id, start_date from public.seasons");
    const [legacyTask] = await rows("select id from public.tasks where points = 5");
    const [legacyLog] = await rows(`insert into public.task_logs(user_id, task_id, season_id)
      values ('${member}', '${legacyTask.id}', '${legacySeason.id}') returning id`);
    await db.exec("reset role");
    await db.exec(load("migrations/20261115000100_add_cycle_creation.sql"));
    await db.exec(load("migrations/20261115000200_add_cycle_planned_end_date.sql"));
    await asUser(member);
    assert.deepEqual(await rows("select id, start_date from public.seasons"), [legacySeason]);
    assert.deepEqual(await rows("select id from public.task_logs"), [legacyLog]);
    assert.equal((await rows("select id from public.tasks")).length, 3);
    await assert.rejects(
      () => db.exec("select public.create_first_cycle('No válido', 15)"), /CYCLE_MEMBERSHIP_EXISTS/,
    );
    await asUser(pending);
    await assert.rejects(
      () => db.exec("select public.create_first_cycle('No válido', 15)"), /CYCLE_PROFILE_UNAVAILABLE/,
    );
    await db.exec("set role anon");
    await assert.rejects(
      () => db.exec("select public.create_first_cycle('No válido', 15)"), /permission denied/,
    );

    await asUser(personal);
    await assert.rejects(
      () => db.exec("select public.create_first_cycle('Con días no válidos', 0)"), /CYCLE_DETAILS_INVALID/,
    );
    assert.deepEqual(await rows("select id from public.seasons"), []);
    const [{ id: personalSeason }] = await rows("select public.create_first_cycle('  Mi ciclo  ', 21) as id");
    assert.deepEqual(await rows("select id, name, planned_duration_days, planned_end_date from public.seasons"), [
      { id: personalSeason, name: "Mi ciclo", planned_duration_days: 21, planned_end_date: null },
    ]);
    assert.deepEqual(await rows("select id, role from public.users"), [{ id: personal, role: "admin" }]);
    assert.deepEqual(await rows("select id from public.tasks"), []);
    assert.deepEqual(await rows("select id from public.task_logs"), []);
    await assert.rejects(
      () => db.exec("select public.create_first_cycle('Segundo grupo', 21)"), /CYCLE_MEMBERSHIP_EXISTS/,
    );
    await assert.rejects(
      () => db.exec("insert into public.seasons(name) values ('Segundo ciclo simultáneo')"), /seasons_one_active_per_group/,
    );
    assert.deepEqual(await rows(`update public.seasons set status = 'closed'
      where id = '${legacySeason.id}' returning id`), []);
    assert.deepEqual(await rows(`update public.tasks set points = 100 where id = '${legacyTask.id}' returning id`), []);
    assert.deepEqual(await rows(`update public.task_logs set status = 'approved' where id = '${legacyLog.id}' returning id`), []);
    const [{ id: personalTask }] = await rows(`insert into public.tasks(name, points, icon_name)
      values ('Mi tarea', 4, 'broom') returning id`);
    await assert.rejects(
      () => db.exec(`insert into public.task_logs(user_id, task_id, season_id)
        values ('${personal}', '${legacyTask.id}', '${personalSeason}')`), /TASK_OUTSIDE_CYCLE_GROUP/,
    );
    await assert.rejects(
      () => db.exec(`insert into public.task_logs(user_id, task_id, season_id)
        values ('${personal}', '${personalTask}', '${legacySeason.id}')`), /TASK_OUTSIDE_CYCLE_GROUP/,
    );
    await db.exec("update public.users set notifications_enabled = true");
    await db.exec("select public.register_push_device('test-device-personal', 'android')");
    await asUser(secondCreator);
    await db.exec("select public.ensure_personal_profile()");
    assert.deepEqual(await rows("select id from public.seasons"), []);
    await assert.rejects(
      () => db.exec(`select public.create_first_cycle('Fecha vencida',
        (statement_timestamp() at time zone 'America/Mexico_City')::date)`),
      /CYCLE_END_DATE_INVALID/,
    );
    await assert.rejects(
      () => db.exec("select public.create_first_cycle('Fecha infinita', 'infinity'::date)"),
      /CYCLE_END_DATE_INVALID/,
    );
    assert.deepEqual(await rows("select role, is_household_member from public.users"), [
      { role: "sibling", is_household_member: false },
    ]);
    const [{ id: secondSeason }] = await rows(`select public.create_first_cycle('Otro ciclo',
      (statement_timestamp() at time zone 'America/Mexico_City')::date + 7) as id`);
    assert.deepEqual(await rows("select id from public.seasons"), [{ id: secondSeason }]);
    const [datePlan] = await rows(`select planned_end_date, planned_duration_days, end_date,
      planned_end_date - (start_date at time zone 'America/Mexico_City')::date as calendar_days
      from public.seasons`);
    assert.equal(datePlan.calendar_days, 7);
    assert.equal(datePlan.planned_duration_days, 7);
    assert.equal(datePlan.end_date, null);

    await asUser(admin);
    await db.exec(`insert into public.tasks(name, points, icon_name, is_active, is_daily_limited)
      values ('Tarea inicial cuatro', 6, 'broom', true, true),
             ('Tarea inicial cinco', 7, 'utensils', false, false)`);
    const catalog = () => rows(`select name, points, icon_name, is_active, is_daily_limited
      from public.tasks order by name`);
    const originalCatalog = await catalog();
    assert.equal(originalCatalog.length, 5);
    await db.exec("reset role");
    await db.exec(load("migrations/20261115000300_add_next_cycle_and_default_tasks.sql"));
    await asUser(secondCreator);
    assert.deepEqual(await catalog(), originalCatalog);
    await asUser(personal);
    assert.deepEqual(await rows("select name from public.tasks"), [{ name: "Mi tarea" }]);
    await asUser(admin);
    await db.exec("update public.tasks set points = 12 where name = 'Tarea inicial cuatro'");
    await asUser(newCreator);
    await db.exec("select public.ensure_personal_profile()");
    await db.exec("select public.create_first_cycle('Otro grupo', 10)");
    assert.deepEqual(await catalog(), originalCatalog);

    await asUser(admin);
    await db.exec("select public.register_push_device('test-device-legacy', 'android')");
    assert.deepEqual(await rows("select id, start_date from public.seasons"), [legacySeason]);
    assert.deepEqual(await rows(`update public.seasons set status = 'closed'
      where id = '${personalSeason}' returning id`), []);
    assert.deepEqual(await rows(`update public.task_logs set status = 'approved'
      where id = '${legacyLog.id}' returning approved_by, points_snapshot`), [
      { approved_by: admin, points_snapshot: 5 },
    ]);
    await asUser(member);
    await db.exec(`insert into public.task_logs(user_id, task_id, season_id)
      values ('${member}', '${legacyTask.id}', '${legacySeason.id}')`);
    await asUser(personal);
    await db.exec(`insert into public.task_logs(user_id, task_id, season_id)
      values ('${personal}', '${personalTask}', '${personalSeason}')`);
    await db.exec("reset role");
    assert.deepEqual(await rows("select recipient_id from public.push_jobs where kind = 'submitted'"), [
      { recipient_id: admin },
    ]);
    await db.exec("select private.enqueue_inactivity_reminders('2099-10-23T00:00:00Z')");
    assert.deepEqual(await rows(`select recipient_id, reminder_season_id from public.push_jobs
      where kind = 'reminder' order by recipient_id`), [
      { recipient_id: admin, reminder_season_id: legacySeason.id },
      { recipient_id: personal, reminder_season_id: personalSeason },
    ]);
    await asUser(personal);
    assert.deepEqual(await rows(`update public.seasons set status = 'closed'
      where id = '${personalSeason}' returning id`), [{ id: personalSeason }]);
    await assert.rejects(
      () => db.exec("select public.create_first_cycle('Sin salir del grupo', 21)"), /CYCLE_MEMBERSHIP_EXISTS/,
    );
    assert.equal((await rows("select id from public.task_logs")).length, 1);
    await asUser(secondCreator);
    const [closed] = await rows(`update public.seasons set status = 'closed' where id = '${secondSeason}'
      returning planned_end_date, planned_duration_days, end_date`);
    assert.deepEqual(closed.planned_end_date, datePlan.planned_end_date);
    assert.equal(closed.planned_duration_days, 7);
    assert.notEqual(closed.end_date, null);
    await db.exec("update public.tasks set is_active = false, points = 11 where name = 'Tarea inicial cuatro'");
    const modifiedCatalog = await catalog();
    const plannedEnd = "(statement_timestamp() at time zone 'America/Mexico_City')::date";
    await assert.rejects(
      () => db.exec(`insert into public.seasons(name, planned_end_date) values ('Fecha vencida', ${plannedEnd})`),
      /CYCLE_END_DATE_INVALID/,
    );
    assert.deepEqual(await rows(`insert into public.seasons(name, planned_end_date)
      values ('Siguiente ciclo', ${plannedEnd} + 10) returning planned_duration_days`), [
      { planned_duration_days: 10 },
    ]);
    assert.deepEqual(await catalog(), modifiedCatalog);
    await asUser(member);
    await assert.rejects(
      () => db.exec(`insert into public.seasons(name, planned_end_date) values ('Ciclo no autorizado', ${plannedEnd} + 10)`),
      /row-level security/,
    );
    console.log("PASS: cycle creation, scoped administrators and notifications, and unchanged legacy data");
    console.log("PASS: default catalog copied once and next cycle keeps the edited catalog");

    await db.exec("reset role");
    await db.exec(load("migrations/20261115000400_add_independent_cycles.sql"));
    await asUser(personal);
    assert.deepEqual(await rows("select role, cycle_group_id from public.users"), [
      { role: "sibling", cycle_group_id: null },
    ]);
    assert.deepEqual(await rows("select id, status from public.seasons"), [
      { id: personalSeason, status: "closed" },
    ]);
    assert.deepEqual(await rows("select task_name_snapshot, requester_name_snapshot from public.task_logs"), [
      { task_name_snapshot: "Mi tarea", requester_name_snapshot: "Elena Marín" },
    ]);
    assert.deepEqual(await rows("select id from public.tasks"), []);
    assert.deepEqual(await rows(`select name from public.get_closed_cycle_catalog('${personalSeason}')`), [
      { name: "Mi tarea" },
    ]);
    const [{ id: freshCycle }] = await rows("select public.create_first_cycle('Ciclo independiente', 10) as id");
    assert.deepEqual(await catalog(), originalCatalog);
    assert.deepEqual(await rows("select id from public.seasons where status = 'active'"), [{ id: freshCycle }]);
    assert.deepEqual(await rows(`select id from public.task_logs where season_id = '${freshCycle}'`), []);
    await assert.rejects(
      () => db.exec("select public.create_first_cycle('Ciclo simultáneo', 10)"),
      /CYCLE_MEMBERSHIP_EXISTS/,
    );
    await assert.rejects(
      () => db.exec("insert into public.seasons(name) values ('Reutilizar catálogo')"),
      /permission denied/,
    );
    await asUser(newCreator);
    assert.deepEqual(await rows(`select id from public.seasons where id = '${personalSeason}'`), []);
    assert.deepEqual(await rows(`select id from public.task_logs where season_id = '${personalSeason}'`), []);
    assert.deepEqual(await rows(`select id from public.get_closed_cycle_catalog('${personalSeason}')`), []);

    await asUser(member);
    const [archivedLog] = await rows(`insert into public.task_logs(user_id, task_id, season_id)
      values ('${member}', '${legacyTask.id}', '${legacySeason.id}') returning id`);
    await asUser(admin);
    await db.exec(`update public.tasks set name = 'Nombre editado' where id = '${legacyTask.id}'`);
    assert.deepEqual(await rows(`update public.task_logs set status = 'approved'
      where id = '${archivedLog.id}' returning task_name_snapshot, reviewer_name_snapshot, points_snapshot`), [
        { task_name_snapshot: "Lavar los platos", reviewer_name_snapshot: "Carlos", points_snapshot: 5 },
    ]);
    assert.deepEqual(await rows(`update public.seasons set status = 'closed'
      where id = '${legacySeason.id}' returning id`), [ { id: legacySeason.id } ]);
    await asUser(member);
    assert.deepEqual(await rows("select role, is_household_member, cycle_group_id from public.users"), [
      { role: "sibling", is_household_member: false, cycle_group_id: null },
    ]);
    assert.deepEqual(await rows(`select id, status from public.seasons where id = '${legacySeason.id}'`), [
      { id: legacySeason.id, status: "closed" },
    ]);
    assert.deepEqual(await rows(`select status, task_name_snapshot, points_snapshot
      from public.task_logs where id = '${archivedLog.id}'`), [
        { status: "approved", task_name_snapshot: "Lavar los platos", points_snapshot: 5 },
    ]);
    assert.deepEqual(await rows(`select name from public.get_closed_cycle_catalog('${legacySeason.id}')
      where id = '${legacyTask.id}'`), [{ name: "Nombre editado" }]);
    await asUser(admin);
    assert.deepEqual(await rows(`update public.tasks set points = 99 where id = '${legacyTask.id}' returning id`), []);
    assert.deepEqual(await rows(`update public.task_logs set status = 'approved'
      where season_id = '${legacySeason.id}' returning id`), []);
    assert.deepEqual(await rows("select role, cycle_group_id from public.users"), [
      { role: "sibling", cycle_group_id: null },
    ]);
    await db.exec("reset role");
    assert.equal((await rows(`select id from public.tasks where id = '${legacyTask.id}'`)).length, 1);
    console.log("PASS: independent cycles archive catalog and results, release all members, and preserve access for participants");

    await db.exec(load("migrations/20261115000500_add_cycle_invites.sql"));
    await asUser(member);
    await assert.rejects(
      () => db.exec("select public.join_cycle_by_code('000000000000')"),
      /CYCLE_INVITE_INVALID/,
    );
    await assert.rejects(
      () => db.exec("select code from private.cycle_invites"),
      /permission denied/,
    );
    await asUser(personal);
    const [{ code }] = await rows(`select public.get_or_create_cycle_invite('${freshCycle}') as code`);
    assert.match(code, /^[0-9A-F]{12}$/);
    assert.deepEqual(await rows(`select public.get_or_create_cycle_invite('${freshCycle}') as code`), [{ code }]);
    await asUser(newCreator);
    await assert.rejects(
      () => db.exec(`select public.get_or_create_cycle_invite('${freshCycle}')`),
      /CYCLE_INVITE_ADMIN_REQUIRED/,
    );
    await assert.rejects(
      () => db.exec(`select public.join_cycle_by_code('${code}')`),
      /CYCLE_MEMBERSHIP_EXISTS/,
    );
    await asUser(pending);
    await assert.rejects(
      () => db.exec(`select public.join_cycle_by_code('${code}')`),
      /CYCLE_PROFILE_UNAVAILABLE/,
    );
    await db.exec("set role anon");
    await assert.rejects(
      () => db.exec(`select public.join_cycle_by_code('${code}')`),
      /permission denied/,
    );
    await asUser(member);
    const formattedCode = code.toLowerCase().match(/.{4}/g).join(" - ");
    assert.deepEqual(await rows(`select public.join_cycle_by_code(' ${formattedCode} ') as id`), [
      { id: freshCycle },
    ]);
    assert.deepEqual(await rows(`select public.join_cycle_by_code('${code}') as id`), [{ id: freshCycle }]);
    assert.deepEqual(await rows("select role, is_household_member from public.users where id = auth.uid()"), [
      { role: "sibling", is_household_member: true },
    ]);
    assert.deepEqual(await catalog(), originalCatalog);
    await assert.rejects(
      () => db.exec(`select public.get_or_create_cycle_invite('${freshCycle}')`),
      /CYCLE_INVITE_ADMIN_REQUIRED/,
    );
    await asUser(personal);
    await db.exec(`update public.seasons set status = 'closed' where id = '${freshCycle}'`);
    await asUser(member);
    assert.deepEqual(await rows(`select id, status from public.seasons where id = '${freshCycle}'`), [
      { id: freshCycle, status: "closed" },
    ]);
    assert.deepEqual(await rows("select cycle_group_id from public.users"), [{ cycle_group_id: null }]);
    await assert.rejects(
      () => db.exec(`select public.join_cycle_by_code('${code}')`),
      /CYCLE_INVITE_INVALID/,
    );
    console.log("PASS: active invitation, one membership, member role and closed-cycle history");

    await db.exec("reset role");
    // Una foto OAuth antigua sigue almacenada y queda fuera del acceso del cliente.
    await db.exec(`insert into storage.objects values ${avatarRow(member)}`);
    await db.exec(load("migrations/20261116000100_restrict_account_avatar_edits.sql"));
    await asUser(personal);
    await db.exec(`insert into storage.objects values ${avatarRow(personal)} on conflict (bucket_id, name) do update set name = excluded.name`);
    await db.exec(`insert into storage.objects values ${avatarRow(personal)} on conflict (bucket_id, name) do update set name = excluded.name`);
    assert.deepEqual(await rows("delete from storage.objects returning name"), [
      { name: `${personal}/avatar` },
    ]);
    for (const id of [member, secondCreator, pending, newCreator]) {
      await asUser(id);
      assert.deepEqual(await rows("select name from storage.objects"), []);
      assert.deepEqual(await rows("update storage.objects set name = name returning name"), []);
      assert.deepEqual(await rows("delete from storage.objects returning name"), []);
      await assert.rejects(
        () => db.exec(`insert into storage.objects values ${avatarRow(id)}`),
        /row-level security/,
      );
    }
    console.log("PASS: confirmed email origin may write avatars, including linked OAuth; other origins cannot");
  } finally {
    await db.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
