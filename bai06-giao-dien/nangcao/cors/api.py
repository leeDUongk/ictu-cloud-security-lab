#!/usr/bin/env python3
"""API mau "Dao tao" cho Bai tap nang cao 2 cua Bai thuc hanh 6 (CORS).

Chi nghe 127.0.0.1:8000; Nginx dung truoc va quyet dinh tieu de CORS.
Du lieu nam trong bo nho, mat khi dung dich vu. CHI DUNG TRONG LAB.

  GET /api/hocphan                   danh sach hoc phan (cong khai)
  GET /api/dangnhap?u=an&samesite=X  gia lap dang nhap, dat cookie sid (X: Lax, Strict, None)
  GET /api/toi                       du lieu ca nhan, can cookie
  PUT /api/dangky                    dang ky hoc phan (JSON {"hocphan": "..."}), can cookie
"""
import json
import secrets
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SINH_VIEN = {
    "an": {"ho_ten": "Nguyễn Văn An", "mssv": "DTC2201", "diem_tb": 3.12},
    "chi": {"ho_ten": "Trần Thị Chi", "mssv": "DTC2202", "diem_tb": 3.45},
}
HOC_PHAN = ["ATDTDM - An toàn điện toán đám mây", "MMT - Mạng máy tính", "CSDL - Cơ sở dữ liệu"]
PHIEN = {}       # sid -> ten dang nhap
DANG_KY = {}     # ten dang nhap -> danh sach hoc phan


class XuLy(BaseHTTPRequestHandler):
    server_version = "daotao-api"
    sys_version = ""

    def gui(self, ma, du_lieu, tieu_de=()):
        than = json.dumps(du_lieu, ensure_ascii=False).encode("utf-8")
        self.send_response(ma)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        for k, v in tieu_de:
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(than)))
        self.end_headers()
        self.wfile.write(than)

    def nguoi_dung(self):
        for phan in self.headers.get("Cookie", "").split(";"):
            ten, _, gia_tri = phan.strip().partition("=")
            if ten == "sid" and gia_tri in PHIEN:
                return PHIEN[gia_tri]
        return None

    def do_GET(self):
        url = urllib.parse.urlsplit(self.path)
        q = urllib.parse.parse_qs(url.query)
        if url.path == "/api/hocphan":
            return self.gui(200, {"hoc_phan": HOC_PHAN})
        if url.path == "/api/dangnhap":
            ten = q.get("u", [""])[0]
            samesite = q.get("samesite", ["Lax"])[0]
            if ten not in SINH_VIEN or samesite not in ("Lax", "Strict", "None"):
                return self.gui(400, {"loi": "sai tham so"})
            sid = secrets.token_urlsafe(16)
            PHIEN[sid] = ten
            cookie = f"sid={sid}; Path=/; Secure; HttpOnly; SameSite={samesite}"
            return self.gui(200, {"dang_nhap": ten, "samesite": samesite}, [("Set-Cookie", cookie)])
        if url.path == "/api/toi":
            ten = self.nguoi_dung()
            if not ten:
                return self.gui(401, {"loi": "chua dang nhap"})
            return self.gui(200, {**SINH_VIEN[ten], "da_dang_ky": DANG_KY.get(ten, [])})
        return self.gui(404, {"loi": "khong co"})

    def do_PUT(self):
        if urllib.parse.urlsplit(self.path).path != "/api/dangky":
            return self.gui(404, {"loi": "khong co"})
        ten = self.nguoi_dung()
        if not ten:
            return self.gui(401, {"loi": "chua dang nhap"})
        if "application/json" not in self.headers.get("Content-Type", ""):
            return self.gui(415, {"loi": "can JSON"})
        do_dai = min(int(self.headers.get("Content-Length", 0)), 4096)
        try:
            hp = str(json.loads(self.rfile.read(do_dai))["hocphan"])[:60]
        except (ValueError, KeyError, TypeError):
            return self.gui(400, {"loi": "JSON sai"})
        DANG_KY.setdefault(ten, []).append(hp)
        return self.gui(200, {"da_dang_ky": DANG_KY[ten]})

    def log_message(self, *args):
        pass  # Nginx da ghi nhat ky truy cap


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8000), XuLy).serve_forever()
