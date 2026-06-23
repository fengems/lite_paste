#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf '工作区检查未通过：%s\n' "$1" >&2
  exit 1
}

check_untracked_text_files() {
  local file
  local last_byte
  local grep_output
  local has_error=0

  while IFS= read -r -d '' file; do
    grep_output="$(grep -n -E '[[:blank:]]$' "${file}" || true)"
    if [[ -n "${grep_output}" ]]; then
      printf '%s\n%s\n' "${file}" "${grep_output}" >&2
      has_error=1
    fi

    if [[ -s "${file}" ]]; then
      last_byte="$(tail -c 1 "${file}" | od -An -t x1 | tr -d ' \n')"
      if [[ "${last_byte}" != "0a" ]]; then
        printf '%s: 文件末尾缺少换行\n' "${file}" >&2
        has_error=1
      fi
    fi
  done < <(
    git ls-files --others --exclude-standard -z -- \
      '*.swift' '*.sh' '*.md' '*.yml' '*.yaml' '*.json' '*.plist' '*.txt'
  )

  (( has_error == 0 )) || fail "新增文本文件存在空白格式问题"
}

cd "${ROOT_DIR}"

printf '检查 tracked 文件空白...\n'
git diff --check

printf '检查 staged 文件空白...\n'
git diff --cached --check

printf '检查新增文本文件空白...\n'
check_untracked_text_files

printf '工作区空白检查通过。\n'
