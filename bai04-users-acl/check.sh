#!/usr/bin/env bash
# Kiểm tra Bài 4. Exit code = số tiêu chí FAIL.
# Lưu ý: script tạo rồi để lại VM bob-vm-1, bob-vm-2; chạy lại sẽ tự dọn trước.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

require_root_sudo
require_cmd xmllint

check "Group dev tồn tại"                 group_exists dev
check "Group audit tồn tại"               group_exists audit
check "User alice tồn tại"                user_exists alice
check "User bob tồn tại"                  user_exists bob
check "User auditor tồn tại"              user_exists auditor
check "alice là admin của group dev" \
  test "$(one_xpath /GROUP/ADMINS/ID onegroup show -x dev)" = "$(one_id oneuser USER alice)"
check "Template '$CIRROS_DEV_TMPL' tồn tại" template_exists "$CIRROS_DEV_TMPL"

# Dọn VM của lần kiểm tra trước
for n in bob-vm-1 bob-vm-2 bob-vm-3; do
  if vm_exists "$n"; then one onevm terminate --hard "$n"; wait_vm_gone "$n"; fi
done

# bob: VM thứ 1–2 được tạo, VM thứ 3 bị quota chặn
check      "bob tạo được VM thứ 1" \
  one_as bob "$BOB_PASSWORD" onetemplate instantiate "$CIRROS_DEV_TMPL" --name bob-vm-1
check      "bob tạo được VM thứ 2" \
  one_as bob "$BOB_PASSWORD" onetemplate instantiate "$CIRROS_DEV_TMPL" --name bob-vm-2
check_fail "bob bị quota chặn khi tạo VM thứ 3" \
  one_as bob "$BOB_PASSWORD" onetemplate instantiate "$CIRROS_DEV_TMPL" --name bob-vm-3

# auditor: chỉ xem
check      "auditor liệt kê được VM (onevm list)" \
  one_as auditor "$AUDITOR_PASSWORD" onevm list
check_fail "auditor bị từ chối khi terminate VM của bob" \
  one_as auditor "$AUDITOR_PASSWORD" onevm terminate bob-vm-1
check      "bob-vm-1 vẫn còn sau khi auditor thử xoá" vm_exists bob-vm-1

finish_check
