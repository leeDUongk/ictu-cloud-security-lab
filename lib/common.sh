#!/usr/bin/env bash
# shellcheck shell=bash
# =====================================================================
# lib/common.sh — hàm dùng chung cho mọi bài thực hành.
# Cách dùng trong script bài:
#   HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$HERE/../lib/common.sh"
# Lưu ý: file này đặt trap EXIT để dọn thư mục tạm $LAB_TMP.
# =====================================================================

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$LIB_DIR")"

set -a
# shellcheck source=lab.env
source "$LIB_DIR/lab.env"
set +a

umask 022
LAB_TMP="$(mktemp -d)"
chmod 755 "$LAB_TMP"                       # để user oneadmin đọc được file tạm
trap 'rm -rf "$LAB_TMP"' EXIT

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
check()      { local d="$1"; shift; if "$@" >/dev/null 2>&1; then log_ok "$d"; else log_fail "$d"; fi; }
# check_fail "mô tả" lệnh... → PASS nếu lệnh THẤT BẠI (dùng cho kiểm tra bị từ chối)
check_fail() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then log_fail "$d"; else log_ok "$d"; fi; }

finish_check() {
  echo
  if (( FAILS == 0 )); then
    log_ok "Tất cả tiêu chí đạt."
  else
    log_fail "Có $FAILS tiêu chí chưa đạt."
  fi
  exit $(( FAILS > 255 ? 255 : FAILS ))
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
  (( ${#missing[@]} == 0 )) || die "Thiếu lệnh: ${missing[*]} (cài: sudo apt install -y libxml2-utils gettext-base netcat-openbsd curl)"
}

# ---------------------------------------------------------------------
# OpenNebula CLI chạy dưới oneadmin (dùng ~oneadmin/.one/one_auth)
#   one onevm list
# ---------------------------------------------------------------------
one() { sudo -u oneadmin -H "$@"; }

# one_as <user> <pass> <lệnh...> — chạy CLI dưới một user OpenNebula khác (qua ONE_AUTH tạm)
one_as() {
  local user="$1" pass="$2" f
  shift 2
  f="$LAB_TMP/auth_$user"
  printf '%s:%s\n' "$user" "$pass" > "$f"
  chmod 644 "$f"
  sudo -u oneadmin -H env ONE_AUTH="$f" "$@"
}

# one_xpath <xpath> <lệnh onexxx show/list ... -x> — in giá trị chuỗi, rỗng nếu lỗi
#   one_xpath /IMAGE/STATE oneimage show -x cirros-0.6.2
one_xpath() {
  local xp="$1"
  shift
  { one "$@" 2>/dev/null | xmllint --xpath "string($xp)" - 2>/dev/null; } || true
}

# one_id <lệnh> <PHẦN_TỬ_XML> <tên> — in ID theo tên, rỗng nếu không có
#   one_id onegroup GROUP dev
one_id() {
  { one "$1" list -x 2>/dev/null | xmllint --xpath "string(//$2[NAME='$3']/ID)" - 2>/dev/null; } || true
}

_has() { [[ -n "$(one_id "$@")" ]]; }
vm_exists()       { _has onevm VM "$1"; }
image_exists()    { _has oneimage IMAGE "$1"; }
template_exists() { _has onetemplate VMTEMPLATE "$1"; }
vnet_exists()     { _has onevnet VNET "$1"; }
user_exists()     { _has oneuser USER "$1"; }
group_exists()    { _has onegroup GROUP "$1"; }
datastore_exists(){ _has onedatastore DATASTORE "$1"; }

# ---------------------------------------------------------------------
# Template: thay ${BIẾN} bằng giá trị môi trường (chỉ các biến có trong file)
#   render_tmpl nguồn.tmpl đích
#   lab_tmpfile tên → in đường dẫn file tạm trong $LAB_TMP
# ---------------------------------------------------------------------
lab_tmpfile() { printf '%s/%s\n' "$LAB_TMP" "$1"; }

render_tmpl() {
  local src="$1" dst="$2" vars
  vars="$(grep -o '\${[A-Za-z_0-9]*}' "$src" | sort -u | tr '\n' ' ' || true)"
  envsubst "$vars" < "$src" > "$dst"
  chmod 644 "$dst"
}

# ---------------------------------------------------------------------
# SSH
# ---------------------------------------------------------------------
ensure_ssh_key() {
  local k="$HOME/.ssh/id_ed25519"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  [[ -f "$k" ]] || ssh-keygen -t ed25519 -N '' -f "$k" -C "lab@$(hostname)" >/dev/null
  cat "$k.pub"
}

# lab_ssh <ip> [lệnh...] — SSH root vào VM khách bằng key lab
lab_ssh() {
  local ip="$1"
  shift
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR -o ConnectTimeout=5 "root@$ip" "$@"
}

# ---------------------------------------------------------------------
# Chờ trạng thái
# ---------------------------------------------------------------------
# wait_image <tên> [timeout_giây=900] — STATE: 1=READY, 4=LOCKED, 5=ERROR
wait_image() {
  local name="$1" timeout="${2:-900}" t=0 st
  while (( t < timeout )); do
    st="$(one_xpath /IMAGE/STATE oneimage show -x "$name")"
    case "$st" in
      1) log_info "Image '$name' đã READY."; return 0 ;;
      5) die "Image '$name' ở trạng thái ERROR (xem: onevm/oneimage show, /var/log/one/oned.log)." ;;
    esac
    sleep 5
    t=$((t + 5))
  done
  die "Hết thời gian chờ image '$name' (${timeout}s)."
}

# wait_vm_running <tên> [timeout_giây=300] — LCM_STATE 3 = RUNNING
wait_vm_running() {
  local name="$1" timeout="${2:-300}" t=0
  while (( t < timeout )); do
    [[ "$(one_xpath /VM/LCM_STATE onevm show -x "$name")" == "3" ]] && { log_info "VM '$name' đang RUNNING."; return 0; }
    [[ "$(one_xpath /VM/STATE onevm show -x "$name")" == "7" ]] && die "VM '$name' ở trạng thái FAILED."
    sleep 5
    t=$((t + 5))
  done
  die "Hết thời gian chờ VM '$name' RUNNING (${timeout}s)."
}

# wait_vm_gone <tên> [timeout_giây=180] — chờ VM biến mất khỏi danh sách (sau terminate)
wait_vm_gone() {
  local name="$1" timeout="${2:-180}" t=0
  while (( t < timeout )); do
    vm_exists "$name" || return 0
    sleep 3
    t=$((t + 3))
  done
  die "VM '$name' vẫn chưa bị xoá sau ${timeout}s."
}

# wait_ssh <ip> [timeout_giây=300] — cổng 22 mở và đăng nhập được bằng key
wait_ssh() {
  local ip="$1" timeout="${2:-300}" t=0
  while (( t < timeout )); do
    if nc -z -w2 "$ip" 22 2>/dev/null && lab_ssh "$ip" true 2>/dev/null; then
      log_info "SSH tới $ip sẵn sàng."
      return 0
    fi
    sleep 5
    t=$((t + 5))
  done
  die "Hết thời gian chờ SSH tới $ip (${timeout}s)."
}

# ---------------------------------------------------------------------
# Tài nguyên dùng chung
# ---------------------------------------------------------------------
# ensure_lab_net — vnet lab-net trên bridge minionebr, AR 172.16.100.200 (50 địa chỉ)
ensure_lab_net() {
  if vnet_exists "$LAB_NET"; then
    log_info "vnet '$LAB_NET' đã tồn tại."
    return 0
  fi
  local f
  f="$(lab_tmpfile lab-net.tmpl)"
  render_tmpl "$LIB_DIR/templates/lab-net.tmpl" "$f"
  one onevnet create "$f"
}

# ensure_ubuntu_image — export Ubuntu 22.04 (ưu tiên) hoặc 24.04 từ Marketplace "OpenNebula Public"
ensure_ubuntu_image() {
  if image_exists "$UBUNTU_IMG"; then
    log_info "Image '$UBUNTU_IMG' đã tồn tại."
    wait_image "$UBUNTU_IMG"
    return 0
  fi
  local list line="" ver id
  list="$(one onemarketapp list -l ID,NAME,MARKET --csv --no-header | grep -i 'OpenNebula Public' \
          | grep -ivE 'lxd|lxc|container|docker|vcenter|oneke|service' || true)"
  for ver in 'Ubuntu 22.04' 'Ubuntu 24.04'; do
    line="$(grep -i "$ver" <<<"$list" | head -n1 || true)"
    [[ -n "$line" ]] && break
  done
  [[ -n "$line" ]] || die "Không tìm thấy appliance Ubuntu 22.04/24.04 trong Marketplace (kiểm tra mạng và: onemarketapp list)."
  id="$(cut -d, -f1 <<<"$line" | tr -d '" ')"
  log_info "Export appliance #$id: $line"
  one onemarketapp export "$id" "$UBUNTU_IMG" -d default
  wait_image "$UBUNTU_IMG"
}

# instantiate_ubuntu <tên_vm> <ip> [extra_context]
#   extra_context là chuỗi chèn vào CONTEXT, bắt đầu bằng dấu phẩy, ví dụ:
#   instantiate_ubuntu web-paas "$IP_WEB_PAAS" $',\n  START_SCRIPT_BASE64="..."'
instantiate_ubuntu() {
  local name="$1" ip="$2" extra="${3:-}" f
  if vm_exists "$name"; then
    log_info "VM '$name' đã tồn tại."
    return 0
  fi
  f="$(lab_tmpfile "$name.tmpl")"
  VM_NAME="$name" VM_IP="$ip" SSH_PUBKEY="$(ensure_ssh_key)" EXTRA_CONTEXT="$extra" \
    render_tmpl "$LIB_DIR/templates/ubuntu-vm.tmpl" "$f"
  one onevm create "$f"
  wait_vm_running "$name"
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
