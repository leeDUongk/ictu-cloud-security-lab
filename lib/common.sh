#!/usr/bin/env bash
# shellcheck shell=bash
# =====================================================================
# lib/common.sh — hàm dùng chung cho các script kiểm tra.
# Cách dùng trong script bài:
#   HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$HERE/../lib/common.sh"
# =====================================================================

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set -a
# shellcheck source=lab.env
source "$LIB_DIR/lab.env"
set +a

# ---------------------------------------------------------------------
# Log + đếm FAIL (check.sh dùng finish_check để trả exit code = số FAIL)
# ---------------------------------------------------------------------
FAILS=0
if [[ -t 1 ]]; then
  C_OK=$'\033[32m'; C_FAIL=$'\033[31m'; C_INFO=$'\033[36m'; C_OFF=$'\033[0m'
else
  C_OK=''; C_FAIL=''; C_INFO=''; C_OFF=''
fi

log_info() { printf '%s[INFO]%s %s\n' "$C_INFO" "$C_OFF" "$*"; }
log_ok()   { printf '%s[PASS]%s %s\n' "$C_OK" "$C_OFF" "$*"; }
log_fail() { printf '%s[FAIL]%s %s\n' "$C_FAIL" "$C_OFF" "$*"; FAILS=$((FAILS + 1)); }
die()      { printf '%s[LỖI]%s %s\n' "$C_FAIL" "$C_OFF" "$*" >&2; exit 1; }

# check "mô tả" lệnh...   → PASS nếu lệnh thành công
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then log_ok "$d"; else log_fail "$d"; fi; }

finish_check() {
  local n=$FAILS
  echo
  if (( n == 0 )); then
    log_ok "Tất cả tiêu chí đạt."
  else
    log_fail "Có $n tiêu chí chưa đạt."
  fi
  exit $(( n > 255 ? 255 : n ))
}

# ---------------------------------------------------------------------
# Tiền điều kiện
# ---------------------------------------------------------------------
require_root_sudo() {
  (( EUID != 0 )) || die "Hãy chạy bằng user thường có sudo, không chạy trực tiếp bằng root."
  sudo -n true 2>/dev/null || sudo -v || die "User hiện tại không có quyền sudo."
}

require_cmd() {
  local c missing=()
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  (( ${#missing[@]} == 0 )) || die "Thiếu lệnh: ${missing[*]} (cài: sudo apt install -y libxml2-utils curl)"
}

# ---------------------------------------------------------------------
# OpenNebula CLI chạy dưới oneadmin (dùng ~oneadmin/.one/one_auth)
#   one onevm list
# ---------------------------------------------------------------------
one() { sudo -u oneadmin -H "$@"; }

# one_xpath <xpath> <lệnh onexxx show/list ... -x> — in giá trị chuỗi, rỗng nếu lỗi
#   one_xpath /HOST/STATE onehost show -x 0
one_xpath() {
  local xp="$1"
  shift
  { one "$@" 2>/dev/null | xmllint --xpath "string($xp)" - 2>/dev/null; } || true
}

# ---------------------------------------------------------------------
# REPORT.md: mục có nội dung thật (không chỉ là placeholder)?
#   report_section_filled REPORT.md "## 1."
# ---------------------------------------------------------------------
report_section_filled() {
  local file="$1" head="$2" n
  [[ -f "$file" ]] || return 1
  n="$(awk -v h="$head" '
        index($0, h) == 1 { on = 1; next }
        /^## / { on = 0 }
        on && !/^_\(điền/ && !/^<!--.*-->$/ { gsub(/[[:space:]]/, ""); printf "%s", $0 }
      ' "$file" | wc -c)"
  (( n >= 20 ))
}
