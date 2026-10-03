# Sunstone views: `DEFAULT_VIEW`, `GROUP_ADMIN_VIEWS`

> **CHƯA XÁC MINH.** Nội dung dưới đây là khung. Giảng viên cần kiểm tra đường dẫn và tên khoá
> thật trên máy miniONE 6.10.3 (FireEdge Sunstone) rồi điền vào mục "Kết quả kiểm tra".

## Cách kiểm tra trên VM ONE-Lab

```bash
ls -R /etc/one/fireedge/sunstone/ | head -50
sudo grep -rniE 'default_view|group_admin_views|groupadmin|cloud' /etc/one/fireedge/ 2>/dev/null | head -30
sudo -u oneadmin -H onegroup show dev
```

## Nội dung cần giải thích (điền sau khi kiểm tra)

| Khoá / khái niệm | Ý nghĩa | Giá trị trong lab |
|---|---|---|
| `DEFAULT_VIEW` | View mặc định cho user thường | _(điền)_ |
| `GROUP_ADMIN_VIEWS` | Các view dành cho admin của group | _(điền)_ |
| view `cloud` | Giao diện tối giản, người dùng cuối | _(điền)_ |
| view `groupadmin` | Giao diện quản trị trong phạm vi group | _(điền)_ |
| view `admin` | Giao diện quản trị toàn hệ thống | _(điền)_ |

## Kết quả kiểm tra

_(điền: đường dẫn file thật, ảnh chụp giao diện khi đăng nhập alice / bob / auditor)_
