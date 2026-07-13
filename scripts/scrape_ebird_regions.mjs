#!/usr/bin/env node
// Scrape eBird level-2 subdivisions (counties/departments) into an existing
// JSONL that already holds countries and their level-1 subdivisions.
//
//   node scripts/scrape_ebird_regions.mjs [file.jsonl]
//
// Countries and subregion1 records are assumed already present (produced by an
// earlier pass); this run reads them, then fetches each subregion1's
// /subregions page and appends its subregion2 children. Many subregion1s have
// no level-2 children on eBird — that's expected.
//
//   {"code":"US","name":"United States","level":"country","parent_code":null}
//   {"code":"US-NY","name":"New York","level":"subregion1","parent_code":"US"}
//   {"code":"US-NY-061","name":"New York","level":"subregion2","parent_code":"US-NY"}
//
// Resumable: during the run each finished subregion1 gets a sentinel line
// {"_done":"US-NY"}, and codes are de-duped, so an interrupted run (Ctrl-C,
// crash) continues where it left off. The sentinel lines are stripped from the
// file on clean completion, leaving pure region records.
//
// Zero dependencies: built-in fetch (Node 18+) + regex parsing. Anubis bot
// detection challenges browser-like (Mozilla/…) UAs but lets programmatic ones
// through — so we send a plain non-browser UA. Still polite: rate-limited, with
// retries.

import { writeFileSync, appendFileSync, existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const BASE = "https://ebird.org";

// Default output lands in priv/datasets/geo/sources/ regardless of cwd.
const scriptDir = dirname(fileURLToPath(import.meta.url));
const DEFAULT_OUT = resolve(
  scriptDir,
  "../priv/datasets/geo/sources/ebird_subregions.jsonl"
);
const OUT = process.argv[2] || DEFAULT_OUT;

// Politeness / robustness knobs.
const DELAY_MS = 700; // between successful requests
const MAX_RETRIES = 4;
const RETRY_BASE_MS = 2000; // exponential backoff base

// No custom User-Agent: let Node send its default (node/<version>). Anubis
// challenges browser-like (Mozilla/…) UAs but lets the default node UA through.
const HEADERS = {
  Accept: "text/html,application/xhtml+xml",
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchHtml(url) {
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const res = await fetch(url, { headers: HEADERS, redirect: "follow" });
      if (res.ok) return await res.text();
      // 429 / 5xx: back off and retry.
      if (res.status === 429 || res.status >= 500) {
        throw new Error(`HTTP ${res.status}`);
      }
      // Other 4xx: not worth retrying.
      throw new Error(`HTTP ${res.status} (giving up)`);
    } catch (err) {
      const last = attempt === MAX_RETRIES;
      const giveUp = String(err.message).includes("giving up");
      if (last || giveUp) throw err;
      const wait = RETRY_BASE_MS * 2 ** attempt;
      console.error(`  ${url} -> ${err.message}; retry in ${wait}ms`);
      await sleep(wait);
    }
  }
}

const decodeEntities = (s) =>
  s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;|&#x27;|&apos;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .trim();

// Extract <a href="…/region/CODE…">Name</a> where CODE matches `codeRe`.
// Deduped by code, preserving first-seen name. Handles both absolute
// (https://ebird.org/region/CO) and root-relative (/region/CO) hrefs.
function extractRegions(html, codeRe) {
  const out = new Map();
  const linkRe = /<a\b[^>]*href="[^"]*\/region\/([^"?/#]+)[^"]*"[^>]*>([\s\S]*?)<\/a>/gi;
  let m;
  while ((m = linkRe.exec(html))) {
    const code = m[1];
    if (!codeRe.test(code)) continue;
    // Strip any nested tags from the link body, collapse whitespace.
    const name = decodeEntities(m[2].replace(/<[^>]+>/g, " ").replace(/\s+/g, " "));
    if (!name) continue;
    if (!out.has(code)) out.set(code, name);
  }
  return out;
}

