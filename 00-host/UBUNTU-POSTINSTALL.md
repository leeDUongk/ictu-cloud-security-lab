# Sau khi cài Ubuntu 24.04 trên VM `ONE-Lab`

## 1. IP tĩnh bằng `nmcli`

Mạng chuẩn: host `192.168.50.1`, VM `192.168.50.10/24`.

```bash
nmcli con show                       # xem tên kết nối, ví dụ "Wired connection 1"
sudo nmcli con mod "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.50.10/24 \
  ipv4.gateway 192.168.50.1 \
  ipv4.dns "8.8.8.8 1.1.1.1"
sudo nmcli con up "Wired connection 1"
ip -4 a                              # xác nhận có 192.168.50.10
ping -c2 8.8.8.8                     # xác nhận ra Internet qua NAT của host
```

## 2. Cài gói cần thiết

```bash
sudo apt update
sudo apt install -y openssh-server git curl libxml2-utils gettext-base netcat-openbsd shellcheck
sudo systemctl enable --now ssh
```

Từ Windows kiểm tra: `ssh sinhvien@192.168.50.10`.

## 3. Lấy mã lab

```bash
git clone https://github.com/leeDUongk/ictu-cloud-security-lab.git
cd ictu-cloud-security-lab
```

## 4. Checkpoint `clean-os`

Trên Windows (PowerShell Administrator), trước khi cài miniONE:

```powershell
Checkpoint-VM -Name ONE-Lab -SnapshotName clean-os
```

Có thể quay lại bằng `Restore-VMCheckpoint -VMName ONE-Lab -Name clean-os -Confirm:$false`.
