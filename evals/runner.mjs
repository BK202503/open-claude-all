#!/usr/bin/env node
// evals/runner.mjs — score open-claude-all review skills against planted-bug fixtures.
//
// Usage:
//   node evals/runner.mjs                          # run all skills, all fixtures
//   node evals/runner.mjs --skill react-hooks-review
//   node evals/runner.mjs --fixture 01-stale-closure
//   node evals/runner.mjs --dry-run                # validate fixture format, no API calls
//   node evals/runner.mjs --verbose                # dump raw claude output for each call
//   node evals/runner.mjs --strict-auth            # opt in to --bare (needs ANTHROPIC_API_KEY; use in CI)
//
// By default, uses whatever auth the local `claude` CLI already has (OAuth /
// keychain). Pass --strict-auth (or set OCA_EVAL_STRICT=1) to switch to
// --bare mode, which is reproducible but requires ANTHROPIC_API_KEY.
// Cost cap per fixture is enforced via --max-budget-usd (default 0.20 for review, 0.05 for extract).

import { readdir, readFile, writeFile, mkdir } from "node:fs/promises";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const FIXTURES_DIR = join(REPO_ROOT, "evals", "fixtures");
const RESULTS_DIR = join(REPO_ROOT, "evals", "results");

// Categories are defined per-skill in evals/fixtures/<skill>/categories.json.
// Falls back to this list if the file is absent (kept for the original react
// skill so existing fixtures still work before the categories file is added).
const FALLBACK_CATEGORIES = [
  "missing-dep",
  "stale-closure",
  "functional-updater",
  "over-memoization",
  "key-antipattern",
  "async-cleanup",
  "rules-of-hooks",
  "server-component-leak",
];

const LINE_TOLERANCE = 3;

async function loadCategoriesForSkill(skillName) {
  const path = join(FIXTURES_DIR, skillName, "categories.json");
  try {
    const raw = await readFile(path, "utf8");
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed.categories) || parsed.categories.length === 0) {
      throw new Error(`${path}: "categories" must be a non-empty array of strings`);
    }
    return parsed.categories;
  } catch (err) {
    if (err.code === "ENOENT") return FALLBACK_CATEGORIES;
    throw err;
  }
}

function parseCliArgs() {
  const { values } = parseArgs({
    options: {
      skill: { type: "string" },
      fixture: { type: "string" },
      "dry-run": { type: "boolean", default: false },
      verbose: { type: "boolean", default: false },
      "strict-auth": { type: "boolean", default: false },
      "review-budget-usd": { type: "string", default: "0.30" },
      "extract-budget-usd": { type: "string", default: "0.05" },
      "extract-model": { type: "string", default: "haiku" },
    },
  });
  return values;
}

