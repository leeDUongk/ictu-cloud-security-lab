#!/usr/bin/env python3
"""Proxy dung giua Core va Peer, gia lap lop bien (CDN, proxy) cau hinh sai hoac bi chiem. CHI DUNG TRONG LAB.

  python3 gia-mao.py CONG_NGHE URL_DICH TEP_CHE_DO

Che do doc lai tu TEP_CHE_DO o moi yeu cau (doi che do khong can khoi dong lai):
  trong-suot    chuyen nguyen yeu cau va phan hoi
  bo-chu-ky     xoa tieu de X-Chu-Ky cua phan hoi
  doi-than      sua than phan hoi sau khi ben kia da ky (1 byte cua ACK; "deny" thanh "allow")
  ack-gia       KHONG chuyen yeu cau di; tu tra mot ACK "da-nhan" voi chu ky bia (su kien mat ma khong ai biet)
  phat-lai-ack  tra lai ACK that cua lan dau cho moi yeu cau sau (ky voi nonce cu)
  chen-su-kien  chen them mot su kien "cap quyen xem" vao trang doi soat
"""
import http.client
import json
import secrets
import sys
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONG, DICH, TEP = int(sys.argv[1]), urllib.parse.urlsplit(sys.argv[2]), sys.argv[3]
ACK_CU = {}


class Proxy(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def gui_lai(self, ma, tieu_de, than):
        self.send_response(ma)
        for k, v in tieu_de.items():
            if k.lower() not in ("content-length", "connection", "server", "date"):
                self.send_header(k, v)
        self.send_header("Connection", "close")
        self.close_connection = True
        self.send_header("Content-Length", str(len(than)))
        self.end_headers()
        self.wfile.write(than)

    def chuyen(self, phuong_thuc):
        che_do = open(TEP).read().strip()
        than_yc = self.rfile.read(int(self.headers.get("Content-Length", "0") or 0))
        if che_do == "ack-gia" and phuong_thuc == "POST":
            sk = json.loads(than_yc)
            than = json.dumps({"id": sk["id"], "ket_qua": "da-nhan"}, separators=(",", ":"), sort_keys=True).encode()
            return self.gui_lai(200, {"Content-Type": "application/json", "X-Khoa": "p2c-1",
                                      "X-Thoi-Gian": str(int(time.time())), "X-Chu-Ky": secrets.token_hex(32)}, than)
        cn = http.client.HTTPConnection(DICH.hostname, DICH.port, timeout=5)
        td = {k: v for k, v in self.headers.items() if k.lower() not in ("host", "connection")}
        cn.request(phuong_thuc, self.path, body=than_yc or None, headers=td)
        r = cn.getresponse()
        ma, tieu_de, than = r.status, dict(r.getheaders()), r.read()
        if ma == 200 and che_do == "bo-chu-ky":
            tieu_de.pop("X-Chu-Ky", None)
        elif ma == 200 and che_do == "doi-than":
            than = than.replace(b'"da-nhan"', b'"da-nham"').replace(b'"trung"', b'"trunG"').replace(b'"deny"', b'"allow"')
        elif ma == 200 and che_do == "phat-lai-ack" and phuong_thuc == "POST":
            if "ack" in ACK_CU:
                tieu_de, than = ACK_CU["ack"]
            else:
                ACK_CU["ack"] = (tieu_de, than)
        elif ma == 200 and che_do == "chen-su-kien" and phuong_thuc == "GET":
            trang = json.loads(than)
            trang["su_kien"].append({"id": "00000000-0000-4000-8000-000000000000", "phien_ban": 1,
                                     "loai": "quyen-xem", "ma": "HS-0003", "gia_tri": "cap"})
            than = json.dumps(trang, separators=(",", ":"), sort_keys=True).encode()
        self.gui_lai(ma, tieu_de, than)

    def do_POST(self):
        self.chuyen("POST")

    def do_GET(self):
        self.chuyen("GET")


print(f"gia-mao nghe 127.0.0.1:{CONG} -> {sys.argv[2]}", flush=True)
ThreadingHTTPServer(("127.0.0.1", CONG), Proxy).serve_forever()
