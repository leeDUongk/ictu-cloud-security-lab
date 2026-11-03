"""Bài 7 — quản lý tài khoản người dùng của ứng dụng "Đăng ký học phần" (lớp tài khoản thứ ba).

Chạy TRONG máy ảo web-paas bằng root, dùng Python của môi trường ảo ứng dụng:
  PY=/srv/demoapp/venv/bin/python
  $PY taikhoan-ungdung.py ds              # liệt kê tài khoản và số phiếu
  $PY taikhoan-ungdung.py them <tên>      # tạo tài khoản, mật khẩu nhập từ bàn phím
  $PY taikhoan-ungdung.py xoa <tên>       # xóa tài khoản và các phiếu của nó

Mật khẩu được lưu ở dạng băm (werkzeug), giống cách ứng dụng tạo tài khoản mẫu.
"""
import getpass
import os
import re
import sqlite3
import sys

from werkzeug.security import generate_password_hash

DB = os.environ.get("DEMOAPP_DB", "/var/lib/demoapp/demo.db")


def ket_noi():
    if not os.path.exists(DB):
        sys.exit(f"[LỖI] Không thấy {DB}. Ứng dụng đã chạy lần nào chưa?")
    return sqlite3.connect(DB)


def ds(db):
    rows = db.execute(
        "SELECT u.id, u.username, COUNT(r.id) FROM users u "
        "LEFT JOIN registrations r ON r.user_id = u.id GROUP BY u.id ORDER BY u.id"
    ).fetchall()
    print(f"{'ID':>3}  {'TÀI KHOẢN':<12} SỐ PHIẾU")
    for uid, name, n in rows:
        print(f"{uid:>3}  {name:<12} {n}")


def them(db, name):
    if not re.fullmatch(r"[a-z][a-z0-9_]{1,15}", name):
        sys.exit("[LỖI] Tên chỉ gồm chữ thường, số, gạch dưới; 2-16 ký tự, bắt đầu bằng chữ.")
    if db.execute("SELECT 1 FROM users WHERE username = ?", (name,)).fetchone():
        sys.exit(f"[LỖI] Tài khoản {name} đã có.")
    pw = getpass.getpass(f"Mật khẩu cho {name}: ")
    if len(pw) < 8:
        sys.exit("[LỖI] Mật khẩu cần ít nhất 8 ký tự.")
    if pw != getpass.getpass("Nhập lại: "):
        sys.exit("[LỖI] Hai lần nhập không khớp.")
    db.execute("INSERT INTO users (username, pw_hash) VALUES (?, ?)",
               (name, generate_password_hash(pw)))
    db.commit()
    print(f"[OK] Đã tạo tài khoản ứng dụng {name}.")


def xoa(db, name):
    row = db.execute("SELECT id FROM users WHERE username = ?", (name,)).fetchone()
    if row is None:
        sys.exit(f"[LỖI] Không có tài khoản {name}.")
    db.execute("DELETE FROM registrations WHERE user_id = ?", (row[0],))
    db.execute("DELETE FROM users WHERE id = ?", (row[0],))
    db.commit()
    print(f"[OK] Đã xóa tài khoản ứng dụng {name} và các phiếu của nó.")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("ds", "them", "xoa"):
        sys.exit(__doc__)
    db = ket_noi()
    if sys.argv[1] == "ds":
        ds(db)
    elif len(sys.argv) != 3:
        sys.exit(__doc__)
    elif sys.argv[1] == "them":
        them(db, sys.argv[2])
    else:
        xoa(db, sys.argv[2])


if __name__ == "__main__":
    main()
