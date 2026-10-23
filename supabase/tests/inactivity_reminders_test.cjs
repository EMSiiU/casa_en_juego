const { PGlite } = require("@electric-sql/pglite");
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");

// PostgreSQL aislado: no lee credenciales ni se conecta al proyecto de Supabase.
async function main() {
  const db = new PGlite();
  try {
    const root = path.resolve(__dirname, "../..");
    const load = (name) =>
      fs.readFileSync(path.join(root, name), "utf8").replace(/^\uFEFF/, "");
    await db.exec(`
      create role authenticated; create role anon; create role service_role bypassrls;
      create schema auth; create table auth.users(id uuid primary key, email text);
      create function auth.uid() returns uuid language sql stable as
        'select nullif(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
      grant usage on schema auth to authenticated;
      grant execute on function auth.uid() to authenticated;
      insert into auth.users values
        ('00000000-0000-0000-0000-000000000001','carlos@familia.es'),
        ('00000000-0000-0000-0000-000000000002','ana@familia.es');
    `);
    for (
      const name of [
        "supabase/phase_2.sql",
        "supabase/migrations/20261022_add_points_snapshot.sql",
        "supabase/migrations/20261022_add_daily_task_limits.sql",
        "supabase/migrations/20261022_add_push_notifications.sql",
      ]
    ) await db.exec(load(name));
    const value = async (sql, params = []) =>
      Object.values((await db.query(sql, params)).rows[0])[0];
    const member = "00000000-0000-0000-0000-000000000002";
    const admin = "00000000-0000-0000-0000-000000000001";
    const season = await value(
      "insert into public.seasons(name) values ('Test season') returning id",
    );
    const task = await value("select id from public.tasks where points=5");
    await db.query(
      "update public.users set notifications_enabled=false where id=$1",
      [admin],
    );
    await db.query(
      "insert into public.push_devices(user_id, token, platform) values ($1,'test-device-001','android'), ($1,'test-device-002','ios')",
      [member],
    );
    const legacyLog = await value(
      "insert into public.task_logs(user_id,task_id,season_id) values ($1,$2,$3) returning id",
      [admin, task, season],
    );
    await db.exec(
      load("supabase/migrations/20261022_add_inactivity_reminders.sql"),
    );
    assert.equal(
      await value(
        "select count(*)::int from public.push_jobs where kind='submitted' and expires_at=created_at+interval '1 day'",
      ),
      2,
    );
    await db.exec(
      "delete from public.push_jobs; delete from public.task_logs; begin;",
    );

    const evening = "2099-10-23T00:00:00Z"; // 22 de octubre a las 18:00 en Ciudad de México.
    const lateEvening = "2099-10-23T02:00:00Z";
    const enqueue = (time) =>
      value("select private.enqueue_inactivity_reminders($1)", [time]);
    const jobs = async () =>
      (await db.query(
        "select * from public.push_jobs where kind='reminder' order by reminder_hour,id",
      )).rows;
    const claimedContext = async (time) => {
      const id = (await jobs())[0].id;
      const lease = await value(
        "update public.push_jobs set status='processing', lease_id=gen_random_uuid() where id=$1 returning lease_id",
        [id],
      );
      return {
        id,
        lease,
        read: (now = time) =>
          value("select private.push_reminder_context($1,$2,$3)", [
            id,
            lease,
            now,
          ]),
      };
    };
    const addLog = async (status, day = "2099-10-22", cycle = season) => {
      await db.exec(
        "alter table public.task_logs disable trigger task_logs_validate",
      );
      await db.query(
        `insert into public.task_logs(user_id,task_id,season_id,status,points_snapshot,
        requested_at,requested_day,approved_by,resolved_at)
        values ($1,$2,$3,$4,5,$5::date+time '12:00' at time zone 'America/Mexico_City',$5,
          case when $4='pending' then null else $6::uuid end,
          case when $4='pending' then null else $5::date+time '12:01' at time zone 'America/Mexico_City' end)`,
        [member, task, cycle, status, day, admin],
      );
      await db.exec(
        "alter table public.task_logs enable trigger task_logs_validate",
      );
    };
    let passed = 0;
    async function check(name, run) {
      await db.exec("savepoint test_case");
      try {
        await run();
        passed++;
        console.log(`PASS: ${name}`);
      } finally {
        await db.exec(
          "rollback to savepoint test_case; release savepoint test_case",
        );
      }
    }

    await check(
      "Mexico clock, local day and two distinct slots; repeated runs are idempotent",
      async () => {
        assert.equal(await enqueue("2099-10-22T23:59:00Z"), 0);
        assert.equal(await enqueue(evening), 2);
        assert.equal(await enqueue(evening), 0);
        assert.equal(await enqueue("2099-10-23T00:01:00Z"), 0);
        assert.equal(await enqueue(lateEvening), 2);
        assert.equal(await enqueue("2099-10-23T03:00:00Z"), 0);
        const rows = await jobs();
        assert.equal(rows.length, 4);
        assert.ok(
          rows.every((row) =>
            new Date(row.reminder_day).toISOString().startsWith("2099-10-22")
          ),
        );
        assert.deepEqual(rows.map((row) => row.reminder_hour), [
          18,
          18,
          20,
          20,
        ]);
        assert.ok(
          rows.every((row) =>
            new Date(row.expires_at) - new Date(row.available_at) === 1800000
          ),
        );
      },
    );
    for (const status of ["pending", "approved"]) {
      await check(
        `${status} task today suppresses both reminders`,
        async () => {
          await addLog(status);
          assert.equal(await enqueue(evening), 0);
          assert.equal(await enqueue(lateEvening), 0);
        },
      );
    }
    await check(
      "Rejected requests and previous-day tasks do not suppress reminders",
      async () => {
        await addLog("rejected");
        await addLog("approved", "2099-10-21");
        assert.equal(await enqueue(evening), 2);
      },
    );
    await check(
      "An activity between 18:00 and 20:00 cancels the second slot and queued first slot",
      async () => {
        await enqueue(evening);
        const delivery = await claimedContext(evening);
        assert.equal((await delivery.read()).reminderEligible, true);
        await addLog("pending");
        assert.equal((await delivery.read()).reminderEligible, false);
        assert.equal(await enqueue(lateEvening), 0);
      },
    );
    await check(
      "Preference, session binding, season and expiration are rechecked at delivery",
      async () => {
        await enqueue(evening);
        const delivery = await claimedContext(evening);
        assert.equal(
          (await delivery.read("2099-10-23T00:30:00Z")).reminderEligible,
          false,
        );
        assert.equal(
          (await delivery.read("2099-10-24T00:00:00Z")).reminderEligible,
          false,
        );
        await db.query(
          "update public.users set notifications_enabled=false where id=$1",
          [member],
        );
        assert.equal((await delivery.read()).reminderEligible, false);
        await db.query(
          "update public.users set notifications_enabled=true where id=$1",
          [member],
        );
        await db.query(
          "update public.push_devices set user_id=$1 where id=(select device_id from public.push_jobs where id=$2)",
          [admin, delivery.id],
        );
        assert.equal((await delivery.read()).reminderEligible, false);
        await db.query("update public.push_devices set user_id=$1", [member]);
        await db.query(
          "update public.seasons set status='closed' where id=$1",
          [season],
        );
        assert.equal((await delivery.read()).reminderEligible, false);
      },
    );
    await check(
      "No active season or disabled preference creates no reminder",
      async () => {
        await db.query(
          "update public.users set notifications_enabled=false where id=$1",
          [member],
        );
        assert.equal(await enqueue(evening), 0);
        await db.query(
          "update public.users set notifications_enabled=true where id=$1",
          [member],
        );
        await db.query(
          "update public.seasons set status='closed' where id=$1",
          [season],
        );
        assert.equal(await enqueue(evening), 0);
      },
    );
    await check(
      "Today activity from a previous cycle also counts",
      async () => {
        await addLog("approved");
        await db.query(
          "update public.seasons set status='closed' where id=$1",
          [season],
        );
        await db.exec(
          "insert into public.seasons(name) values ('Next season')",
        );
        assert.equal(await enqueue(evening), 0);
      },
    );
    await check(
      "Changing active cycles cannot duplicate a reminder slot",
      async () => {
        assert.equal(await enqueue(evening), 2);
        await db.query(
          "update public.seasons set status='closed' where id=$1",
          [season],
        );
        await db.exec(
          "insert into public.seasons(name) values ('Next season')",
        );
        assert.equal(await enqueue(evening), 0);
      },
    );
    await check(
      "Unknown leases and authenticated clients cannot read reminder context or change time",
      async () => {
        await enqueue(evening);
        const delivery = await claimedContext(evening);
        assert.equal(
          await value(
            "select private.push_reminder_context($1,gen_random_uuid(),$2)",
            [delivery.id, evening],
          ),
          null,
        );
        // Cada error esperado se revierte para no abortar la transacción de la prueba.
        for (
          const sql of [
            "select private.enqueue_inactivity_reminders('2099-10-23T00:00Z')",
            "select public.get_push_reminder_context(gen_random_uuid(),gen_random_uuid())",
          ]
        ) {
          await db.exec("savepoint denied; set role authenticated");
          await assert.rejects(() => db.query(sql), /permission denied/);
          await db.exec(
            "rollback to savepoint denied; release savepoint denied",
          );
        }
      },
    );
    await check("Expired reminders cannot be claimed", async () => {
      await enqueue(evening);
      await db.exec(
        "update public.push_jobs set expires_at=now()-interval '1 second'",
      );
      assert.equal(
        (await db.query("select * from public.claim_push_jobs(10)")).rows
          .length,
        0,
      );
      assert.equal(
        await value(
          "select count(*)::int from public.push_jobs where status='failed' and last_error='expired'",
        ),
        2,
      );
    });
    await check(
      "Logout deletes pending reminders through the device foreign key",
      async () => {
        await enqueue(evening);
        await db.query("delete from public.push_devices where user_id=$1", [
          member,
        ]);
        assert.equal((await jobs()).length, 0);
      },
    );
    await check(
      "Cron activation is repeatable and preserves the delivery worker",
      async () => {
        // Se simula solo el catálogo de Cron; las funciones de negocio usan PostgreSQL real.
        await db.exec(`create schema cron;
        create table cron.job(jobid bigserial primary key, jobname text, schedule text, command text, active boolean default true);
        create function cron.schedule(text,text,text) returns bigint language sql as
          'insert into cron.job(jobname,schedule,command) values ($1,$2,$3) returning jobid';
        create function cron.unschedule(bigint) returns boolean language sql as
          'delete from cron.job where jobid=$1 returning true';
        insert into cron.job(jobname,schedule,command) values ('send_task_notifications','* * * * *','select 1');
        create function private.test_wake() returns trigger language plpgsql as 'begin return null; end;';
        create trigger push_jobs_wake_worker after insert on public.push_jobs for each statement execute function private.test_wake();`);
        const activation = load("supabase/enable_inactivity_reminders.sql")
          .replace(/^begin;\s*$/gm, "").replace(/^commit;\s*$/gm, "");
        await db.exec(activation);
        await db.exec(activation);
        assert.equal(
          await value(
            "select count(*)::int from cron.job where jobname='inactivity_reminders'",
          ),
          1,
        );
        assert.equal(
          await value(
            "select schedule from cron.job where jobname='inactivity_reminders'",
          ),
          "0 * * * *",
        );
        assert.equal(
          await value(
            "select command from cron.job where jobname='inactivity_reminders'",
          ),
          "select private.enqueue_inactivity_reminders();",
        );
        assert.equal(
          await value(
            "select count(*)::int from cron.job where jobname='send_task_notifications' and active",
          ),
          1,
        );
        await db.exec(
          "update cron.job set active=false where jobname='send_task_notifications'; savepoint disabled_delivery",
        );
        await assert.rejects(() => db.exec(activation), /Activa primero/);
        await db.exec(
          "rollback to savepoint disabled_delivery; release savepoint disabled_delivery",
        );
      },
    );
    await db.exec("rollback");
    console.log(
      `${passed} reminder database checks passed; legacy job ${legacyLog} preserved during migration.`,
    );
  } finally {
    await db.close();
  }
}
main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
