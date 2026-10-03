import { createClient } from "@supabase/supabase-js";

function requireEnv(name: "VITE_SUPABASE_URL" | "VITE_SUPABASE_ANON_KEY"): string {
  const value = import.meta.env[name];
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(
      `Missing ${name}. Copy .env.example to .env.local and set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.`,
    );
  }
  return value;
}

export const supabase = createClient(
  requireEnv("VITE_SUPABASE_URL"),
  requireEnv("VITE_SUPABASE_ANON_KEY"),
);
