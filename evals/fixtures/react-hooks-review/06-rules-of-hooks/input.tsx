import { useState } from "react";

interface Props {
  featureEnabled: boolean;
}

export function Toggle({ featureEnabled }: Props) {
  if (!featureEnabled) return null;

  const [on, setOn] = useState(false);

  return <button onClick={() => setOn((v) => !v)}>{on ? "ON" : "OFF"}</button>;
}
