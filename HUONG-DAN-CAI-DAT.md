# Hướng dẫn cài đặt môi trường lab

> **CHỈ DÙNG TRONG LAB.** Mật khẩu công khai trong `lib/lab.env`.
>
> **Trạng thái tài liệu: NHÁP.** Các bước dưới đây được viết từ script có sẵn và chưa được chạy hoàn chỉnh.
> Mỗi bước có cột **Kiểm chứng**: `chưa` nghĩa là chưa chạy thật; sẽ đổi thành `đã chạy` (kèm ngày và kết quả) khi giảng viên cài xong.

Mục tiêu: dựng VM `ONE-Lab` (Ubuntu 24.04 Desktop) rồi cài OpenNebula miniONE v6.10.3 (Front-end + KVM) để làm các bài thực hành.

## 0. Tổng quan

| Giai đoạn | Làm ở đâu | Tài liệu / script | Kiểm chứng |
|---|---|---|---|
| A. Chuẩn bị máy thật | Windows | mục 1 | chưa |
| B. Tạo VM Hyper-V | Windows (PowerShell Admin) | `00-host/setup-onelab.ps1` | chưa |
| C. Cài Ubuntu và đặt IP tĩnh | VM | `00-host/UBUNTU-POSTINSTALL.md` | chưa |
| D. Cài miniONE | VM | `01-minione/install.sh` | chưa |
| E. Kiểm tra | VM | `01-minione/check.sh` | chưa |

Thông số chuẩn: host Windows `192.168.50.1`, VM `192.168.50.10`, mạng VM lồng `172.16.100.0/24` (bridge `minionebr`).

## 1. Chuẩn bị máy thật

Yêu cầu:

