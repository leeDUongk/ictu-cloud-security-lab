#!/bin/sh
# Bài 7 — tạo lỗi có kiểm soát cho ứng dụng "Đăng ký học phần" để luyện chẩn đoán, rồi trả lại như cũ.
# Chạy TRONG máy ảo web-paas bằng root:
#   sh gia-lap-loi.sh 1          # tạo lỗi số 1
#   sh gia-lap-loi.sh 2          # tạo lỗi số 2
#   sh gia-lap-loi.sh khoiphuc   # gỡ mọi lỗi đã tạo, kiểm tra ứng dụng chạy lại
# Script cố ý không in nguyên nhân; hãy tìm nguyên nhân bằng số liệu và nhật ký.
# Chỉ dùng trên máy ảo thực hành của chính mình.
set -eu

DATA=/var/lib/demoapp
BAK=/root/.lab7-demoapp-bak

loi1() {
  rc-service demoapp stop >/dev/null 2>&1
}

loi2() {
  if mountpoint -q "$DATA"; then echo "Lỗi số 2 đã được tạo trước đó."; return; fi
  rc-service demoapp stop >/dev/null 2>&1
  rm -rf "$BAK" && cp -a "$DATA" "$BAK"
  # Thay thư mục dữ liệu bằng một hệ thống tệp rất nhỏ, chép dữ liệu cũ vào rồi lấp đầy phần còn lại.
  mount -t tmpfs -o size=1m,mode=0755 tmpfs "$DATA"
  cp -a "$BAK/." "$DATA/"
  chown webapp:webapp "$DATA"
  rc-service demoapp start >/dev/null 2>&1
  sleep 3
  su -s /bin/sh webapp -c "dd if=/dev/zero of=$DATA/.cache bs=4k 2>/dev/null" || true
}

khoiphuc() {
  if mountpoint -q "$DATA"; then
    rc-service demoapp stop >/dev/null 2>&1
    umount "$DATA"
    rm -rf "$BAK"
  fi
  rc-service demoapp start >/dev/null 2>&1 || true
  sleep 2
  code=$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1/login)
  echo "Đã khôi phục. /login trả $code."
}

case "${1:-}" in
  1) loi1; echo "Đã tạo lỗi số 1." ;;
  2) loi2; echo "Đã tạo lỗi số 2." ;;
  khoiphuc) khoiphuc ;;
  *) echo "Dùng: sh $0 1|2|khoiphuc" >&2; exit 1 ;;
esac
