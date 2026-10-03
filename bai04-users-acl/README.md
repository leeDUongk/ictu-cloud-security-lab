# Bài 4 — Quản lý người dùng, nhóm, quota và ACL

## Mục tiêu

<!-- TODO (giảng viên): mục tiêu bài (bài giảng mục 4.3) -->

## Lý thuyết liên quan

<!-- TODO (giảng viên): user/group, quota, ACL, nguyên tắc đặc quyền tối thiểu -->

## Điều kiện

Đã chạy `bash bai03-iaas/setup.sh` (cần image, vnet, template của Bài 3).

## Thực hành

```bash
bash bai04-users-acl/setup.sh
```

| User | Nhóm | Vai trò |
|---|---|---|
| `alice` / `Alice@123` | `dev` | admin của nhóm `dev` |
| `bob` / `Bob@123` | `dev` | user thường, quota 2 VM / 2 CPU / 2048 MB |
| `auditor` / `Audit@123` | `audit` | chỉ xem |

ACL tạo ra:
- `@dev`: `VM+IMAGE+TEMPLATE` trong nhóm `dev` — `USE+MANAGE+CREATE`.
- `@audit`: `VM+IMAGE+TEMPLATE+NET+HOST` — chỉ `USE` (xem).

> **Template dùng chung.** Template `cirros-tmpl` của Bài 3 gán IP cố định `172.16.100.201`, nên không
> tạo được nhiều VM từ nó. Bài này thêm `cirros-dev-tmpl` (cấp IP tự động) để kiểm tra quota.
> `setup.sh` cũng `chmod 644` cho template, image và vnet để user khác có quyền `USE`.

Giao diện Sunstone theo nhóm: xem `files/sunstone-views.md`.

## Kiểm tra

```bash
bash bai04-users-acl/check.sh
```

Script tạo VM `bob-vm-1`, `bob-vm-2` bằng tài khoản `bob`, kiểm tra VM thứ 3 bị quota chặn,
và `auditor` xem được nhưng không xoá được.

## Câu hỏi kiểm tra

<!-- TODO (giảng viên) -->

## Dọn dẹp

```bash
bash bai04-users-acl/reset.sh
```
