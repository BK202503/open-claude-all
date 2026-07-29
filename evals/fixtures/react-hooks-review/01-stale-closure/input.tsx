import { useCallback, useState } from "react";

interface Props {
  onCommit: (n: number) => void;
}

export function Counter({ onCommit }: Props) {
  const [count, setCount] = useState(0);

  const handleClick = useCallback(() => {
    setCount(count + 1);
    onCommit(count + 1);
  }, []);

  return <button onClick={handleClick}>Count: {count}</button>;
}
