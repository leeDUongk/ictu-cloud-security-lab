#!/usr/bin/env bash
# Kiểm tra miniONE đã cài đúng. Exit code = số tiêu chí FAIL.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

require_cmd xmllint curl

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$1" || true; }
http_ok()   { [[ "$(http_code "$1")" =~ ^(200|301|302)$ ]]; }

check "Dịch vụ opennebula đang chạy"           systemctl is-active --quiet opennebula
check "Dịch vụ opennebula-fireedge đang chạy"  systemctl is-active --quiet opennebula-fireedge
check "Host 0 ở trạng thái on (MONITORED)"     test "$(one_xpath /HOST/STATE onehost show -x 0)" = "2"
check "Có ít nhất một virtual network"         test "$(one onevnet list -x | xmllint --xpath 'count(//VNET)' -)" -ge 1
check "Bridge minionebr có IP $LAB_GATEWAY"    bash -c "ip -4 addr show '$LAB_BRIDGE' | grep -q '$LAB_GATEWAY'"

if http_ok "http://localhost/" || http_ok "http://localhost:2616/"; then
  log_ok "Giao diện web trả 200/301/302 (cổng 80 hoặc 2616)"
else
  log_fail "Giao diện web không phản hồi (cổng 80, 2616)"
fi

finish_check
