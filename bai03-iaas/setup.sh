#!/usr/bin/env bash
# Bài 3 — IaaS: image CirrOS, vnet, template, datastore phụ, VM cirros-01. Chạy lại không lỗi.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

require_root_sudo
require_cmd curl xmllint envsubst

# 1. Tải CirrOS vào /var/tmp (đường dẫn an toàn mặc định của datastore;
#    /home/... sẽ bị chặn bởi RESTRICTED_DIRS/SAFE_DIRS)
IMG_PATH="$CIRROS_DIR/$CIRROS_FILE"
if [[ ! -s "$IMG_PATH" ]]; then
  log_info "Tải CirrOS về $IMG_PATH"
  curl -fL -o "$IMG_PATH" "$CIRROS_URL"
fi
chmod 644 "$IMG_PATH"

# 2. Tạo image
if image_exists "$CIRROS_IMG"; then
  log_info "Image '$CIRROS_IMG' đã tồn tại."
else
  one oneimage create --name "$CIRROS_IMG" --path "$IMG_PATH" \
    --datastore default --type OS --driver qcow2 --description "CirrOS 0.6.2 (Bai 3)"
fi
wait_image "$CIRROS_IMG"

# 3. Mạng lab
ensure_lab_net

# 4. Template
if template_exists "$CIRROS_TMPL"; then
  log_info "Template '$CIRROS_TMPL' đã tồn tại."
else
  f="$(lab_tmpfile cirros.tmpl)"
  render_tmpl "$HERE/files/cirros.tmpl" "$f"
  one onetemplate create "$f"
fi

# 5. Datastore phụ (minh hoạ mục 3.3.3)
if datastore_exists "$LAB_DS"; then
  log_info "Datastore '$LAB_DS' đã tồn tại."
else
  f="$(lab_tmpfile lab-ds.tmpl)"
  render_tmpl "$HERE/files/lab-ds.tmpl" "$f"
  one onedatastore create "$f"
fi

# 6. Tạo VM
if vm_exists "$CIRROS_VM"; then
  log_info "VM '$CIRROS_VM' đã tồn tại."
else
  one onetemplate instantiate "$CIRROS_TMPL" --name "$CIRROS_VM"
fi
wait_vm_running "$CIRROS_VM"

cat <<EOF

CirrOS không có one-context và OpenNebula 6.x không cấp DHCP, nên cần đặt IP tay.
Mở VNC của $CIRROS_VM trong Sunstone, đăng nhập (cirros / gocubsgo) rồi chạy:
  sudo ip addr add $IP_CIRROS_01/24 dev eth0
  sudo ip route add default via $LAB_GATEWAY
Sau đó: bash bai03-iaas/check.sh
EOF
