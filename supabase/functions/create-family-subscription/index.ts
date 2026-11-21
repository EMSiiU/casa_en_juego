import { createHandler } from "./handler.ts";

Deno.serve(createHandler({
  supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
  supabaseKey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  stripeSecretKey: Deno.env.get("STRIPE_SECRET_KEY") ?? "",
  stripePublishableKey: Deno.env.get("STRIPE_PUBLISHABLE_KEY") ?? "",
  familyPrice: Deno.env.get("STRIPE_PRICE_FAMILIA") ?? "",
  communityPrice: Deno.env.get("STRIPE_PRICE_COMUNIDAD") ?? "",
}));
