#!/usr/bin/env bash
# Cài OpenNebula miniONE (Front-end + KVM) trên VM ONE-Lab.
# Chạy: bash 01-minione/install.sh      (user thường có sudo)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

LOG="$HOME/minione-install.log"
MINIONE_URL="https://github.com/OpenNebula/minione/releases/download/v${ONE_VERSION}/minione"
MINIONE_BIN="$HOME/minione"

require_root_sudo
require_cmd curl grep

# --- Tiền điều kiện -----------------------------------------------------
. /etc/os-release
[[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]] \
  || die "Cần Ubuntu 24.04 (hiện tại: ${PRETTY_NAME:-không rõ})."

if (( $(grep -c -E 'vmx|svm' /proc/cpuinfo) == 0 )) || [[ ! -e /dev/kvm ]]; then
  cat <<'EOF'
[LỖI] VM chưa bật ảo hoá lồng (không có vmx/svm hoặc không có /dev/kvm).
  Hyper-V (PowerShell Administrator, tắt VM trước):
    Set-VMProcessor -VMName ONE-Lab -ExposeVirtualizationExtensions $true
    Set-VMNetworkAdapter -VMName ONE-Lab -MacAddressSpoofing On
  VMware: tích "Virtualize Intel VT-x/EPT or AMD-V/RVI" trong Processors (xem 00-host/VMWARE.md).
Sau đó bật VM và chạy lại script này.
EOF
  exit 1
fi

# --- Tải miniONE (ghim phiên bản) ---------------------------------------
if [[ ! -s "$MINIONE_BIN" ]]; then
  log_info "Tải miniONE v${ONE_VERSION}..."
  curl -fL -o "$MINIONE_BIN" "$MINIONE_URL"
fi

# --- Chọn cờ theo đúng bản miniONE tải về --------------------------------
HELP="$(bash "$MINIONE_BIN" --help 2>&1 || true)"
args=(--password "$ONEADMIN_PASSWORD")
if grep -q -e '--yes' <<<"$HELP"; then
  args+=(--yes)
else
  log_info "Bản miniONE này không có cờ --yes; script có thể hỏi xác nhận."
fi
grep -q -e '--password' <<<"$HELP" || die "miniONE không có cờ --password. Xem: bash $MINIONE_BIN --help"

# --- Chờ khóa apt (Ubuntu Desktop hay chạy cập nhật nền bằng aptd/unattended-upgrades) ---
# Nếu khóa đang bị giữ, bước "Install docker" của miniONE sẽ thất bại.
sudo systemctl stop unattended-upgrades 2>/dev/null || true
log_info "Chờ khóa apt được giải phóng (tối đa 10 phút)..."
for _ in $(seq 1 120); do
  if ! sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1; then
    break
  fi
  sleep 5
done
if sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1; then
  die "Khóa apt vẫn đang bị giữ sau 10 phút. Đợi cập nhật nền kết thúc (hoặc khởi động lại VM) rồi chạy lại."
fi

log_info "Cài đặt (10–20 phút). Log: $LOG"
# Cờ thêm truyền thẳng cho miniONE, ví dụ: bash 01-minione/install.sh --force
sudo bash "$MINIONE_BIN" "${args[@]}" "$@" 2>&1 | tee "$LOG"

log_info "Xong. Kiểm tra: bash 01-minione/check.sh"
log_info "Đăng nhập Sunstone: http://$VM_LAB_IP/  (oneadmin / $ONEADMIN_PASSWORD)"
