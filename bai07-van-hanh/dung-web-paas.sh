#!/usr/bin/env bash
# Bài 7 — chuẩn bị máy ảo web-paas có sẵn ứng dụng "Đăng ký học phần" (kết quả của Bài thực hành 5).
# Chạy trên ONE-Lab bằng tài khoản thường có sudo:
#   bash ~/ictu-cloud-security-lab/bai07-van-hanh/dung-web-paas.sh
# - Chưa có máy ảo web-paas: tạo nhóm bảo mật, mạng ảo vnet-paas, template và máy ảo như Bài 5 Phần A.
# - Máy ảo đang tắt: bật lại.
# - Sau đó chép mã ứng dụng vào máy ảo và cài (Bài 5 Phần B, C). Chạy lại nhiều lần không sao.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
ADM="sudo -u oneadmin -H"
IP=172.16.100.205
WORK=/tmp/lab7
SSHOPT="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5"

mkdir -p "$WORK" && chmod 755 "$WORK"
cd "$WORK"
test -f ~/.ssh/id_ed25519 || ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519

if ! $ADM onevm list --no-header | awk '{print $4}' | grep -qx web-paas; then
  echo "[1/4] Chưa có máy ảo web-paas: tạo theo Bài 5 Phần A"
  if ! $ADM onesecgroup list --no-header | awk '{print $4}' | grep -qx sg-web-paas; then
    cat > sg-web-paas.txt <<'EOF'
NAME = "sg-web-paas"
DESCRIPTION = "Chi mo SSH, HTTP, HTTPS, ICMP vao web-paas"
RULE = [ PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "22,80,443" ]
RULE = [ PROTOCOL = "ICMP", RULE_TYPE = "inbound" ]
RULE = [ PROTOCOL = "ALL", RULE_TYPE = "outbound" ]
EOF
    $ADM onesecgroup create sg-web-paas.txt
  fi
  SG=$($ADM onesecgroup list --no-header | awk '$4=="sg-web-paas"{print $1}')
  if ! $ADM onevnet list --no-header | awk '{print $4}' | grep -qx vnet-paas; then
    cat > vnet-paas.txt <<EOF
NAME = "vnet-paas"
VN_MAD = "fw"
BRIDGE = "minionebr"
GATEWAY = "172.16.100.1"
DNS = "1.1.1.1 8.8.8.8"
NETWORK_ADDRESS = "172.16.100.0"
NETWORK_MASK = "255.255.255.0"
AR = [ TYPE = "IP4", IP = "172.16.100.200", SIZE = "10" ]
EOF
    $ADM onevnet create vnet-paas.txt
  fi
  # Gỡ nhóm default (ID 0) mà OpenNebula tự gắn vào mạng mới.
  echo "SECURITY_GROUPS = \"$SG\"" > vnet-paas-sg.txt
  $ADM onevnet update vnet-paas vnet-paas-sg.txt --append
  if ! $ADM onetemplate list --no-header | awk '{print $4}' | grep -qx web-paas-tmpl; then
    KEY=$(cat ~/.ssh/id_ed25519.pub)
    cat > web-paas-tmpl.txt <<EOF
NAME = "web-paas-tmpl"
CPU = "1"
VCPU = "1"
MEMORY = "512"
DISK = [ IMAGE_ID = "0", SIZE = "2048" ]
NIC = [ NETWORK = "vnet-paas", NETWORK_UNAME = "oneadmin", IP = "$IP" ]
NIC_DEFAULT = [ MODEL = "virtio" ]
GRAPHICS = [ LISTEN = "0.0.0.0", TYPE = "vnc" ]
OS = [ ARCH = "x86_64" ]
CONTEXT = [ NETWORK = "YES", SSH_PUBLIC_KEY = "$KEY",
  SET_HOSTNAME = "web-paas", REPORT_READY = "YES", TOKEN = "YES" ]
EOF
    $ADM onetemplate create web-paas-tmpl.txt
  fi
  $ADM onetemplate instantiate web-paas-tmpl --name web-paas
else
  echo "[1/4] Đã có máy ảo web-paas"
fi

VMID=$($ADM onevm list --no-header | awk '$4=="web-paas"{print $1; exit}')
STATE=$($ADM onevm list --no-header | awk '$4=="web-paas"{print $5; exit}')
case "$STATE" in
  poff|stop|unde|susp) echo "      Máy ảo $VMID đang $STATE: bật lại"; $ADM onevm resume "$VMID" ;;
esac

echo "[2/4] Chờ máy ảo $VMID chạy và mở SSH (tối đa 3 phút)"
for _ in $(seq 1 60); do
  if ssh $SSHOPT -o BatchMode=yes root@$IP true 2>/dev/null; then break; fi
  sleep 3
done
ssh $SSHOPT -o BatchMode=yes root@$IP true || {
  echo "[LỖI] Chưa SSH được vào root@$IP. Xem: $ADM onevm show $VMID" >&2; exit 1; }

echo "[3/4] Chép mã ứng dụng và script Bài 7 vào máy ảo"
scp $SSHOPT -q -r "$REPO/bai05-paas" "$REPO/bai07-van-hanh" root@$IP:/root/

echo "[4/4] Cài ứng dụng trong máy ảo"
ssh $SSHOPT root@$IP sh /root/bai07-van-hanh/cai-ung-dung.sh
