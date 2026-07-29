"use client";

import { useState } from "react";
import { db } from "@/lib/db";

interface Props {
  userId: string;
}

export function AdminPanel({ userId }: Props) {
  const [note, setNote] = useState("");

  async function save() {
    await db.notes.upsert({
      where: { userId },
      update: { body: note, secret: process.env.SECRET_KEY },
      create: { userId, body: note, secret: process.env.SECRET_KEY },
    });
  }

  return (
    <div>
      <textarea value={note} onChange={(e) => setNote(e.target.value)} />
      <button onClick={save}>Save</button>
    </div>
  );
}