// State loaded from the existing file at startup:
//   seenCodes    — every code present, so re-appends stay idempotent.
//   donePrefixes — subregion1s whose children were fully fetched (sentinel seen).
//   subregion1s  — parents to fetch level-2 children for, in file order.
// A parent is only "done" once its sentinel lands, so a run interrupted
// mid-parent refetches that parent; already-written children are then skipped.
const seenCodes = new Set();
const donePrefixes = new Set();
const subregion1s = [];

function loadInput() {
  if (!existsSync(OUT)) {
    console.error(`Input file not found: ${OUT}`);
    console.error("Expected an existing JSONL with country + subregion1 records.");
    process.exit(1);
  }
  const text = readFileSync(OUT, "utf8");
  for (const line of text.split("\n")) {
    if (!line) continue;
    let rec;
    try {
      rec = JSON.parse(line);
    } catch {
      continue; // tolerate a truncated final line from a hard kill
    }
    if (rec._done) {
      donePrefixes.add(rec._done);
      continue;
    }
    if (!rec.code) continue;
    seenCodes.add(rec.code);
    if (rec.level === "subregion1") subregion1s.push(rec.code);
  }
}

function writeRecord(record) {
  appendFileSync(OUT, JSON.stringify(record) + "\n");
}

// Write a region record unless its code is already present (idempotent resume).
function writeRegion(record) {
  if (seenCodes.has(record.code)) return;
  writeRecord(record);
  seenCodes.add(record.code);
}

function markDone(prefix) {
  writeRecord({ _done: prefix });
  donePrefixes.add(prefix);
}

// Escape a code for safe interpolation into a RegExp (codes contain letters,
// digits and '-'; escaping is cheap insurance against surprises).
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Fetch a region's /subregions page and return its direct children as a Map
// code -> name. A direct child of PREFIX is PREFIX-<segment> with no further
// dash. Returns null on fetch failure so the caller can distinguish it from
// "fetched, but no children".
async function fetchChildren(prefix) {
  let html;
  try {
    html = await fetchHtml(`${BASE}/region/${prefix}/subregions`);
  } catch (err) {
    console.error(`  ${prefix}/subregions FAILED (${err.message})`);
    return null;
  }
  const childRe = new RegExp(`^${escapeRe(prefix)}-[^-]+$`);
  const children = extractRegions(html, childRe);
  children.delete(prefix); // guard against a self-link slipping through
  return children;
}

// Rewrite the file keeping only well-formed region records: drops the
// {"_done":...} sentinels and any malformed line (e.g. a truncated final line
// left by a hard kill, whose region was re-fetched cleanly on resume). Record
// order is otherwise preserved. Called once on clean completion.
function finalizeFile() {
  const kept = [];
  for (const line of readFileSync(OUT, "utf8").split("\n")) {
    if (!line) continue;
    let rec;
    try {
      rec = JSON.parse(line);
    } catch {
      continue; // malformed / truncated
    }
    if (rec._done) continue;
    kept.push(line);
  }
  writeFileSync(OUT, kept.join("\n") + "\n");
  return kept.length;
}

async function main() {
  loadInput();

  if (subregion1s.length === 0) {
    console.error("No subregion1 records in input — nothing to expand. Aborting.");
    process.exit(1);
  }

  const todo = subregion1s.filter((code) => !donePrefixes.has(code));
  console.error(
    `${subregion1s.length} subregion1s in file; ` +
      `${subregion1s.length - todo.length} already done, ${todo.length} to fetch.`
  );

  let i = 0;
  let sub2Count = 0;
  for (const parent of subregion1s) {
    if (donePrefixes.has(parent)) continue; // fully fetched in a prior run
    i++;
    await sleep(DELAY_MS);
    process.stderr.write(`[${i}/${todo.length}] ${parent} … `);
    const children = await fetchChildren(parent);
    if (children === null) continue; // fetch failed; left un-done for a rerun
    for (const [code, name] of children) {
      writeRegion({ code, name, level: "subregion2", parent_code: parent });
    }
    sub2Count += children.size;
    markDone(parent);
    console.error(`${children.size}`);
  }

  const total = finalizeFile();
  console.error(
    `Done. Added subregion2 for ${todo.length} subregion1s ` +
      `(~${sub2Count} this run); ${total} total records → ${OUT}`
  );
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