function parseJsonc(text) {
  return JSON.parse(
    text.replace(/\/\/.*$/gm, "").replace(/\/\*[\s\S]*?\*\//g, "")
  );
}

async function listDir(path) {
  const entries = await readdir(path, { withFileTypes: true });
  return entries.filter((e) => e.isDirectory() && !e.name.startsWith(".")).map((e) => e.name);
}

async function loadFixture(skillName, fixtureName) {
  const dir = join(FIXTURES_DIR, skillName, fixtureName);
  const files = await readdir(dir);
  const inputFile = files.find((f) => f.startsWith("input."));
  if (!inputFile) throw new Error(`no input.* in ${dir}`);
  const [input, expectedRaw] = await Promise.all([
    readFile(join(dir, inputFile), "utf8"),
    readFile(join(dir, "expected.jsonc"), "utf8"),
  ]);
  return {
    dir,
    inputPath: join(dir, inputFile),
    inputFile,
    input,
    expected: parseJsonc(expectedRaw),
  };
}

function runClaude(args, { timeoutMs = 180_000 } = {}) {
  return new Promise((resolvePromise, reject) => {
    const proc = spawn("claude", args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (d) => (stdout += d.toString()));
    proc.stderr.on("data", (d) => (stderr += d.toString()));
    const timer = setTimeout(() => {
      proc.kill("SIGKILL");
      reject(new Error(`claude timed out after ${timeoutMs}ms`));
    }, timeoutMs);
    proc.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
    proc.on("close", (code) => {
      clearTimeout(timer);
      if (code !== 0) return reject(new Error(`claude exited ${code}\nstderr:\n${stderr}`));
      resolvePromise({ stdout, stderr });
    });
  });
}

function extractAssistantText(rawJson) {
  const parsed = JSON.parse(rawJson);
  if (typeof parsed.result === "string") return parsed.result;
  if (typeof parsed.content === "string") return parsed.content;
  if (Array.isArray(parsed.messages)) {
    const last = parsed.messages[parsed.messages.length - 1];
    if (typeof last?.content === "string") return last.content;
  }
  throw new Error(`unrecognized claude -p json shape: ${rawJson.slice(0, 400)}`);
}

// When --json-schema is passed, the schema-conforming JSON lands in
// .structured_output. The .result field usually holds a prose summary that
// is NOT valid JSON — parsing it fails. Prefer structured_output.
function extractStructuredOutput(rawJson) {
  const parsed = JSON.parse(rawJson);
  if (parsed.structured_output && typeof parsed.structured_output === "object") {
    return parsed.structured_output;
  }
  // Fallback: try to JSON.parse the result field, in case a future CLI
  // version puts the structured output there directly.
  const text = extractAssistantText(rawJson);
  try { return JSON.parse(text); } catch { /* fall through */ }
  throw new Error(`no structured_output and .result is not JSON:\n${text.slice(0, 400)}`);
}

async function reviewWithSkill({ fixture, skillName, budgetUsd, verbose, strictAuth }) {
  const prompt =
    `Review the file at \`${fixture.inputPath}\` using the /${skillName} skill. ` +
    `For every issue you find, state the exact line number and briefly describe the problem. ` +
    `Do not modify the file. Read only.`;
  const args = [
    "-p",
    ...(strictAuth ? ["--bare"] : []),
    "--plugin-dir", REPO_ROOT,
    "--add-dir", fixture.dir,
    "--allowedTools", "Read",
    "--max-budget-usd", String(budgetUsd),
    "--output-format", "json",
    prompt,
  ];
  if (verbose) console.error(`    $ claude ${args.map((a) => (a.includes(" ") ? `"${a}"` : a)).join(" ")}`);
  const { stdout } = await runClaude(args);
  if (verbose) console.error(`    <raw>\n${stdout}\n    </raw>`);
  return extractAssistantText(stdout);
}

async function extractFindings({ reviewText, categories, budgetUsd, verbose, strictAuth, model }) {
  const schema = {
    type: "object",
    properties: {
      findings: {
        type: "array",
        items: {
          type: "object",
          properties: {
            line: { type: "integer" },
            category: { type: "string", enum: categories },
            snippet: { type: "string" },
          },
          required: ["line", "category"],
        },
      },
    },
    required: ["findings"],
  };
  const prompt =
    `Extract structured findings from this code review. ` +
    `For each issue mentioned, emit {line, category, snippet}. ` +
    `Categories must be one of: ${categories.join(", ")}. ` +
    `If a mentioned issue does not clearly fit any category, pick the closest match. ` +
    `Do not invent findings that the review did not mention.\n\n` +
    `Review:\n${reviewText}`;
  const args = [
    "-p",
    ...(strictAuth ? ["--bare"] : []),
    "--model", model,
    "--json-schema", JSON.stringify(schema),
    "--max-budget-usd", String(budgetUsd),
    "--output-format", "json",
    prompt,
  ];
  if (verbose) console.error(`    $ claude -p --json-schema ... "<extract prompt>"`);
  const { stdout } = await runClaude(args);
  if (verbose) console.error(`    <raw>\n${stdout}\n    </raw>`);
  const parsed = extractStructuredOutput(stdout);
  return parsed.findings ?? [];
}

function categoriesOf(expected) {
  return Array.isArray(expected.category) ? expected.category : [expected.category];
}

function scoreFixture(findings, expected) {
  const mustFlag = expected.must_flag ?? [];
  const mustNotFlag = expected.must_not_flag ?? [];
  const matchedExpected = new Set();
  let tp = 0;
  let fp = 0;
  let extra = 0;
  const findingAudit = [];

  for (const f of findings) {
    // Try to match against must_flag first.
    let matchIdx = -1;
    for (let i = 0; i < mustFlag.length; i++) {
      if (matchedExpected.has(i)) continue;
      const e = mustFlag[i];
      const lineOk = Math.abs(f.line - e.line) <= LINE_TOLERANCE;
      const catOk = categoriesOf(e).includes(f.category);
      if (lineOk && catOk) {
        matchIdx = i;
        break;
      }
    }
    if (matchIdx >= 0) {
      tp += 1;
      matchedExpected.add(matchIdx);
      findingAudit.push({ ...f, verdict: "TP", matched_expected: matchIdx });
      continue;
    }
    // Not a must_flag match — check against must_not_flag (explicit FP).
    const isFp = mustNotFlag.some((n) => {
      const lineOk = Math.abs(f.line - n.line) <= LINE_TOLERANCE;
      const catOk = !n.category || categoriesOf(n).includes(f.category);
      return lineOk && catOk;
    });
    if (isFp) {
      fp += 1;
      findingAudit.push({ ...f, verdict: "FP" });
    } else {
      // Bonus / undocumented finding — logged but not counted against precision.
      // (Real bugs the fixture author didn't enumerate. Review the audit and
      // promote to must_flag if legitimate.)
      extra += 1;
      findingAudit.push({ ...f, verdict: "EXTRA" });
    }
  }

  const fn = mustFlag.length - matchedExpected.size;
  const missed = mustFlag
    .map((e, i) => ({ ...e, i }))
    .filter((e) => !matchedExpected.has(e.i));

  return {
    tp, fp, fn, extra,
    total_expected: mustFlag.length,
    total_found: findings.length,
    findings_audit: findingAudit,
    missed,
  };
}

function pct(n, d) {
  if (d === 0) return "n/a";
  return `${((100 * n) / d).toFixed(0)}%`;
}

async function main() {
  const opts = parseCliArgs();
  const reviewBudget = Number(opts["review-budget-usd"]);
  const extractBudget = Number(opts["extract-budget-usd"]);
  const extractModel = opts["extract-model"];
  const verbose = opts.verbose;
  const strictAuth = opts["strict-auth"] || process.env.OCA_EVAL_STRICT === "1";

  if (strictAuth && !opts["dry-run"] && !process.env.ANTHROPIC_API_KEY) {
    console.error("error: --strict-auth uses `claude --bare` which requires ANTHROPIC_API_KEY.");
    console.error("       either drop --strict-auth (use your CLI's OAuth) or export the key.");
    process.exit(2);
  }

  const skills = opts.skill ? [opts.skill] : await listDir(FIXTURES_DIR);
  const results = [];

  for (const skillName of skills) {
    const skillDir = join(FIXTURES_DIR, skillName);
    const categories = await loadCategoriesForSkill(skillName);
    const fixtureNames = (await listDir(skillDir)).filter(
      (n) => !opts.fixture || n === opts.fixture
    );

    for (const fixtureName of fixtureNames) {
      const fixture = await loadFixture(skillName, fixtureName);
      console.log(`\n[${skillName}/${fixtureName}]`);
      if (fixture.expected.notes) console.log(`  ${fixture.expected.notes}`);

      if (opts["dry-run"]) {
        console.log(
          `  DRY: expected ${fixture.expected.must_flag?.length ?? 0} findings, skipping API`
        );
        results.push({ skill: skillName, fixture: fixtureName, dry_run: true });
        continue;
      }

      let review, findings;
      try {
        review = await reviewWithSkill({ fixture, skillName, budgetUsd: reviewBudget, verbose, strictAuth });
        console.log(`  review: ${review.length} chars`);
        findings = await extractFindings({ reviewText: review, categories, budgetUsd: extractBudget, verbose, strictAuth, model: extractModel });
      } catch (err) {
        console.error(`  ERROR: ${err.message}`);
        results.push({ skill: skillName, fixture: fixtureName, error: err.message });
        continue;
      }

      const score = scoreFixture(findings, fixture.expected);
      console.log(
        `  found=${findings.length}  TP=${score.tp}  FP=${score.fp}  FN=${score.fn}  EXTRA=${score.extra}  ` +
          `precision=${pct(score.tp, score.tp + score.fp)}  recall=${pct(score.tp, score.tp + score.fn)}`
      );
      if (score.missed.length) {
        for (const m of score.missed) {
          console.log(`    MISSED: line ${m.line} [${categoriesOf(m).join("|")}] — ${m.hint ?? ""}`);
        }
      }
      for (const f of score.findings_audit) {
        if (f.verdict === "EXTRA") {
          console.log(`    EXTRA:  line ${f.line} [${f.category}] — ${(f.snippet ?? "").slice(0, 80)}`);
        }
      }
      results.push({
        skill: skillName,
        fixture: fixtureName,
        review_chars: review.length,
        ...score,
      });
    }
  }

  if (opts["dry-run"]) return;

  await mkdir(RESULTS_DIR, { recursive: true });
  const outPath = join(RESULTS_DIR, "latest.json");
  await writeFile(
    outPath,
    JSON.stringify({ timestamp: new Date().toISOString(), results }, null, 2)
  );
  console.log(`\nwrote ${outPath}`);

  const perSkill = {};
  for (const r of results) {
    if (r.error || r.dry_run) continue;
    perSkill[r.skill] ??= { tp: 0, fp: 0, fn: 0, extra: 0, fixtures: 0 };
    perSkill[r.skill].tp += r.tp;
    perSkill[r.skill].fp += r.fp;
    perSkill[r.skill].fn += r.fn;
    perSkill[r.skill].extra += r.extra;
    perSkill[r.skill].fixtures += 1;
  }

  console.log("\n=== summary ===");
  for (const [skill, s] of Object.entries(perSkill)) {
    console.log(
      `${skill}: ${s.fixtures} fixtures  ` +
        `precision=${pct(s.tp, s.tp + s.fp)}  recall=${pct(s.tp, s.tp + s.fn)}  ` +
        `(TP=${s.tp} FP=${s.fp} FN=${s.fn} EXTRA=${s.extra})`
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
