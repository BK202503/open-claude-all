"use client";

import { useEffect, useState } from "react";

interface Feed {
  items: string[];
}

export function LiveFeed() {
  const [feed, setFeed] = useState<Feed>({ items: [] });

  useEffect(() => {
    const base = process.env.API_URL ?? "http://localhost:3000";
    fetch(`${base}/api/feed`)
      .then((r) => r.json())
      .then(setFeed);
  }, []);

  return (
    <ul>
      {feed.items.map((it) => (
        <li key={it}>{it}</li>
      ))}
    </ul>
  );
}
