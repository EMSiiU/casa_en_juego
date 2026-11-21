import { createHandler } from "./handler.ts";

const userId = "00000000-0000-0000-0000-000000000001";
const config = {
  supabaseUrl: "https://auth.example",
  supabaseKey: "public-test-key",
  stripeSecretKey: "sk_test_fixture",
  stripePublishableKey: "pk_test_fixture",
  familyPrice: "price_fixture",
};

function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}

function setup() {
  const calls: Request[] = [];
  let customer = false;
  let subscription = false;
  const state = {
    authenticated: true,
    confirmed: true,
    amount: 3900,
    status: "incomplete",
    plan: "familia",
  };
  const payload = () => ({
    id: "sub_fixture",
    status: state.status,
    metadata: { plan: state.plan },
    latest_invoice: {
      confirmation_secret: { client_secret: "pi_fixture_secret_test" },
    },
  });
  const request: typeof fetch = async (input, init) => {
    const call = new Request(input, init);
    calls.push(call.clone());
    const url = new URL(call.url);
    if (url.host === "auth.example") {
      return Response.json({
        id: userId,
        email: "test@example.com",
        email_confirmed_at: state.confirmed ? "2026-11-01" : null,
      }, { status: state.authenticated ? 200 : 401 });
    }
    assert(call.headers.get("Authorization") === "Bearer sk_test_fixture");
    if (url.pathname === "/v1/prices/price_fixture") {
      return Response.json({
        active: true,
        livemode: false,
        currency: "mxn",
        unit_amount: state.amount,
        recurring: { interval: "month", interval_count: 1 },
      });
    }
    if (url.pathname === "/v1/customers/search") {
      assert(url.searchParams.get("query")?.includes(userId));
      return Response.json({ data: customer ? [{ id: "cus_fixture" }] : [] });
    }
    if (url.pathname === "/v1/customers") {
      const body = new URLSearchParams(await call.text());
      assert(body.get("metadata[supabase_user_id]") === userId);
      customer = true;
      return Response.json({ id: "cus_fixture" });
    }
    if (url.pathname === "/v1/subscriptions" && call.method === "GET") {
      assert(url.searchParams.get("customer") === "cus_fixture");
      return Response.json({ data: subscription ? [payload()] : [] });
    }
    if (url.pathname === "/v1/subscriptions" && call.method === "POST") {
      const body = new URLSearchParams(await call.text());
      assert(body.get("items[0][price]") === "price_fixture");
      assert(body.get("payment_behavior") === "default_incomplete");
      assert(body.get("metadata[supabase_user_id]") === userId);
      assert(
        call.headers.get("Idempotency-Key") === `casa-familia-${userId}-first`,
      );
      subscription = true;
      return Response.json(payload());
    }
    if (url.pathname === "/v1/subscriptions/sub_fixture") {
      return Response.json(payload());
    }
    throw new Error("Unexpected test request");
  };
  const handler = createHandler(config, request);
  const post = (action = "checkout") =>
    handler(
      new Request("https://function.example", {
        method: "POST",
        headers: { Authorization: "Bearer user-session" },
        body: JSON.stringify({
          action,
          amount: 1,
          customer: "cus_foreign",
          price: "price_foreign",
        }),
      }),
    );
  return { handler, request, post, state, calls };
}

Deno.test("Missing and invalid sessions cannot call Stripe", async () => {
  const test = setup();
  assert(
    (await test.handler(
      new Request("https://function.example", { method: "POST" }),
    )).status === 401,
  );
  assert(test.calls.length === 0);
  test.state.authenticated = false;
  assert((await test.post()).status === 401);
  test.state.authenticated = true;
  test.state.confirmed = false;
  assert((await test.post()).status === 403);
  assert(test.calls.every((call) => call.url.startsWith(config.supabaseUrl)));
});

Deno.test("Only test credentials and the advertised monthly price are accepted", async () => {
  const test = setup();
  const live = createHandler(
    { ...config, stripeSecretKey: "sk_live_fixture" },
    test.request,
  );
  assert(
    (await live(
      new Request("https://function.example", {
        method: "POST",
        headers: { Authorization: "Bearer test" },
      }),
    )).status === 503,
  );
  test.state.amount = 1;
  assert((await test.post()).status === 503);
  assert(test.calls.every((call) => call.method === "GET"));
});

Deno.test("Server selects identity and price and reuses an incomplete subscription", async () => {
  const test = setup();
  const first = await test.post();
  assert(first.status === 200);
  assert(first.headers.get("Cache-Control") === "no-store");
  const body = await first.json();
  assert(body.clientSecret === "pi_fixture_secret_test");
  assert(body.publishableKey === "pk_test_fixture");
  assert(!JSON.stringify(body).includes(config.stripeSecretKey));
  assert((await test.post()).status === 200);
  assert(
    test.calls.filter((call) =>
      call.method === "POST" && call.url.endsWith("/subscriptions")
    ).length === 1,
  );
  test.state.status = "active";
  const active = await (await test.post()).json();
  assert(active.status === "active" && !active.clientSecret);
});

Deno.test("Transport and provider errors return a safe message", async () => {
  const handler = createHandler(
    config,
    () => Promise.reject(new Error("sensitive-body")),
  );
  const response = await handler(
    new Request("https://function.example", {
      method: "POST",
      headers: { Authorization: "Bearer test" },
    }),
  );
  assert(response.status === 502);
  assert(!(await response.text()).includes("sensitive-body"));
});

Deno.test("Status is read-only and follows active plans and cancellation", async () => {
  const test = setup();
  assert((await (await test.post("status")).json()).plan === "casa");
  assert(test.calls.every((call) => call.method === "GET"));
  await test.post();
  for (const plan of ["familia", "comunidad"]) {
    test.state.status = "active";
    test.state.plan = plan;
    const start = test.calls.length;
    const response = await test.post("status");
    assert(response.status === 200);
    const body = await response.json();
    assert(body.plan === plan && !body.clientSecret);
    assert(test.calls.slice(start).every((call) => call.method === "GET"));
  }
  for (const status of ["canceled", "incomplete", "past_due"]) {
    test.state.status = status;
    assert((await (await test.post("status")).json()).plan === "casa");
  }
  assert((await test.post("unsupported")).status === 400);
});
