# ictu-cloud-security-lab

Thực hành học phần **An toàn điện toán đám mây** (ICTU) trên OpenNebula miniONE v6.10.3.

> **CHỈ DÙNG TRONG LAB.** Mật khẩu trong `lib/lab.env` được công khai, dành cho môi trường cá nhân, cô lập.
> Không dùng lại ở nơi khác.

## Môi trường

Ubuntu 24.04 (VM `ONE-Lab`, 12 GB RAM, 6 vCPU, 80 GB, nested virtualization) + OpenNebula miniONE **v6.10.3**.
Tạo máy ảo trên Hyper-V bằng `00-host/setup-onelab.ps1`; dùng VMware thì xem `00-host/VMWARE.md`.

## Bắt đầu

```bash
git clone https://github.com/leeDUongk/ictu-cloud-security-lab.git
cd ictu-cloud-security-lab
bash 01-minione/install.sh
bash 01-minione/check.sh
```

## Nội dung

| Thư mục | Mục đích |
|---|---|
| `00-host/` | Tạo máy ảo `ONE-Lab` trên Hyper-V hoặc VMware |
| `01-minione/` | `install.sh` cài miniONE; `check.sh` kiểm tra hệ thống |
| `bai02-kien-truc/` | `check.sh` kiểm tra báo cáo Bài thực hành 2 (6 mục) |
| `bai03-iaas/` | `check.sh` kiểm tra báo cáo Bài thực hành 3 (5 mục) |
| `bai04-users-acl/` | `check.sh` kiểm tra báo cáo Bài thực hành 4 (6 mục) |
| `lib/` | `common.sh` (hàm dùng chung), `lab.env` (cấu hình và mật khẩu lab) |

Repo này chỉ chứa script và cấu hình để kéo về chạy trong terminal. Tài liệu lab (hướng dẫn, lý thuyết, mẫu báo cáo)
được phát riêng cho sinh viên, không nằm trong repo.

## Kiểm tra báo cáo

```bash
bash bai0X-.../check.sh <đường dẫn REPORT.md>
```

`check.sh` in `[PASS]`/`[FAIL]` cho từng mục của báo cáo và trả exit code bằng số mục chưa điền.

## Quy ước

- Chạy bằng user thường có sudo trên VM `ONE-Lab`.
- Lệnh OpenNebula chạy qua hàm `one()` (= `sudo -u oneadmin -H`).
- Mọi mật khẩu và IP nằm trong `lib/lab.env`.
- Sinh viên chỉ clone/pull repo này để lấy script.
