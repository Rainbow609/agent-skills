# linter-cli

Standalone ArkTS linter CLI extracted from `arkts-cli`.

This tool runs ArkTS checker diagnostics only. It does not transform sources, generate `.abc` files, or run `ark_js_vm`.

Example:

```bash
node ./bin/linter-cli.js \
  --input /abs/path/file.ets
```

With an SDK path:

```bash
node ./bin/linter-cli.js \
  --input /abs/path/project/entry/src/main/ets/pages/Index.ets \
  --sdk-path /abs/path/sdk/default/openharmony/ets
```

With a custom cache directory:

```bash
node ./bin/linter-cli.js \
  --input /abs/path/file.ets \
  --cache-dir /abs/path/cache
```

Project context:

- The input remains a single `.ets` file.
- By default, the CLI infers the module root from the path segment before `src/main/ets`.
- The CLI uses the real source file in place. It does not copy `entry/src/main/ets` into a temporary workspace.
- Use `--module-root`, `--project-root`, or `--module-json` only when inference is not enough.

SDK context:

- `--sdk-path` may point to an OpenHarmony ETS SDK root such as `.../openharmony/ets`.
- `--sdk-path` may also point to a parent SDK directory such as `.../sdk/default`; the CLI will look for known `openharmony/ets` and `hms/ets` children.
- Windows paths such as `D:\DevEco Studio\sdk\default\openharmony\ets` are accepted when running under WSL.

Cache directory:

- `--cache-dir` is still used for checker cache and small generated helper files.
- It is no longer used as a copied source workspace.

Output:

- `Lint Check: OK` when checker diagnostics pass
- ArkTS checker diagnostics on stdout/stderr when linter or tsc errors are found

Runtime layout:

- `runtime/compiler`: minimized ArkTS checker runtime and dependencies

Notes:

- `linter-cli` only looks up the compiler runtime through package-relative paths.
- The package does not include `es2abc`, `ark_js_vm`, or packaging scripts from `arkts-cli`.
- Current input is a single `.ets` file path.
