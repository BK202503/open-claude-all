import { useEffect, useState } from "react";

interface Props {
  userId: string;
}

export function UserProfile({ userId }: Props) {
  const [user, setUser] = useState<{ name: string } | null>(null);

  useEffect(() => {
    fetch(`/api/users/${userId}`)
      .then((r) => r.json())
      .then(setUser);
  }, []);

  return <div>{user?.name ?? "loading..."}</div>;
}
