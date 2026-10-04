# PROJECT_SPEC — ictu-cloud-security-lab

> File đặc tả để Claude Code dựng toàn bộ repo thực hành môn **An toàn điện toán đám mây** (ICTU).
> Cách dùng: mở thư mục `D:\ICTU\An_toan_dientoandammay\ictu-cloud-security-lab` trong Claude Code và ra lệnh:
> **"Đọc PROJECT_SPEC.md và dựng toàn bộ dự án theo đặc tả, làm lần lượt theo mục 10."**

---

## 1. Mục tiêu

- Repo **public** trên GitHub: `ictu-cloud-security-lab`, chứa script, template, cấu hình cho 9 bài thực hành.
- Giảng viên là người duy nhất được push. Sinh viên **chỉ clone/pull** về, rồi làm trên **repo riêng** của mình (xem mục 8).
- Mỗi bài chạy được độc lập trên môi trường lab cá nhân: **Ubuntu 24.04 (VM) + OpenNebula miniONE v6.10.3 (Front-end + KVM)**.
- Mật khẩu lab **để công khai trong repo** (môi trường cá nhân, cô lập). Ghi rõ cảnh báo "CHỈ DÙNG TRONG LAB".

## 2. Môi trường chuẩn (đã chốt)

| Lớp | Giá trị |
|---|---|
| Máy host giảng viên | Windows 11 Pro, Ryzen AI 7 H 350, 32 GB RAM, đang dùng WSL2 |
| Hypervisor ngoài | **Hyper-V** (chạy song song WSL2) — script `00-host/setup-onelab.ps1` đã có |
| Phương án SV | VMware Workstation (tích "Virtualize Intel VT-x/EPT or AMD-V/RVI"); máy có WSL/Docker dùng Hyper-V hoặc boot entry `hypervisorlaunchtype off` |
| VM lab | `ONE-Lab`: Ubuntu 24.04.4 **Desktop**, user `sinhvien`, tên máy `ubuntu` (dấu nhắc `sinhvien@ubuntu`), 12 GB RAM tĩnh, 6 vCPU, 80 GB, nested virt ON, MAC spoofing ON |
| Mạng host↔VM | Hyper-V Internal switch `ONE-Lab` + NAT `192.168.50.0/24`; host `192.168.50.1`, VM `192.168.50.10` (IP tĩnh qua `nmcli`) |
| OpenNebula | miniONE **v6.10.3** (ghim phiên bản, KHÔNG dùng `latest` vì 7.x đổi Sunstone và yêu cầu 32 GiB RAM) |
| Mạng VM lồng | bridge `minionebr`, `172.16.100.0/24`, gateway `172.16.100.1` (miniONE tạo sẵn, có NAT) |

## 3. Quy ước chung

### 3.1 Mật khẩu & IP lab (công khai)

| Tài nguyên | Giá trị |
|---|---|
| oneadmin (miniONE) | `OneLab@2026` |
| User OpenNebula Bài 4 | `alice` / `Alice@123`, `bob` / `Bob@123`, `auditor` / `Audit@123` |
| root VM khách (CONTEXT PASSWORD) | `Lab@123` |
| MySQL root (Bài 7, 9 – cố ý yếu ở Bài 9) | `root` / `123456` (Bài 9 setup), sau respond đổi `Db@Strong2026` |
| Basic auth Nginx (Bài 6) | `labadmin` / `Labadmin@123` |

IP cố định cho VM lồng (gán bằng `NIC=[ ..., IP="..." ]`):

| VM | IP |
|---|---|
| cirros-01 (Bài 3) | 172.16.100.201 |
| web-paas (Bài 5) | 172.16.100.205 |
| lamp-01 (Bài 7) | 172.16.100.207 |
| VM-WS (Bài 9) | 172.16.100.211 |
| VM-DB (Bài 9) | 172.16.100.212 |
| VM-ATK (Bài 9) | 172.16.100.213 |

Tất cả gom vào **`lib/lab.env`** (một nguồn duy nhất), các script `source` file này.

### 3.2 Cấu trúc mỗi bài

```
baiXX-ten/
├── README.md     # mục tiêu, lý thuyết liên quan (mục bài giảng), các bước SV làm, câu hỏi kiểm tra
├── setup.sh      # dựng tài nguyên của bài (idempotent: chạy lại không lỗi, không tạo trùng)
├── check.sh      # tự kiểm tra, in [PASS]/[FAIL] từng tiêu chí, exit code = số FAIL
├── reset.sh      # xoá tài nguyên bài này (không động bài khác)
├── files/        # template .tmpl, cấu hình, ứng dụng mẫu
└── REPORT.md     # mẫu báo cáo SV điền (ảnh chụp, kết quả lệnh, trả lời câu hỏi)
```

### 3.3 Chuẩn viết script

