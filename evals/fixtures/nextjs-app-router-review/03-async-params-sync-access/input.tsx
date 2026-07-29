import { notFound } from "next/navigation";

export const runtime = "nodejs";

interface PageProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ tab?: string }>;
}

interface Order {
  id: string;
  total: number;
}

export default async function OrderPage({ params, searchParams }: PageProps) {
  const order: Order | null = await fetch(
    `https://api.example.com/orders/${params.id}`,
    { cache: "no-store" }
  ).then((r) => (r.ok ? r.json() : null));

  if (!order) notFound();

  const sp = await searchParams;
  return (
    <main>
      <h1>Order {order.id}</h1>
      <p>Total: {order.total}</p>
      <p>Tab: {sp.tab ?? "summary"}</p>
    </main>
  );
}
