# LLD.md — Low-Level Design: v1.2.0 Cleanup Refactor

**Package:** `tool_schema_generator` · **Target release:** `1.2.0-dev` (prerelease; stable `1.2.0` follows) · **Status:** Implemented
**Rev 2** — supersedes Rev 1. Owner decision 2026-08-21: consolidate the entire encoding surface
onto `format(...)` (leveraging Dart ≥3.10 dot-shorthand: `format(.gemini)`) and unify MCP into
`SchemaFormat`.
**Source of findings:** 3-way review (architecture / performance / package-design agents)

---

## 1. Purpose & Scope

Harden the 1.2.0 release by (a) fixing release-hygiene blockers, (b) breaking three internal
import-cycle smells via a shared JSON types module, and (c) consolidating ALL schema encoding —
every provider, including MCP — behind a single canonical verb: `format(SchemaFormat)`,
with the legacy `.toX` sugar formally `@Deprecated`. **No removals; additive + deprecations only.**

### Goals
1. Working tree fully committed; releasable via existing tag-triggered publish workflow.
2. Static analysis actually analyzes something (`analysis_options.yaml` + `lints`).
3. Single SDK floor: `^3.11.0` everywhere (raise root, do **not** lower example). This floor
   already enables enum dot-shorthand at call sites (`tools.schemas.format(.gemini)`).
4. Zero cycles between runtime modules; internals stop importing their own public barrel.
5. **One encoding path:** `SchemaFormat` gains `mcp`; every class exposes exactly one general
   `format(...)`; all provider-named aliases (`.toX`) are deprecated with migration messages.

### Non-goals (explicitly rejected by review)
- ❌ IR rewrite — sealed `SchemaSpec`/`ToolSpec` hierarchy (lib/src/schema_spec.dart,
  lib/src/tool_spec.dart) is well designed.
- ❌ Removing `MapView` from `ToolDefinition` (lib/src/tool_definition.dart:10) — deliberate
  dual-use wire-format trick; removal requires 2.0.
- ❌ Perf micro-optimizations — analyzer resolution dominates builds by ~1000×. Only exception:
  trivially cheap memoization bundled into Phase 1 (§5.6).
- ❌ Removing deprecated members — they die in 2.0, not 1.2.0.

---

## 2. Current-State Findings (what we're fixing)

| ID | Sev | Finding | Location |
|----|-----|---------|----------|
| F1 | CRIT | 1.2.0 work uncommitted; two exported modules untracked | `git status`: `?? lib/src/tool_schema.dart`, `?? lib/src/tool_schema_collection.dart`; M ×10 |
| F2 | CRIT | No git tags; publish workflow (`v*.*.*` trigger) never validated end-to-end | `.github/workflows/publish.yml` |
| F3 | HIGH | No `analysis_options.yaml` anywhere (~10 pana pts lost) | repo root |
| F4 | HIGH | SDK floor mismatch: root `^3.10.0` vs example `^3.11.0` | pubspec.yaml:8 · example/pubspec.yaml:7 |
| F5 | MED | Internal files import own public barrel | lib/src/tool_parser.dart:5, lib/src/tool_spec.dart:2 |
| F6 | MED | Import cycle A: registry ↔ collection | lib/src/tool_registry.dart:5 ↔ lib/src/tool_schema_collection.dart:4 |
| F7 | MED | Import cycle B: definition ↔ schema | lib/src/tool_definition.dart:4 ↔ lib/src/tool_schema.dart:3 |
| F8 | MED | Redundant encode surface: `encode()`/`encoded`/`allSchemas`(dep.)/`schemas.raw`/`toOpenAiSchemas()` overlap | lib/src/tool_registry.dart:111-171, lib/src/tool_schema_collection.dart:39 |
| F9 | LOW | Bare `StateError` inside `encode(name:)` vs typed exceptions elsewhere | lib/src/tool_registry.dart:154 |
| F10 | LOW | README drift: install `^1.0.0`, conflicting `build_runner` pins, garbled sentence | README.md |
| F11 | MED | **MCP lives outside the general path**: no `SchemaFormat.mcp`; MCP maps are hand-built twice (tool_definition.dart:132, tool_schema.dart:33-37) instead of flowing through `encode()` | annotations.dart:4-13 |
| F12 | LOW | **Verb chaos**: `ToolDefinition.encode([f])` vs `format(f)` on wrapper/collection; four different alias families (`toX`, `toXSchema`, `toXSchemas`, `raw`) | see F8 refs |

> F9 dissolves automatically: the `StateError` lives inside `encode(name:)`, which Phase 2
> deprecates rather than redesigns. No error-type change ships in 1.x.

---

## 3. Target Encoding Surface (post-refactor)

