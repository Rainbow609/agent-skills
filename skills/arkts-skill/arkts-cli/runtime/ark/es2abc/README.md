`arkts-cli` packages `es2abc` as a self-contained runtime dependency.

Expected layout:

- `linux/bin/es2abc`
- `linux/lib/*` optional dependent shared libraries
- `mac/bin/es2abc`
- `mac/lib/*` optional dependent shared libraries
- `win/bin/es2abc.exe`
- `win/lib/*` optional dependent shared libraries

Populate these directories from a built OpenHarmony output tree, for example:

- `out/<product>/clang_x64/arkcompiler/ets_frontend/es2abc` -> `linux/bin/es2abc`

If the executable depends on additional shared libraries, copy them into the matching `lib` directory.
