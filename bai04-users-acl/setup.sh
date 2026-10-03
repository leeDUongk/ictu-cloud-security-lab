#!/usr/bin/env bash
# Bài 4 — Người dùng, nhóm, quota, ACL. Chạy lại không lỗi. Cần Bài 3 đã chạy.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

STATE="$HERE/.state"        # lưu ID các ACL đã tạo (reset.sh dùng lại)

require_root_sudo
require_cmd xmllint envsubst

image_exists "$CIRROS_IMG" && template_exists "$CIRROS_TMPL" && vnet_exists "$LAB_NET" \
  || die "Thiếu image/template/vnet của Bài 3. Hãy chạy: bash bai03-iaas/setup.sh"

# 1. Nhóm
for g in dev audit; do
  if group_exists "$g"; then log_info "Group '$g' đã tồn tại."; else one onegroup create "$g"; fi
done
GID_DEV="$(one_id onegroup GROUP dev)"
GID_AUDIT="$(one_id onegroup GROUP audit)"

# 2. User (tên:mật khẩu:nhóm)
create_user() {
  local name="$1" pass="$2" grp="$3" f
  if user_exists "$name"; then
    log_info "User '$name' đã tồn tại."
  else
    one oneuser create "$name" "$pass"
  fi
  one oneuser chgrp "$name" "$grp"
  f="$(lab_tmpfile "attr-$name.txt")"
  printf 'DEPARTMENT="IT"\nEMAIL="%s@lab.local"\n' "$name" > "$f"
  one oneuser update "$name" --append "$f"
}
create_user alice   "$ALICE_PASSWORD"   dev
create_user bob     "$BOB_PASSWORD"     dev
create_user auditor "$AUDITOR_PASSWORD" audit

# alice là admin của group dev
one onegroup addadmin dev alice 2>/dev/null || log_info "alice đã là admin của dev."

# 3. Quota cho bob
one oneuser quota bob "$HERE/files/quota-dev.txt"

# 4. Chia sẻ tài nguyên để user khác dùng được
#    (VM của user tham chiếu image/vnet của oneadmin nên cần quyền USE; 644 = USE cho group và other)
one onetemplate chmod "$CIRROS_TMPL" 644
one oneimage chmod "$CIRROS_IMG" 644
one onevnet chmod "$LAB_NET" 644
if template_exists "$CIRROS_DEV_TMPL"; then
  log_info "Template '$CIRROS_DEV_TMPL' đã tồn tại."
else
  f="$(lab_tmpfile cirros-dev.tmpl)"
  render_tmpl "$HERE/files/cirros-dev.tmpl" "$f"
  one onetemplate create "$f"
fi
one onetemplate chmod "$CIRROS_DEV_TMPL" 644

# 5. ACL (chỉ tạo một lần; ID lưu trong .state)
if [[ -s "$STATE" ]]; then
  log_info "ACL đã tạo trước đó (ID: $(tr '\n' ' ' < "$STATE"))."
else
  acl_create() {
    local out id
    out="$(one oneacl create "$1")"
    id="$(grep -oE '[0-9]+' <<<"$out" | tail -n1)"
    [[ -n "$id" ]] || die "Không đọc được ID ACL từ: $out"
    echo "$id" >> "$STATE"
  }
  acl_create "@$GID_DEV VM+IMAGE+TEMPLATE/@$GID_DEV USE+MANAGE+CREATE"
  acl_create "@$GID_AUDIT VM+IMAGE+TEMPLATE+NET+HOST/* USE"
fi

log_info "Xong. Kiểm tra: bash bai04-users-acl/check.sh"
