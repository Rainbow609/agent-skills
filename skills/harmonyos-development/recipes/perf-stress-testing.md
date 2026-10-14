# Recipe: HarmonyOS Performance Stress Testing (Jank / Large-List Investigation)

Use this recipe when the user reports UI jank, frame drops, or slow lists that only appear with large
data sets (hundreds/thousands of items), and asks for E2E reproduction, instrumentation, or a
debug/release instrumentation strategy.

## Official grounding (verified against the DevEco knowledge base)

- HiTraceMeter (`@ohos.hiTraceMeter`: `startSyncTrace` / `finishSyncTrace` / `traceByValue`,
  gated by `hiTraceMeter.isTraceEnabled`) is the official instrumentation API.
- **ArkTS has NO conditional compilation** (no `#ifdef`, no preprocessor). The only official
  build-parameter mechanism is `BuildProfile` / `buildProfileFields`, documented as
  **runtime** access to build parameters.
- The sanctioned extension point for custom build logic is a custom Hvigor plugin
  (`hvigorfile.ts` script or TypeScript plugin project).
- ArkGuard obfuscation renames identifiers; it does **not** strip dead code.

## Steps

1. **Instrument first, with a runtime gate.** Wrap every probe site in `if (DEBUG) { ... }`
   using a named const import:

   ```ts
   import { DEBUG } from 'BuildProfile';
   if (DEBUG) { ShelfTracer.syncBegin('shelf.refreshBookshelfData'); }
   ```

2. **Log level pitfall:** on log/eng (HVD emulator) builds, hilog thresholds are at INFO —
   COMMERCIAL-level trace/print may be silently dropped. Instrument with INFO while testing
   on such devices; re-evaluate levels before production.

3. **Seed stress data programmatically** (idempotent seeder triggered via
   `hdc shell aa start -b <bundle> -a EntryAbility --pi <key> <count>`). Mind the app's own
   grouping rules when naming seed files (e.g. a strip-volume-suffix pass can merge distinct
   numeric filenames into one card — make seed names unique and letter-terminated).

4. **E2E drive the UI** with `hdc shell uitest uiInput fling <x1> <y1> <x2> <y2> <speed>` plus
   slow `swipe` passes; 10–12 flings at ~1.2s intervals reproduce steady-state scrolling.

5. **Capture evidence:**
   - `hdc shell hitrace --trace_begin app` → drive → `hitcace --trace_dump` to a local file
     (run `--trace_finish` after; beware `grep -c` returning 0 breaking `&&` chains).
   - hilog windows for duration lines from the instrumentation.

6. **Correlate:** align trace slices (`C|H:<name>`) with jank frames (look for
   `JANK_FRAME_UNFILTERED`, frame times > 32ms). Batch appends of heavily decorated cards
   interleaving with 50–200ms frames is the classic LazyVGrid load-more signature.

7. **Verify debug/release packaging separately:**
   - debug: `strings ets/modules.abc | grep -c <ProbeClass>` > 0 confirms instrumentation compiled in.
   - release: disassemble with `ark_disasm` (in SDK `toolchains/`) and confirm the probe call
     sites are gone or reduced to a constant-false branch.

## Release packaging: what "stripping" actually means

Empirically verified on the API 23 toolchain:

- Default class import (`BuildProfile.DEBUG` via default import) survives into release bytecode
  with a property lookup per call site — worst option.
- Named const import (`import { DEBUG }`) removes the property lookup but the compiler does
  **not** constant-fold across modules: release keeps
  `ldexternalmodulevar DEBUG; isfalse; jnez <skip>` — a runtime branch that is always false.
- So the achievable ceiling without custom build plumbing is **zero runtime side effects**
  (one external-var load + never-taken branch per probe site), with probe bytecode still
  present in the package.
- True physical removal requires a custom Hvigor plugin that excludes the probe source files
  per buildMode. Only build this if bytecode content itself is a hard requirement
  (security audit, trace-name confidentiality); otherwise ship the runtime gate.

## Response format

- Repro environment (device/emulator, build mode, seeded count) + caveat that HVD emulator
  numbers need on-device confirmation (no GLES 3.1, unrepresentative performance).
- Evidence table (probe durations vs data-set size; jank-frame distribution; batch-vs-jank
  timeline correlation).
- Root causes ranked P0/P1 with fix directions (incremental refresh, move assembly off the
  main thread, reduce batch size / cachedCount, flatten card decoration).
- Packaging verdict: what the release build actually contains, verified via disassembly.
