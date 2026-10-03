# Bài 3 — Dịch vụ IaaS với OpenNebula

## Mục tiêu

<!-- TODO (giảng viên): mục tiêu bài (bài giảng mục 3.3) -->

## Lý thuyết liên quan

<!-- TODO (giảng viên): image, datastore, virtual network, template, vòng đời VM -->

## Thực hành

```bash
bash bai03-iaas/setup.sh
```

Script thực hiện: tải CirrOS → tạo image → tạo `lab-net` → tạo template `cirros-tmpl`
→ tạo datastore phụ `lab-ds` → tạo VM `cirros-01`.

> **Vì sao tải vào `/var/tmp/`?** Datastore chỉ nhận file trong các thư mục an toàn
> (`SAFE_DIRS`, mặc định có `/var/tmp`). Đường dẫn dưới `/home/...` sẽ bị chặn bởi `RESTRICTED_DIRS`.

### Đặt IP cho CirrOS (bắt buộc)

CirrOS không có one-context và OpenNebula 6.x không cấp DHCP. Mở VNC trên Sunstone, đăng nhập
`cirros` / `gocubsgo` và đặt IP tay:

```bash
sudo ip addr add 172.16.100.201/24 dev eth0
sudo ip route add default via 172.16.100.1
```

### Vòng đời VM

```bash
sudo -u oneadmin -H onevm suspend cirros-01
sudo -u oneadmin -H onevm resume cirros-01
sudo -u oneadmin -H onevm poweroff cirros-01
sudo -u oneadmin -H onevm resume cirros-01
sudo -u oneadmin -H onevm monitoring cirros-01
sudo -u oneadmin -H onevm terminate cirros-01
```

<!-- TODO (giảng viên): thao tác tương đương trên Sunstone (ảnh chụp) -->

## Kiểm tra

```bash
bash bai03-iaas/check.sh
```

## Câu hỏi kiểm tra

<!-- TODO (giảng viên) -->

## Dọn dẹp

```bash
bash bai03-iaas/reset.sh
```
