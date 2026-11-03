# Phương án VMware Workstation (dành cho sinh viên)

> Phương án chuẩn của giảng viên là Hyper-V (`setup-onelab.ps1`). Dùng VMware nếu máy bạn không bật được Hyper-V.

## 1. Tạo VM `ONE-Lab`

| Mục | Giá trị |
|---|---|
| Hệ điều hành | Ubuntu 24.04 **Desktop** |
| RAM | 8–12 GB (khuyến nghị 12 GB nếu máy có ≥ 24 GB) |
| CPU | 4–6 vCPU |
| Ổ đĩa | 80 GB |
| **Processors** | tích **Virtualize Intel VT-x/EPT or AMD-V/RVI** |
| NIC 1 | NAT (ra Internet) |
| NIC 2 | Host-only (để máy thật truy cập Sunstone) |

IP trong VM: xem `UBUNTU-POSTINSTALL.md` (đổi dải IP theo mạng Host-only của VMware nếu khác `192.168.50.0/24`,
đồng thời cập nhật `VM_LAB_IP` trong `lib/lab.env`).

## 2. Lỗi "Virtualized Intel VT-x/EPT is not supported"

Nguyên nhân: Windows đang giữ hypervisor (Hyper-V/VBS) nên VMware không bật được ảo hoá lồng.

1. Mở *Turn Windows features on or off*, **bỏ tích**: Hyper-V, Virtual Machine Platform,
   Windows Hypervisor Platform, Windows Sandbox. Khởi động lại.
2. *Windows Security → Device security → Core isolation* → tắt **Memory integrity**. Khởi động lại.
3. PowerShell (Administrator):

```powershell
bcdedit /set hypervisorlaunchtype off
```

Khởi động lại rồi mở VM. Kiểm tra: `systeminfo` không còn dòng *"A hypervisor has been detected"*.

## 3. Giữ WSL2/Docker: tạo boot entry kép

WSL2 và Docker Desktop cần hypervisor của Windows, nên không dùng được khi đã tắt ở mục 2.
Cách giữ cả hai: tạo thêm một mục khởi động riêng không có hypervisor.

```powershell
# 1) Nhân bản mục khởi động hiện tại, ghi lại GUID in ra
bcdedit /copy {current} /d "Windows (VMware - khong Hyper-V)"

# 2) Tắt hypervisor trên mục mới (thay <GUID> bằng GUID vừa in ra)
bcdedit /set "<GUID>" hypervisorlaunchtype off

# 3) Mục mặc định vẫn giữ hypervisor (cho WSL/Docker)
bcdedit /set "{current}" hypervisorlaunchtype auto
```

Khi khởi động, chọn **Windows (VMware - khong Hyper-V)** để chạy VMware, chọn mục cũ để dùng WSL/Docker.
Memory integrity tắt ở mục 2 chỉ cần tắt một lần.
