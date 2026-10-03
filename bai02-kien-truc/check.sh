#!/usr/bin/env bash
# Kiểm tra sinh viên đã điền đủ các mục trong REPORT.md. Exit code = số mục thiếu.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

REPORT="$HERE/REPORT.md"
SECTIONS=(
  "## 1."
  "## 2."
  "## 3."
  "## 4."
  "## 5."
  "## 6."
)

[[ -f "$REPORT" ]] || die "Không thấy $REPORT"

for s in "${SECTIONS[@]}"; do
  title="$(grep -m1 -F "$s" "$REPORT" || true)"
  if report_section_filled "$REPORT" "$s"; then
    log_ok "Đã điền: ${title:-$s}"
  else
    log_fail "Chưa điền: ${title:-$s}"
  fi
done

finish_check
