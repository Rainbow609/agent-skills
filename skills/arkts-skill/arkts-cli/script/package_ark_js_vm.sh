#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 /abs/path/to/ark_js_vm /abs/path/to/lib-dir /abs/path/to/stub.an /abs/path/to/icu-data-dir" >&2
  exit 1
fi

SOURCE_BIN=$(realpath "$1")
SOURCE_LIB_DIR=$(realpath "$2")
SOURCE_STUB=$(realpath "$3")
SOURCE_ICU_DIR=$(realpath "$4")

TARGET_ROOT="${ROOT_DIR}/runtime/ark/jsvm/linux"
TARGET_BIN_DIR="${TARGET_ROOT}/bin"
TARGET_LIB_DIR="${TARGET_ROOT}/lib"
TARGET_DATA_DIR="${TARGET_ROOT}/data"

mkdir -p "${TARGET_BIN_DIR}" "${TARGET_LIB_DIR}" "${TARGET_DATA_DIR}"

cp -f "${SOURCE_BIN}" "${TARGET_BIN_DIR}/ark_js_vm"
chmod +x "${TARGET_BIN_DIR}/ark_js_vm"

find "${TARGET_LIB_DIR}" -mindepth 1 -maxdepth 1 -type f -delete
while IFS= read -r lib; do
  cp -f "${lib}" "${TARGET_LIB_DIR}/"
done < <(find "${SOURCE_LIB_DIR}" -maxdepth 1 -type f \( -name '*.so' -o -name '*.so.*' \))
cp -f "${SOURCE_STUB}" "${TARGET_LIB_DIR}/stub.an"

find "${TARGET_DATA_DIR}" -mindepth 1 -maxdepth 1 -type f -delete
while IFS= read -r data; do
  cp -f "${data}" "${TARGET_DATA_DIR}/"
done < <(find "${SOURCE_ICU_DIR}" -maxdepth 1 -type f -name '*.dat')

echo "Packaged ark_js_vm into ${TARGET_ROOT}"
