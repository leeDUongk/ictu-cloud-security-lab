# Cài đặt OpenNebula miniONE

> **CHỈ DÙNG TRONG LAB.** Mật khẩu công khai trong `lib/lab.env`.

## Mục tiêu

<!-- TODO (giảng viên): mục tiêu bài, liên hệ nội dung bài giảng -->

Dựng đám mây IaaS một máy (Front-end + KVM) bằng miniONE **v6.10.3** trên VM `ONE-Lab`
(Ubuntu 24.04, 12 GB RAM, nested virtualization bật).

## Lý thuyết liên quan

<!-- TODO (giảng viên): mục bài giảng liên quan -->

## Các bước

1. Hoàn thành `00-host/` (tạo VM, IP tĩnh, `clean-os` checkpoint).
2. Chạy cài đặt:

   ```bash
   bash 01-minione/install.sh
   ```
3. Kiểm tra:

   ```bash
   bash 01-minione/check.sh
   ```
4. Đăng nhập Sunstone: `http://192.168.50.10/` hoặc `http://192.168.50.10:2616/fireedge/sunstone`
   với `oneadmin` / `OneLab@2026`.
5. Chụp checkpoint `after-minione` (Hyper-V: `Checkpoint-VM -Name ONE-Lab -SnapshotName after-minione`).

## Câu hỏi kiểm tra

<!-- TODO (giảng viên) -->

## Ghi chú

- Ghim phiên bản 6.10.3, không dùng `latest`: 7.x đổi giao diện Sunstone và yêu cầu 32 GiB RAM.
- miniONE tự tạo bridge `minionebr` (`172.16.100.0/24`, gateway `172.16.100.1`, có NAT).
