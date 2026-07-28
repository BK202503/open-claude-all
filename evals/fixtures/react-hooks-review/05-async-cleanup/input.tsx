import { useEffect, useState } from "react";

interface Props {
  query: string;
}

export function Search({ query }: Props) {
  const [results, setResults] = useState<string[]>([]);

  useEffect(() => {
    fetch(`/api/search?q=${encodeURIComponent(query)}`)
      .then((r) => r.json())
      .then(setResults);
  }, [query]);

  return (
    <ul>
      {results.map((r) => (
        <li key={r}>{r}</li>
      ))}
    </ul>
  );
}
