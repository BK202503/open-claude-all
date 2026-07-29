import { headers } from "next/headers";

interface Metric {
  label: string;
  value: number;
}

export default async function LiveDashboardPage() {
  const h = await headers();
  const region = h.get("x-region") ?? "us-east";

  const metrics: Metric[] = await fetch(
    `https://api.example.com/metrics/live?region=${region}`
  ).then((r) => r.json());

  const regions: string[] = await fetch(
    "https://api.example.com/regions",
    { next: { revalidate: 3600 } }
  ).then((r) => r.json());

  return (
    <main>
      <h1>Live metrics ({region})</h1>
      <ul>
        {metrics.map((m) => (
          <li key={m.label}>{m.label}: {m.value}</li>
        ))}
      </ul>
      <small>Regions: {regions.join(", ")}</small>
    </main>
  );
}
