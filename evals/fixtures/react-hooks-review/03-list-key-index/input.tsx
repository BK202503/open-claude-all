import { useState } from "react";

interface Todo {
  id: string;
  text: string;
}

interface Props {
  todos: Todo[];
}

export function TodoList({ todos }: Props) {
  const [checked, setChecked] = useState<Record<number, boolean>>({});

  return (
    <ul>
      {todos.map((todo, i) => (
        <li key={i}>
          <input
            type="checkbox"
            checked={!!checked[i]}
            onChange={() => setChecked({ ...checked, [i]: !checked[i] })}
          />
          {todo.text}
        </li>
      ))}
    </ul>
  );
}
