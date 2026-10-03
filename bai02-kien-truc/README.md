# Bài 2 — Kiến trúc điện toán đám mây

## Mục tiêu

<!-- TODO (giảng viên): mục tiêu bài -->

Đối chiếu các thành phần của miniONE với mô hình IaaS / PaaS / SaaS.

## Lý thuyết liên quan

<!-- TODO (giảng viên): mục bài giảng -->

Các thành phần cần nhận diện: `oned`, scheduler, FireEdge/Sunstone, OneFlow, OneGate, datastore, virtual network.

## Thực hành: khám phá hệ thống

Chạy trên VM `ONE-Lab` và ghi kết quả vào `REPORT.md`:

```bash
sudo -u oneadmin -H onehost show 0
sudo -u oneadmin -H onedatastore list
sudo -u oneadmin -H onevnet show 0
ls /etc/one
ls /var/log/one
systemctl list-units 'opennebula*' --no-pager
```

## Câu hỏi kiểm tra

<!-- TODO (giảng viên) -->

## Nộp bài

Điền `REPORT.md`, chạy `bash bai02-kien-truc/check.sh` (kiểm tra các mục đã có nội dung).
