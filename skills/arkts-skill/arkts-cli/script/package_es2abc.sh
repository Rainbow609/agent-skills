#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 /abs/path/to/es2abc [/abs/path/to/lib-dir]" >&2
  exit 1
fi

SOURCE_BIN=$(realpath "$1")
SOURCE_LIB_DIR=""
if [[ $# -eq 2 ]]; then
  SOURCE_LIB_DIR=$(realpath "$2")
fi

TARGET_ROOT="${ROOT_DIR}/runtime/ark/es2abc/linux"
TARGET_BIN_DIR="${TARGET_ROOT}/bin"
TARGET_LIB_DIR="${TARGET_ROOT}/lib"

mkdir -p "${TARGET_BIN_DIR}" "${TARGET_LIB_DIR}"
cp -f "${SOURCE_BIN}" "${TARGET_BIN_DIR}/es2abc"
chmod +x "${TARGET_BIN_DIR}/es2abc"

if [[ -n "${SOURCE_LIB_DIR}" ]]; then
  find "${TARGET_LIB_DIR}" -mindepth 1 -maxdepth 1 -type f -delete
  while IFS= read -r lib; do
    cp -f "${lib}" "${TARGET_LIB_DIR}/"
  done < <(find "${SOURCE_LIB_DIR}" -maxdepth 1 -type f \( -name '*.so' -o -name '*.so.*' \))
fi

echo "Packaged es2abc into ${TARGET_ROOT}"
