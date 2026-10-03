#!/usr/bin/env bash
# Xoá tài nguyên của Bài 3 (không đụng bài khác; giữ vnet lab-net vì dùng chung).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

require_root_sudo
require_cmd xmllint

if vm_exists "$CIRROS_VM"; then
  one onevm terminate --hard "$CIRROS_VM"
  wait_vm_gone "$CIRROS_VM"
fi
if template_exists "$CIRROS_TMPL"; then one onetemplate delete "$CIRROS_TMPL"; fi
if image_exists "$CIRROS_IMG"; then one oneimage delete "$CIRROS_IMG"; fi
if datastore_exists "$LAB_DS"; then one onedatastore delete "$LAB_DS"; fi

log_info "Đã xoá tài nguyên Bài 3. File tải về $CIRROS_DIR/$CIRROS_FILE được giữ lại để dùng lại."
