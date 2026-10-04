#!/usr/bin/env bash
# Bài 3 — kiểm tra sinh viên đã điền đủ các mục trong file báo cáo. Exit code = số mục thiếu.
# Dùng: bash bai03-iaas/check.sh <đường dẫn file báo cáo .md>
#   (file báo cáo nằm trong tài liệu lab của sinh viên, không nằm trong repo này)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

REPORT="${1:-}"
[[ -n "$REPORT" ]] || die "Thiếu đường dẫn file báo cáo. Dùng: bash bai03-iaas/check.sh <file báo cáo .md>"
SECTIONS=(
  "## 1."
  "## 2."
  "## 3."
  "## 4."
  "## 5."
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