- Windows 11 (build ≥ 22000), CPU hỗ trợ ảo hoá, RAM ≥ 24 GB (VM dùng 12 GB cố định).
- File ISO `ubuntu-24.04.4-desktop-amd64.iso` (mặc định ở `D:\setup\`).
- Dung lượng trống đủ cho ổ đĩa ảo (tối đa 80 GB).

Máy giảng viên lúc ghi nhận (2026-10-03): RAM 31,3 GB; ISO có ở `D:\setup\`; C: trống 66 GB, D: trống 301 GB; Hyper-V chưa bật.

> **Quyết định chờ xử lý:** script mặc định đặt VM ở `C:\HyperV`. Nếu ổ C: ít chỗ trống, sửa dòng `$VMPath` trong `00-host/setup-onelab.ps1` thành ổ có nhiều chỗ (ví dụ `D:\HyperV`) trước khi chạy.

Phương án khác: VMware Workstation, xem `00-host/VMWARE.md`.

## 2. Tạo VM Hyper-V

Mở **PowerShell bằng Run as administrator**:

```powershell
cd <thư mục repo>\00-host
powershell -ExecutionPolicy Bypass -File .\setup-onelab.ps1
```

- **Lần 1:** nếu Hyper-V chưa bật, script bật nó rồi thoát. **Khởi động lại máy.**
- **Lần 2:** chạy lại đúng lệnh trên. Script tạo switch nội bộ `ONE-Lab`, IP host `192.168.50.1`, NAT `192.168.50.0/24`, VM `ONE-Lab`
  (6 vCPU, 12 GB RAM tĩnh, 80 GB, bật nested virtualization, bật MAC spoofing), gắn ISO, khởi động VM và mở màn hình điều khiển.

Kiểm tra sau bước này (PowerShell Admin):

```powershell
Get-VM ONE-Lab | Select-Object Name, State, MemoryAssigned
(Get-VMProcessor ONE-Lab).ExposeVirtualizationExtensions    # phải là True
```

Lỗi gặp và cách xử lý: xem mục 7.

## 3. Cài Ubuntu trong VM

1. Trong trình cài Ubuntu: chọn **Do not connect to the internet**, bỏ qua cập nhật (switch này chưa có DHCP).
2. Chọn cài đặt bình thường, tạo user có quyền sudo.
3. Sau lần đăng nhập đầu, đặt IP tĩnh và cài SSH. Làm theo `00-host/UBUNTU-POSTINSTALL.md`:

```bash
nmcli con show
sudo nmcli con mod "<TÊN KẾT NỐI>" ipv4.method manual ipv4.addresses 192.168.50.10/24 \
  ipv4.gateway 192.168.50.1 ipv4.dns "8.8.8.8 1.1.1.1"
sudo nmcli con up "<TÊN KẾT NỐI>"
ping -c2 8.8.8.8
sudo apt update && sudo apt install -y openssh-server git curl libxml2-utils gettext-base netcat-openbsd shellcheck
```

4. Từ Windows kiểm tra: `ssh <user>@192.168.50.10`.
5. Gỡ ISO và chụp checkpoint (PowerShell Admin):

```powershell
Set-VMDvdDrive -VMName ONE-Lab -Path $null
Checkpoint-VM -Name ONE-Lab -SnapshotName clean-os
```

6. Lấy mã lab trong VM:

```bash
git clone https://github.com/leeDUongk/ictu-cloud-security-lab.git
cd ictu-cloud-security-lab
```

## 4. Cài OpenNebula miniONE

```bash
bash 01-minione/install.sh
```

Script kiểm tra Ubuntu 24.04, ảo hoá lồng (`vmx`/`svm`, `/dev/kvm`), tải miniONE v6.10.3 và cài (10 đến 20 phút). Log ở `~/minione-install.log`.
Không dùng bản `latest` (7.x đổi giao diện và cần 32 GiB RAM).

## 5. Kiểm tra

```bash
bash 01-minione/check.sh
```

Tất cả tiêu chí phải `[PASS]`. Đăng nhập Sunstone từ Windows: `http://192.168.50.10/` hoặc `http://192.168.50.10:2616/fireedge/sunstone`
với `oneadmin` / `OneLab@2026`. Chụp checkpoint `after-minione`:

```powershell
Checkpoint-VM -Name ONE-Lab -SnapshotName after-minione
```

## 6. Bước tiếp theo

Bài 3 (`bai03-iaas/`), rồi Bài 4 (`bai04-users-acl/`). Tuỳ chọn: `00-host/route-to-nested.ps1` để Windows truy cập thẳng VM lồng.

## 7. Nhật ký cài đặt thật và xử lý sự cố

> Phần này được điền khi giảng viên cài. Mỗi dòng: bước, thời điểm, kết quả, lỗi (nguyên văn) và cách khắc phục.

| Ngày | Bước | Kết quả | Lỗi / ghi chú | Cách khắc phục |
|---|---|---|---|---|
| 2026-10-03 | Kiểm tra máy trước khi cài | Hyper-V chưa bật; không có quyền Admin trong phiên Claude | — | Chạy script bằng PowerShell Admin do giảng viên mở |
| 2026-10-03 | B. Chạy `setup-onelab.ps1` (lần 1) | Không chạy | `The script 'setup-onelab.ps1' cannot be run because it contains a "#requires" statement for running as Administrator.` (`ScriptRequiresElevation`) | Mở PowerShell bằng **Run as administrator** (Start, gõ `powershell`, chuột phải, Run as administrator), rồi chạy lại lệnh |
| | | | | |

## 8. Câu hỏi thường gặp (bổ sung dần)

<!-- TODO (giảng viên): điền sau khi cài xong, dựa trên lỗi thực tế -->

## 9. Việc cần hoàn thiện khi cài xong

- [ ] Đổi cột **Kiểm chứng** ở mục 0 thành `đã chạy` kèm ngày.
- [ ] Điền mục 7 bằng lỗi thật, mục 8 bằng câu hỏi thường gặp.
- [ ] Thêm ảnh chụp Sunstone sau khi đăng nhập.
- [ ] Đồng bộ nếu thông số (RAM, vCPU, IP) thay đổi: `00-host/setup-onelab.ps1` và `lib/lab.env`.
- [ ] Thêm liên kết tới file này trong `README.md` ở thư mục gốc.
