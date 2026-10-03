#!/usr/bin/env bash
# Kiểm tra Bài 3. Exit code = số tiêu chí FAIL.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

require_cmd xmllint

check "Image '$CIRROS_IMG' READY" \
  test "$(one_xpath /IMAGE/STATE oneimage show -x "$CIRROS_IMG")" = "1"
check "vnet '$LAB_NET' tồn tại"            vnet_exists "$LAB_NET"
check "Template '$CIRROS_TMPL' tồn tại"    template_exists "$CIRROS_TMPL"
check "Datastore '$LAB_DS' tồn tại"        datastore_exists "$LAB_DS"
check "VM '$CIRROS_VM' RUNNING" \
  test "$(one_xpath /VM/LCM_STATE onevm show -x "$CIRROS_VM")" = "3"
check "Ping $IP_CIRROS_01 (sau khi đặt IP trong VM)" \
  ping -c 2 -W 2 "$IP_CIRROS_01"

finish_check
