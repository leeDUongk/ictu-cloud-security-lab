# ictu-cloud-security-lab

Thực hành học phần **An toàn điện toán đám mây** (ICTU) trên OpenNebula miniONE v6.10.3.

> **CHỈ DÙNG TRONG LAB.** Mật khẩu trong `lib/lab.env` được công khai, dành cho môi trường cá nhân, cô lập.
> Không dùng lại ở nơi khác.

## Môi trường

Ubuntu 24.04 (VM `ONE-Lab`, 12 GB RAM, 6 vCPU, 80 GB, nested virtualization) + OpenNebula miniONE **v6.10.3**.
Chi tiết: `00-host/`.

## Bắt đầu

```bash
git clone <URL repo của giảng viên>
cd ictu-cloud-security-lab
bash 01-minione/install.sh
bash 01-minione/check.sh
```

## Các bài

| Thư mục | Nội dung | Trạng thái |
|---|---|---|
| `00-host/` | Hyper-V/VMware, IP tĩnh, route | khung đầy đủ |
| `01-minione/` | Cài miniONE | khung đầy đủ |
| `bai02-kien-truc/` | Kiến trúc đám mây | khung đầy đủ |
| `bai03-iaas/` | IaaS | khung đầy đủ |
| `bai04-users-acl/` | User, nhóm, quota, ACL | khung đầy đủ |
| `bai05-paas/` | PaaS | khung rỗng |
| `bai06-web-nginx/` | (tên tạm) | khung rỗng |
| `bai07-lamp/` | (tên tạm) | khung rỗng |
| `bai08-tbd/` | chưa xác định | khung rỗng |
| `bai09-incident-response/` | (tên tạm) | khung rỗng |

Mỗi bài có `README.md`, `setup.sh`, `check.sh`, `reset.sh`, `files/`, `REPORT.md`.
`setup.sh` và `reset.sh` chạy lại nhiều lần không lỗi. `check.sh` in `[PASS]`/`[FAIL]` và trả exit code bằng số tiêu chí FAIL.

## Quy ước

- Chạy bằng user thường có sudo trên VM `ONE-Lab`: `bash baiXX/setup.sh`.
- Lệnh OpenNebula chạy qua hàm `one()` (= `sudo -u oneadmin -H`).
- Mọi mật khẩu và IP nằm trong `lib/lab.env`.
- Sinh viên chỉ clone/pull repo này và nộp bài trên repo riêng của mình.

<!-- TODO (giảng viên): quy trình nộp bài trên repo riêng của sinh viên -->