```dart
// ── THE one path ────────────────────────────────────────────────
definition.format(SchemaFormat.gemini)      // single tool → any provider
schema.format(.anthropic)                   // wrapper (dot-shorthand)
collection.format(.openAi)                  // batch
registry.schemas.format(.mcp)               // registry batch (NEW: mcp!)

// ── Deprecated sugar (removed 2.0) ─────────────────────────────
def.toGeminiSchema()  schema.toAnthropic()  collection.toOpenAi()
registry.toMcpSchemas()  registry.encode(...)  encoded  raw  allSchemas
```

Design rules enforced by this refactor:
1. **One implementation per wire-shape** — all five shapes (openAi, anthropic, gemini, mcp)
   originate from `ToolDefinition._shapeFor(format)`; every alias delegates to it.
2. **One general verb** — `format(...)` named identically on `ToolDefinition`, `ToolSchema`,
   `ToolSchemaCollection` (registry reaches it via `.schemas`).
3. Aliases are pure delegations until deletion; they cannot drift.

---

## 4. Commit Plan

Staged, bisectable history. Conventional Commits (matches repo's `fix CI:` precedent).

| # | Commit message | Contents |
|---|----------------|----------|
| C1 | `chore: track pending 1.2.0 runtime additions` | Snapshot WIP verbatim: adds untracked `tool_schema.dart`, `tool_schema_collection.dart`; stages 10 modified files. |
| C2 | `chore(deps): raise SDK floor to ^3.11.0 and enable recommended lints` | §5.1–5.3. |
| C3 | `refactor: extract json_types module and break internal import cycles` | §5.4–5.6. Generated output must remain **byte-identical** (golden diff). |
| C4a | `feat(api): add SchemaFormat.mcp and unify MCP wire shape` | §5.7: enum value, switch arm, delegation cleanup. Generated output changes **only in doc-comment text**. |
| C4b | `refactor(api): consolidate encoding surface onto format(); deprecate toX aliases` | §5.8–5.10: `ToolDefinition.format`, full deprecation sweep, `hasTool()`, doc/README/CHANGELOG rewrites. |

Release (after green gate): `git tag -a v1.2.0 -m "v1.2.0"` → workflow publishes → `pana` check.

---

## 5. Detailed Changes

### 5.1 — Root `pubspec.yaml` (C2)

```diff
 environment:
-  sdk: ^3.10.0
+  sdk: ^3.11.0

 dev_dependencies:
-  build_runner: ^2.4.0
+  build_runner: ^2.15.0
+  lints: {resolved latest major}   # via `dart pub add dev:lints`
```

Rationale: example already demands 3.11; raising (not lowering) per owner decision. `build_runner`
aligned with example's pin — dev-only, zero consumer impact. Verify `pub get` resolves cleanly.

### 5.2 — `example/pubspec.yaml` (C2)

Unchanged except: mirror root's `lints` dev_dep. SDK stays `^3.11.0`.

### 5.3 — New `analysis_options.yaml` (root + copy in `example/`) (C2)

```yaml
include: package:lints/recommended.yaml
```

Minimal by design — no strict-casts/inference/raw-types this pass. Mechanical lint fallout
(unused imports, missing overrides) fixes in C2; structural findings deferred and listed in PR
description — never silently suppressed.

### 5.4 — New `lib/src/json_types.dart` (C3)

```dart
/// A JSON object passed to or produced by tool schema APIs.
typedef JsonObject = Map<String, Object?>;

/// A JSON array passed to or produced by tool schema APIs.
typedef JsonArray = List<Object?>;
```

Verbatim move of definitions at lib/src/tool_registry.dart:8-11 (docs preserved).

### 5.5 — Per-file import surgery (C3)

| File | Change |
|------|--------|
| `lib/src/tool_registry.dart` | Delete local typedefs (:8-11) → `import 'json_types.dart';` **plus `export 'json_types.dart';`** (back-compat via public barrel). Cache `schemas` (§5.6). |
| `lib/src/tool_schema_collection.dart` | Drop `tool_registry.dart` (:4) → `import 'json_types.dart';`. **Cycle A broken.** |
| `lib/src/tool_schema.dart` | Drop `tool_registry.dart` (:3) → `import 'json_types.dart';`. |
| `lib/src/tool_definition.dart` | Drop `tool_registry.dart` (:3) → `import 'json_types.dart';`; drop `tool_schema.dart` (:4), then re-add solely for the `.schema` getter — the definition↔schema wrapper pair references each other inherently (REV 2 CORRECTION: cycle B cannot close without removing public API; only its *accidental* edges are removed). |
| `lib/src/tool_parser.dart:5` | Barrel import → `import 'annotations.dart';` (grep first: only `SchemaFormat` consumed). |
| `lib/src/tool_spec.dart:2` | Same replacement (`SchemaFormat` in `formats` field). |

### 5.6 — Cheap memoization (C3, the one endorsed perf item)

```dart
// tool_registry.dart — was fresh allocation per read (tool_registry.dart:96):
late final ToolSchemaCollection schemas = ToolSchemaCollection(_tools.values);

// tool_schema_collection.dart:
final Map<SchemaFormat, List<JsonObject>> _formatCache = {};

List<JsonObject> format(SchemaFormat format) =>
    _formatCache.putIfAbsent(
      format,
      () => List.unmodifiable(_tools.map((t) => t.encode(format))),
    );
```

Safety: `ToolRegistry._tools` has no public mutators (`extend`/`+` build new instances);
memoization cannot go stale.

### 5.7 — `SchemaFormat.mcp` + single-source wire shapes (C4a)

**(a) annotations.dart** — extend the enum:

```dart
enum SchemaFormat {
  openAi,     // OpenAI function tool shape
  anthropic,  // Anthropic tool shape
  gemini,     // Gemini function declaration shape
  mcp,        // Model Context Protocol tool shape
}
```

> ⚠️ Semver note: adding an enum constant breaks consumer code with *exhaustive* switches over
> `SchemaFormat`. Accepted deliberately while 1.2.0 is unreleased; called out in CHANGELOG (§5.10)
> and the README migration section so downstream sees it before upgrading.

**(b) tool_definition.dart** — `encode()`'s switch gains the fourth arm, becoming the single
source of every wire shape (replaces the hand-built map previously delegated to `ToolSchema`):

```dart
JsonObject encode([SchemaFormat format = SchemaFormat.openAi]) =>
    switch (format) {
      SchemaFormat.openAi    => Map<String, Object?>.unmodifiable(this),
      SchemaFormat.anthropic => {
        'name': name,
        if (description.isNotEmpty) 'description': description,
        'input_schema': parametersSchema,
        if (strict) 'strict': true,
      },
      SchemaFormat.gemini    => {
        'name': name,
        if (description.isNotEmpty) 'description': description,
        'parameters': parametersSchema,
      },
      SchemaFormat.mcp       => {
        'name': name,
        if (description.isNotEmpty) 'description': description,
        'inputSchema': parametersSchema,   // camelCase per MCP spec; no `strict` key
      },
    };
```

Output-parity requirement: the `mcp` arm must produce **byte-identical JSON keys** to the old
hand-built implementations (verified by existing tests + golden run). Drop the now-redundant
`tool_schema.dart` import here → **cycle B fully closed**.

**(c) Delegation cleanup** (aliases keep their exact old output, now via the shared path):

| Site | Becomes |
|------|---------|
| `ToolDefinition.toMcpSchema()` body | `=> encode(SchemaFormat.mcp);` |
| `ToolSchema.toMcp()` body | `=> _tool.encode(SchemaFormat.mcp);` |
| `ToolSchemaCollection.toMcp()` body | `=> format(SchemaFormat.mcp);` |
| `ToolRegistry.toMcpSchemas()` body | unchanged (already routes through `schemas`) |

### 5.8 — Canonical `format()` + surface consolidation (C4b) — REV 3: removal, not deprecation

**Owner decision:** every `.toX` variant was introduced by *unreleased* 1.2.0 previews —
deprecation ceremony without value. They are **removed outright**, so no release ever ships them.
Only members that shipped in ≤1.1.0 (verified against baseline `4c7d47e`) carry `@Deprecated`.

**(a) Canonical members added:** `ToolDefinition.format(SchemaFormat)` (required-positional,
matching siblings), `ToolRegistry.hasTool(String)`.

**(b) REMOVED (never published):**

| Class | Removed members |
|-------|-----------------|
| `ToolRegistry` | `toGeminiSchemas()`, `toAnthropicSchemas()`, `toOpenAiSchemas()`, `toMcpSchemas()` |
| `ToolDefinition` | `toGeminiSchema()`, `toAnthropicSchema()`, `toOpenAiSchema()`, `toMcpSchema()` |
| `ToolSchema` | `toGemini()`, `toAnthropic()`, `toOpenAi()`, `toMcp()`, `toJson()`, `toMap()` |
| `ToolSchemaCollection` | `toGemini()`, `toAnthropic()`, `toOpenAi()`, `toMcp()`, `raw` |

**(c) DEPRECATED (shipped ≤1.1.0; bodies intact until 2.0):**

| Member | `@Deprecated` replacement text |
|--------|-------------------------------|
| `ToolRegistry.encode({name, format})` | `Use tools[name].format(...) for a single tool or tools.schemas.format(...) for all tools.` — doc notes it remains the only formats-filtering path |
| `ToolRegistry.encoded` | `Use tools.schemas.format(.openAi).` |
| `ToolRegistry.allSchemas` | message updated → `Use tools.schemas.format(.openAi) instead.` |
| `ToolDefinition.encode([f])` | `Use format(SchemaFormat) — e.g. format(.gemini).` |

Same-library deprecation references are analyzer-exempt (`format()` delegates to `encode()`).

**(d) Behavioral note:** `schemas.format(...)` does **not** filter by each tool's declared
`formats:` list (deprecated `registry.encode(format:)` does). Documented in README + dartdoc;
restriction story = declare via `@Tool(formats:)`.

### 5.9 — Generated-code & internal doc updates (C4b)

1. **lib/src/tool_schema_generator.dart:91-95** — emitted registry doc comment changes from
   `Use [tools.toGeminiSchemas()]...` to `Use [tools.schemas.format] (e.g. tools.schemas.format(.gemini))
   and [tools.call] to dispatch.` → golden output differs **only** in doc-comment lines (expected;
   gate adjusted in §7).
2. **Class docstring** tool_registry.dart:31-48 — rewrite usage block to the §3 canonical forms.
3. **Tests** — migrate call sites off deprecated members onto `format(.x)` (dogfoods the new
   idiom; keeps CI analyzer-clean). Existing assertions on wire shapes stay byte-for-byte.

### 5.10 — Documentation (C2 pins + C4b surface)

1. **README.md** — install snippet `^1.0.0` → `^1.2.0`; unify `build_runner` guidance to `^2.15.0`;
   repair garbled `<FUNCTION_NAME>` sentence; **rewrite every encoding example to `format(.x)`**;
   add "Migrating from toX helpers" table mirroring §5.8(b); add `SchemaFormat.mcp` to feature list.
2. **CHANGELOG.md under `## 1.2.0`** —

```markdown
### Added
* `SchemaFormat.mcp` — MCP tool shape now flows through `format(...)` like every other provider.

### Changed
* Minimum Dart SDK raised from 3.10 to **3.11**.
* `ToolDefinition` gains `format(SchemaFormat)`; MCP output is produced by the same encoder
  as all providers (single source of truth).
* ⚠️ Adding `SchemaFormat.mcp` breaks exhaustive `switch` statements over `SchemaFormat`;
  add a `mcp` case (or default) when upgrading.

### Deprecated
* All provider-named aliases (`toGemini*`, `toAnthropic*`, `toOpenAi*`, `toMcp*`, `raw`,
  `encoded`, `encode(...)`, `allSchemas`, `toJson`/`toMap`) — use
  `format(SchemaFormat.xxx)` / dot-shorthand `format(.gemini)`. Removal in 2.0.
```

3. **README "Migrating to 1.2.0"** — latest-only migration section placed at the end of
   README (before Contributing); MIGRATION.md deleted (owner decision: single, current
   migration home).

---

## 6. Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Generated `.g.dart` drifts in C3 | Low | Golden diff must be empty post-C3 build |
| Generated output drifts in C4a/C4b | Expected | Diff limited to doc-comment lines — reviewed manually (§5.9.1) |
| `SchemaFormat.mcp` breaks consumer exhaustive switches | Medium (by design) | CHANGELOG ⚠️ + README migration entry; accepted pre-release |
| MCP arm diverges from legacy hand-built map | Low | Key-by-key parity asserted in existing tests before/after C4a |
| `late final schemas` semantics if registry ever mutable | Very low | Comment on field; revisit if mutation API added |
| Re-export miss breaks `JsonObject` consumers | Low | Explicit `export 'json_types.dart';`; suite catches |
| Lint flood turns CI red | Medium | Mechanical fixes in C2; nothing silently suppressed |
| Stale README/test references to `.toX` | Low | Gate grep below fails the build |

## 7. Verification Gate

After **C1–C3** (blocking):
```sh
dart analyze && cd example && dart analyze
dart test
cd example && dart run build_runner build --delete-conflicting-outputs
git diff --exit-code -- example/lib/tools.g.dart        # golden: byte-identical
dart format --output=none --set-exit-if-changed lib test example/lib
```

After **C4a/C4b** (blocking):
```sh
dart analyze && dart test                                # zero warnings incl. tests
cd example && dart run build_runner build --delete-conflicting-outputs
git diff -- example/lib/tools.g.dart                     # doc-comment lines ONLY
rg -n "to(Gemini|Anthropic|OpenAi|Mcp)|\.encode\(|\.encoded|\ballSchemas|\bschemas\.raw\b|\btoJson\(|\btoMap\(" \
   README.md example/lib example/README.md               # hits allowed only inside deprecation/migration prose
rg -n "Deprecated" lib | wc -l                           # ≥ 24 annotated members present
```

## 8. Release Procedure

1. All commits pushed; both gates green on HEAD.
2. `git tag -a v1.2.0 -m "tool_schema_generator 1.2.0"` && push tag → triggers publish workflow
   (first-ever live validation, closes F2).
3. Confirm publish success on pub.dev / Actions log.
4. `dart pub global activate pana && pana` → score uplift sanity check (F3 fix).
