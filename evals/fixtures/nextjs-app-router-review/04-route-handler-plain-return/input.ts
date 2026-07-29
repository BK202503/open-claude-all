import type { NextRequest } from "next/server";

export const dynamic = "force-dynamic";

interface Health {
  status: "ok" | "degraded";
  uptimeSec: number;
}

const startedAt = Date.now();

export async function GET(_req: NextRequest) {
  const body: Health = {
    status: "ok",
    uptimeSec: Math.floor((Date.now() - startedAt) / 1000),
  };
  return body;
}
