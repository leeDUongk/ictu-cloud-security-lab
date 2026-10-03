#!/usr/bin/env bash
# Xoá tài nguyên của Bài 4: VM của các user, ACL đã thêm, user, group, template cirros-dev.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

STATE="$HERE/.state"

require_root_sudo
require_cmd xmllint

# 1. VM thuộc các user bài này
for u in alice bob auditor; do
  user_exists "$u" || continue
  mapfile -t vms < <(one onevm list -x | xmllint --xpath "//VM[UNAME='$u']/NAME/text()" - 2>/dev/null | tr ' ' '\n' || true)
  for n in "${vms[@]}"; do
    [[ -n "$n" ]] || continue
    one onevm terminate --hard "$n"
    wait_vm_gone "$n"
  done
done

# 2. ACL đã tạo
if [[ -s "$STATE" ]]; then
  while read -r id; do
    [[ -n "$id" ]] && { one oneacl delete "$id" || log_info "ACL $id không còn."; }
  done < "$STATE"
  rm -f "$STATE"
fi

# 3. Template, user, group
if template_exists "$CIRROS_DEV_TMPL"; then one onetemplate delete "$CIRROS_DEV_TMPL"; fi
for u in alice bob auditor; do
  if user_exists "$u"; then one oneuser delete "$u"; fi
done
for g in dev audit; do
  if group_exists "$g"; then one onegroup delete "$g"; fi
done

log_info "Đã xoá tài nguyên Bài 4."
