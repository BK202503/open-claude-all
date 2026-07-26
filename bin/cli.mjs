#!/usr/bin/env node
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { existsSync } from "node:fs";

const pkgRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);

const HELP = `open-claude-all: Claude Code skills + hooks installer

Usage:
  npx open-claude-all [install] [--dry-run] [--skip-hook]
  npx open-claude-all uninstall [--dry-run]

Commands:
  install     (default) copy skills, agents, hooks into ~/.claude
              and wire the branch-guard PreToolUse hook.
  uninstall   remove skills, agents, hooks installed by this package
              and unwire the branch-guard hook.

Options:
  --dry-run   print what would happen, change nothing.
  --skip-hook (install only) skip branch-guard hook wiring.
  -h, --help  show this help.
`;

if (args.includes("-h") || args.includes("--help")) {
  process.stdout.write(HELP);
  process.exit(0);
}

const [maybeCmd, ...rest] = args;
let cmd = "install";
let scriptArgs = args;
if (maybeCmd === "install" || maybeCmd === "uninstall") {
  cmd = maybeCmd;
  scriptArgs = rest;
}

const script = join(pkgRoot, cmd === "install" ? "install.sh" : "uninstall.sh");
if (!existsSync(script)) {
  console.error(`open-claude-all: cannot find ${script}`);
  process.exit(1);
}

const child = spawn("bash", [script, ...scriptArgs], { stdio: "inherit" });
child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
  } else {
    process.exit(code ?? 1);
  }
});