- Bash, `#!/usr/bin/env bash` + `set -euo pipefail`, chạy bằng user thường có sudo trên VM `ONE-Lab`.
- Mọi lệnh OpenNebula CLI chạy qua helper `one()` = `sudo -u oneadmin -H "$@"` (để dùng `~oneadmin/.one/one_auth`).
- Comment & thông báo bằng **tiếng Việt có dấu** (file UTF-8, LF). Riêng file `.ps1` dùng **ASCII** (PowerShell 5.1 đọc UTF-8 không BOM sẽ lỗi font).
- Có `shellcheck` sạch. Thêm `.gitattributes`: `*.sh text eol=lf`, `*.ps1 text eol=crlf`.

## 4. Thư viện dùng chung `lib/`

`lib/lab.env` — biến ở mục 3.1 + `ONE_VERSION=6.10.3`, `LAB_NET=lab-net`, `LAB_BRIDGE=minionebr`, `UBUNTU_IMG=ubuntu2204-lab`, `CIRROS_URL=https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img`.

`lib/common.sh` — các hàm:

| Hàm | Việc |
|---|---|
| `one` | chạy CLI dưới oneadmin |
| `log_ok/log_fail/log_info` | in màu, đếm FAIL cho `check.sh` |
| `require_root_sudo`, `require_cmd` | kiểm tra tiền điều kiện |
| `ensure_ssh_key` | tạo `~/.ssh/id_ed25519` nếu chưa có, trả về nội dung public key |
| `ensure_lab_net` | tạo vnet `lab-net` trên `minionebr` nếu chưa có: `VN_MAD="bridge"`, AR IP4 `172.16.100.200` SIZE 50, GATEWAY `172.16.100.1`, DNS `8.8.8.8`, NETWORK_MASK `255.255.255.0` (dải 200–249 để tránh dải mặc định của miniONE 172.16.100.2+) |
| `ensure_ubuntu_image` | lấy image Ubuntu từ Marketplace "OpenNebula Public": `onemarketapp list -l ID,NAME,MARKET --csv --no-header`, lọc `Ubuntu 22.04` (ưu tiên) hoặc `Ubuntu 24.04`, `onemarketapp export <ID> $UBUNTU_IMG -d default`; chờ READY |
| `wait_image <name>` | chờ `<STATE>1</STATE>` trong `oneimage show -x` (4=LOCKED, 5=ERROR → báo lỗi), timeout 15 phút |
| `wait_vm_running <name>` | chờ `LCM_STATE=3` (RUNNING), timeout 5 phút |
| `wait_ssh <ip>` | chờ cổng 22 mở + SSH key login được (timeout 5 phút) |
| `vm_exists/image_exists/template_exists/vnet_exists/user_exists/group_exists` | kiểm tra theo tên (dùng `-x` + grep/xmllint) |
| `instantiate_ubuntu <vmname> <ip> [extra_context]` | sinh template tạm từ `lib/templates/ubuntu-vm.tmpl` (envsubst) rồi `onetemplate instantiate` hoặc `onevm create` |

`lib/templates/ubuntu-vm.tmpl`:
```
NAME   = "${VM_NAME}"
CPU    = 1
VCPU   = 1
MEMORY = 1024
DISK   = [ IMAGE = "${UBUNTU_IMG}", IMAGE_UNAME = "oneadmin" ]
NIC    = [ NETWORK = "${LAB_NET}", IP = "${VM_IP}" ]
GRAPHICS = [ TYPE = "VNC", LISTEN = "0.0.0.0" ]
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = "${SSH_PUBKEY}",
  PASSWORD = "${GUEST_ROOT_PASSWORD}",
  SET_HOSTNAME = "${VM_NAME}" ]
```
(Image Marketplace có sẵn one-context → tự đặt IP, key, mật khẩu root.)

## 5. Nội dung từng thư mục

### 5.0 `00-host/` (đã có `setup-onelab.ps1`)
- Giữ `setup-onelab.ps1` (Hyper-V, đã chạy được ý tưởng; default ISO `D:\setup\ubuntu-24.04.4-desktop-amd64.iso`, có tham số `-IsoPath`).
- Thêm `wslconfig.sample` (`memory=8GB`, `processors=6`).
- Thêm `VMWARE.md`: tạo VM VMware (8–12 GB RAM, 4–6 vCPU, 80 GB, tích VT-x/AMD-V, NIC1 NAT + NIC2 Host-only), cách tắt Hyper-V/VBS khi gặp lỗi *"Virtualized Intel VT-x/EPT is not supported"* (bỏ Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform, Windows Sandbox; tắt Memory Integrity; `bcdedit /set hypervisorlaunchtype off`), và cách tạo boot entry kép để giữ WSL.
- Thêm `UBUNTU-POSTINSTALL.md`: đặt IP tĩnh bằng `nmcli`, cài `openssh-server`, checkpoint `clean-os`.
- Thêm `route-to-nested.ps1` (tùy chọn): `route add 172.16.100.0 mask 255.255.255.0 192.168.50.10` để Windows truy cập thẳng VM lồng.

### 5.1 `01-minione/`
- `install.sh`: kiểm tra Ubuntu 24.04, `grep -c -E 'vmx|svm' /proc/cpuinfo` > 0, `/dev/kvm` tồn tại (không có → in hướng dẫn bật nested rồi thoát); tải `https://github.com/OpenNebula/minione/releases/download/v6.10.3/minione`; chạy `sudo bash minione --password "$ONEADMIN_PASSWORD" --yes` (kiểm tra cờ không-tương-tác thực tế bằng `bash minione --help`, dùng đúng cờ có sẵn); lưu log `~/minione-install.log`.
- `check.sh`: `systemctl is-active opennebula opennebula-fireedge`, `onehost list` có host 0 trạng thái `on`, `onevnet list` có vnet mặc định, `ip a show minionebr` có `172.16.100.1`, `curl -s -o /dev/null -w '%{http_code}' http://localhost/` hoặc `:2616` trả 200/302.
- `README.md`: đăng nhập Sunstone (`http://192.168.50.10/` hoặc `http://192.168.50.10:2616/fireedge/sunstone`), oneadmin / `OneLab@2026`, chụp checkpoint `after-minione`.

### 5.2 `bai02-kien-truc/`
Chỉ README: đối chiếu thành phần miniONE với mô hình IaaS/PaaS/SaaS (oned, scheduler, FireEdge/Sunstone, OneFlow, OneGate, datastore, vnet), lệnh khám phá: `onehost show 0`, `onedatastore list`, `onevnet show 0`, `ls /etc/one`, `ls /var/log/one`. `check.sh` kiểm tra SV đã ghi kết quả vào `REPORT.md` (có đủ các mục).

### 5.3 `bai03-iaas/` (bài giảng mục 3.3)
- `setup.sh`:
  1. Tải CirrOS vào **`/var/tmp/`** (đường dẫn an toàn mặc định của datastore — bài giảng đang để `/home/...` sẽ bị chặn bởi `RESTRICTED_DIRS/SAFE_DIRS`), `chmod 644`.
  2. `oneimage create --name cirros-0.6.2 --path /var/tmp/cirros-0.6.2-x86_64-disk.img --datastore default --type OS --driver qcow2`; `wait_image`.
  3. `ensure_lab_net`.
  4. Tạo template `files/cirros.tmpl`: CPU 0.5, VCPU 1, MEMORY 256, DISK image cirros, NIC `lab-net` IP `172.16.100.201`, GRAPHICS VNC.
  5. Tạo datastore phụ `files/lab-ds.tmpl` (`TYPE=IMAGE_DS`, `DS_MAD=fs`, `TM_MAD=ssh` hoặc `qcow2`) — minh hoạ mục 3.3.3.
  6. `onetemplate instantiate cirros-tmpl --name cirros-01`.
- README: vòng đời VM `onevm suspend/resume/poweroff/resume/terminate`, `onevm monitoring`, thao tác tương đương trên Sunstone.
- **Lưu ý CirrOS không có one-context, OpenNebula 6.x không cấp DHCP** → đăng nhập VNC (`cirros` / `gocubsgo`) và đặt IP tay: `sudo ip addr add 172.16.100.201/24 dev eth0; sudo ip route add default via 172.16.100.1`. Ghi rõ trong README.
- `check.sh`: image READY, template tồn tại, `cirros-01` RUNNING, ping `172.16.100.201` (sau khi SV đặt IP).

### 5.4 `bai04-users-acl/` (mục 4.3)
- `setup.sh`: group `dev`, `audit`; user `alice` (dev, group admin), `bob` (dev), `auditor` (audit); `oneuser update --append` thêm `DEPARTMENT="IT"`, `EMAIL="alice@lab.local"`; quota `files/quota-dev.txt` (`VM=[VMS=2, CPU=2, MEMORY=2048, RUNNING_VMS=2]`) áp cho bob; ACL:
  - `@dev` được `VM+IMAGE+TEMPLATE/@<gid_dev> USE+MANAGE+CREATE`
  - `@audit` chỉ `VM+IMAGE+TEMPLATE+NET+HOST/* USE` (chỉ xem)
  - `onetemplate chmod cirros-tmpl 644` để dev dùng chung template
- `files/sunstone-views.md`: giải thích `DEFAULT_VIEW`, `GROUP_ADMIN_VIEWS` (cloud / groupadmin / admin) đúng cho FireEdge Sunstone 6.10 (`/etc/one/fireedge/sunstone/`) — kiểm tra đường dẫn thật trên máy rồi mới viết.
- `check.sh`: dùng `ONE_AUTH` tạm (`echo "bob:Bob@123" > /tmp/bob_auth`) kiểm tra: bob tạo được VM thứ 1–2, VM thứ 3 bị quota chặn; auditor `onevm list` được nhưng `onevm terminate` bị từ chối; in bảng kết quả.
- `reset.sh`: xoá VM của các user này, ACL đã thêm (lưu ID ACL vào `.state`), user, group.

### 5.5 `bai05-paas/` (mục 5.3)
- Ý tưởng: OpenNebula làm IaaS, dựng "nền tảng" (Nginx + Gunicorn + Python) trên VM để
