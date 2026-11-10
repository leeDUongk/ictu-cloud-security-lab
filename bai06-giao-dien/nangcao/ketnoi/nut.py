#!/usr/bin/env python3
"""Mot nut ket noi (Core hoac Peer) cho Bai tap nang cao 3 cua Bai thuc hanh 6. CHI DUNG TRONG LAB.

  python3 nut.py CAU_HINH chay                    chay may chu (chi nghe 127.0.0.1)
  python3 nut.py CAU_HINH tao-su-kien LOAI MA GIA_TRI
  python3 nut.py CAU_HINH gui                     gui hop thu di (outbox) sang ben kia, kiem ACK co ky
  python3 nut.py CAU_HINH keo                     keo trang doi soat cua ben kia theo cursor
  python3 nut.py CAU_HINH hoi MA THAO_TAC         hoi Core: ho so con du dieu kien khong (Peer dung)
  python3 nut.py CAU_HINH cach-ly bat|go|xem      cach ly sau khoi phuc sao luu (go: nhap mat khau quan tri)
  python3 nut.py CAU_HINH xem BANG                xem mot bang (ho_so, hop_thu_di, hop_thu_den, lead, ...)

Core co them: /may/lead (ve tinh day lead), /cong/... (cong ve tinh), /may/dieu-kien.
"""
import hashlib
import http.client
import json
import os
import sqlite3
import sys
import threading
import time
import urllib.parse
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import kyso

CH = {}          # cau hinh
DB = None        # duong dan CSDL
DEM = {}         # dem tan suat: khoa -> [moc thoi gian]
KHOA_DEM = threading.Lock()
TRANG_CONG = {"/trang/gioi-thieu": "Gioi thieu chuong trinh tuyen sinh", "/trang/tuyen-dung": "Thong tin tuyen dung"}


# ------------------------------------------------------------------ CSDL
def ket_noi():
    c = sqlite3.connect(DB, timeout=10, isolation_level=None)
    c.execute("PRAGMA journal_mode=WAL")
    return c


def tao_bang():
    c = ket_noi()
    c.executescript("""
    CREATE TABLE IF NOT EXISTS nonce(nonce TEXT PRIMARY KEY, het INTEGER);
    CREATE TABLE IF NOT EXISTS hop_thu_den(id TEXT PRIMARY KEY, bam TEXT, loai TEXT, nhan_luc INTEGER);
    CREATE TABLE IF NOT EXISTS hop_thu_di(seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT UNIQUE, loai TEXT, than TEXT,
        trang_thai TEXT DEFAULT 'cho', lan_thu INTEGER DEFAULT 0, gui_sau INTEGER DEFAULT 0,
        lease_den INTEGER DEFAULT 0, fencing INTEGER DEFAULT 0, so_lan_gui INTEGER DEFAULT 0);
    CREATE TABLE IF NOT EXISTS ho_so(ma TEXT PRIMARY KEY, nghe TEXT, dong_y TEXT, phien_ban INTEGER);
    CREATE TABLE IF NOT EXISTS de_cu(ma TEXT PRIMARY KEY, ket_qua TEXT, phien_ban INTEGER);
    CREATE TABLE IF NOT EXISTS quyen_xem(ma TEXT PRIMARY KEY, quyen TEXT, phien_ban INTEGER);
    CREATE TABLE IF NOT EXISTS lead(sdt TEXT PRIMARY KEY, ten TEXT, nhu_cau TEXT, nguon_dau TEXT, tao_luc INTEGER);
    CREATE TABLE IF NOT EXISTS lead_lich_su(sdt TEXT, nguon TEXT, luc INTEGER);
    CREATE TABLE IF NOT EXISTS con_tro(ten TEXT PRIMARY KEY, gia_tri INTEGER);
    CREATE TABLE IF NOT EXISTS trang_thai(khoa TEXT PRIMARY KEY, gia_tri TEXT);
    CREATE TABLE IF NOT EXISTS nhat_ky(luc INTEGER, ma TEXT, chi_tiet TEXT);
    """)
    c.close()


def dang_cach_ly(c):
    r = c.execute("SELECT gia_tri FROM trang_thai WHERE khoa='cach_ly'").fetchone()
    return bool(r and r[0] == "bat")


def ghi_log(ma, chi_tiet=""):
    """Nhat ky van hanh: chi ghi ma loi, khong ghi than yeu cau."""
    print(f"[{CH['ten']}] {time.strftime('%H:%M:%S')} {ma} {chi_tiet}", file=sys.stderr, flush=True)


# ------------------------------------------------------------------ nghiep vu (dung chung khi nhan su kien va khi doi soat)
def ap_dung(c, sk):
    """Ghi mot su kien cua ben kia vao nha minh. Tra ve 'da-nhan', 'trung' hoac nem ValueError('xung-dot')."""
    than = kyso.ma_hoa(sk)
    cu = c.execute("SELECT bam FROM hop_thu_den WHERE id=?", (sk["id"],)).fetchone()
    if cu:
        if cu[0] == kyso.bam(than):
            return "trung"
        raise ValueError("xung-dot")
    c.execute("INSERT INTO hop_thu_den VALUES(?,?,?,?)", (sk["id"], kyso.bam(than), sk["loai"], int(time.time())))
    loai, ma, gt, pb = sk["loai"], sk["ma"], sk["gia_tri"], sk["phien_ban"]
    if loai == "ho-so":
        # Rut dong y la trang thai cuoi: ho so da rut khong duoc mo lai.
        c.execute("INSERT INTO ho_so VALUES(?,?,?,?) ON CONFLICT(ma) DO UPDATE SET nghe=excluded.nghe, "
                  "phien_ban=excluded.phien_ban WHERE ho_so.dong_y!='rut' AND excluded.phien_ban>ho_so.phien_ban",
                  (ma, gt, "chua", pb))
    elif loai in ("dong-y", "rut-dong-y"):
        c.execute("INSERT INTO ho_so VALUES(?,?,?,?) ON CONFLICT(ma) DO UPDATE SET dong_y=excluded.dong_y "
                  "WHERE ho_so.dong_y!='rut'", (ma, "", "co" if gt == "co" else "rut", pb))
    else:
        bang = "de_cu" if loai == "ket-qua-de-cu" else "quyen_xem"
        cot = "ket_qua" if bang == "de_cu" else "quyen"
        c.execute(f"INSERT INTO {bang} VALUES(?,?,?) ON CONFLICT(ma) DO UPDATE SET {cot}=excluded.{cot}, "
                  f"phien_ban=excluded.phien_ban WHERE excluded.phien_ban>{bang}.phien_ban", (ma, gt, pb))
    return "da-nhan"


def tao_su_kien(loai, ma, gia_tri):
    """Thay doi nghiep vu tai cho va ghi outbox TRONG CUNG MOT transaction."""
    c = ket_noi()
    c.execute("BEGIN IMMEDIATE")
    pb = int(time.time() * 1000)
    sk = {"id": str(uuid.uuid4()), "phien_ban": pb, "loai": loai, "ma": ma, "gia_tri": gia_tri}
    loi = kyso.kiem_su_kien(sk)
    if loi:
        c.execute("ROLLBACK")
        sys.exit(f"Su kien khong hop le: {loi}")
    if loai == "ho-so":
        c.execute("INSERT INTO ho_so VALUES(?,?,?,?) ON CONFLICT(ma) DO UPDATE SET nghe=excluded.nghe",
                  (ma, gia_tri, "co", pb))
    elif loai == "rut-dong-y":
        c.execute("UPDATE ho_so SET dong_y='rut' WHERE ma=?", (ma,))
        # Snapshot ho so con cho gui bi huy: khong gui thong tin cua nguoi da rut.
        for seq, than in c.execute("SELECT seq, than FROM hop_thu_di WHERE trang_thai='cho' AND loai='ho-so'").fetchall():
            if json.loads(than)["ma"] == ma:
                c.execute("UPDATE hop_thu_di SET trang_thai='huy' WHERE seq=?", (seq,))
    else:
        ap_dung_noi_bo = {"ket-qua-de-cu": ("de_cu", "ket_qua"), "quyen-xem": ("quyen_xem", "quyen")}.get(loai)
        if ap_dung_noi_bo:
            b, cot = ap_dung_noi_bo
            c.execute(f"INSERT OR REPLACE INTO {b}(ma,{cot},phien_ban) VALUES(?,?,?)", (ma, gia_tri, pb))
    c.execute("INSERT INTO hop_thu_di(id,loai,than) VALUES(?,?,?)", (sk["id"], loai, kyso.ma_hoa(sk).decode()))
    c.execute("COMMIT")
    print(f"Da ghi outbox: {loai} {ma} {gia_tri} id={sk['id'][:8]}")


# ------------------------------------------------------------------ kiem yeu cau den
def kiem_yeu_cau(c, phuong_thuc, route, tieu_de, than):
    """Xac thuc yeu cau may cua ben kia. Tra ve (khoa, None) hoac (None, (ma_http, ma_loi)).
    Moi buoc truoc khi ghi nonce deu khong ghi gi vao CSDL."""
    bearer = tieu_de.get("Authorization", "")
    if not bearer.startswith("Bearer "):
        return None, (401, "thieu-bearer")
    khoa = kyso.tim_khoa(CH["khoa_nhan"], tieu_de.get("X-Khoa", ""))
    if not khoa or not kyso.khop(kyso.bam(bearer[7:].encode()), khoa["bearer_bam"]):
        return None, (401, "bearer-sai")
    try:
        ts = int(tieu_de.get("X-Thoi-Gian", ""))
    except ValueError:
        return None, (401, "thoi-gian-sai")
    if abs(time.time() - ts) > kyso.LECH_TOI_DA:
        return None, (401, "lech-thoi-gian")
    nonce = tieu_de.get("X-Nonce", "")
    try:
        uuid.UUID(nonce)
    except ValueError:
        return None, (401, "nonce-sai")
    mong = kyso.ky(khoa["ky"], kyso.chuoi_yeu_cau(phuong_thuc, route, ts, nonce, than))
    if not kyso.khop(mong, tieu_de.get("X-Chu-Ky", "")):
        return None, (401, "chu-ky-sai")
    if not kyso.bi_tat("nonce"):
        c.execute("DELETE FROM nonce WHERE het<?", (int(time.time()),))
        try:
            c.execute("INSERT INTO nonce VALUES(?,?)", (nonce, int(time.time()) + kyso.NONCE_SONG))
        except sqlite3.IntegrityError:
            return None, (401, "phat-lai")
    with KHOA_DEM:
        ds = [t for t in DEM.get(khoa["id"], []) if t > time.time() - 60] + [time.time()]
        DEM[khoa["id"]] = ds
    if len(ds) > CH.get("gioi_han_phut", 120):
        return None, (429, "qua-tan-suat")
    return khoa, None


# ------------------------------------------------------------------ may chu
class XuLy(BaseHTTPRequestHandler):
    server_version = "ketnoi"
    sys_version = ""
    protocol_version = "HTTP/1.1"

    def tra(self, ma, obj, nonce_yc=None, route=None, them=()):
        than = kyso.ma_hoa(obj)
        self.send_response(ma)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Accel-Expires", "0")          # bao Nginx khong cache
        if nonce_yc and 200 <= ma < 300:                   # chi phan hoi 2xx cua route may moi ky
            ts = int(time.time())
            k = CH["khoa_gui"]
            self.send_header("X-Khoa", k["id"])
            self.send_header("X-Thoi-Gian", str(ts))
            self.send_header("X-Chu-Ky", kyso.ky(k["ky"], kyso.chuoi_phan_hoi(route, ts, nonce_yc, than)))
        for k, v in them:
            self.send_header(k, v)
        self.send_header("Connection", "close")            # don gian: moi ket noi mot yeu cau
        self.close_connection = True
        self.send_header("Content-Length", str(len(than)))
        self.end_headers()
        self.wfile.write(than)

    def loi(self, ma, ma_loi, them=()):
        ghi_log(f"E{ma}", ma_loi)
        # Loi tra ra ngoai: cau trung tinh + ma, khong lo chi tiet.
        self.tra(ma, {"loi": "khong-xu-ly-duoc", "ma": f"E{ma}"}, them=them)

    def doc_than(self):
        n = int(self.headers.get("Content-Length", "0") or 0)
        if n > kyso.THAN_TOI_DA:
            return None
        return self.rfile.read(n)

    def xu_ly(self, phuong_thuc):
        url = urllib.parse.urlsplit(self.path)
        route = url.path
        if route.startswith("/cong/"):
            return self.cong(route[5:])
        if route == "/may/lead":
            return self.lead()
        c = ket_noi()
        try:
            if dang_cach_ly(c):
                return self.tra(503, {"loi": "tam-dung", "ma": "E503"})
            than = self.doc_than() if phuong_thuc == "POST" else b""
            if than is None:
                return self.loi(413, "than-qua-lon")
            khoa, sai = kiem_yeu_cau(c, phuong_thuc, route, self.headers, than)
            if sai:
                them = [("Retry-After", "60")] if sai[0] == 429 else ()
                return self.loi(sai[0], sai[1], them)
            nonce = self.headers["X-Nonce"]
            if route == "/may/su-kien" and phuong_thuc == "POST":
                return self.nhan_su_kien(c, khoa, than, nonce, route)
            if route == "/may/doi-soat" and phuong_thuc == "GET":
                return self.trang_doi_soat(c, khoa, url.query, nonce, route)
            if route == "/may/dieu-kien" and phuong_thuc == "POST" and CH["ten"] == "core":
                return self.dieu_kien(c, khoa, than, nonce, route)
            return self.loi(404, "khong-co-route")
        finally:
            c.close()

    def do_POST(self):
        self.xu_ly("POST")

    def do_GET(self):
        self.xu_ly("GET")

    def nhan_su_kien(self, c, khoa, than, nonce, route):
        try:
            sk = kyso.doc_json(than)
        except kyso.LoiJson as e:
            return self.loi(400, str(e))
        sai = kyso.kiem_su_kien(sk)
        if sai:
            return self.loi(400, sai)
        if "events:" + sk["loai"] not in khoa["pham_vi"]:
            return self.loi(403, "ngoai-pham-vi")
        c.execute("BEGIN IMMEDIATE")
        try:
            kq = ap_dung(c, sk)
            c.execute("COMMIT")
        except ValueError:
            c.execute("ROLLBACK")
            return self.loi(409, "xung-dot")
        self.tra(200, {"ket_qua": kq, "id": sk["id"]}, nonce, route)

    def trang_doi_soat(self, c, khoa, query, nonce, route):
        if "doisoat:doc" not in khoa["pham_vi"]:
            return self.loi(403, "ngoai-pham-vi")
        q = urllib.parse.parse_qs(query)
        sau = int(q.get("sau", ["0"])[0])
        rows = c.execute("SELECT seq, than FROM hop_thu_di WHERE seq>? AND trang_thai!='huy' ORDER BY seq LIMIT 50",
                         (sau,)).fetchall()
        trang = {"su_kien": [json.loads(t) for _, t in rows], "con_tro": rows[-1][0] if rows else sau}
        self.tra(200, trang, nonce, route)

    def dieu_kien(self, c, khoa, than, nonce, route):
        if "dieukien:hoi" not in khoa["pham_vi"]:
            return self.loi(403, "ngoai-pham-vi")
        ket_qua = "deny"
        try:
            hoi = kyso.doc_json(than)
            r = c.execute("SELECT dong_y FROM ho_so WHERE ma=?", (str(hoi["ma"]),)).fetchone()
            if r and r[0] == "co" and hoi["thao_tac"] in ("de-cu", "xem-ho-so"):
                ket_qua = "allow"
        except Exception:
            ket_qua = "deny"                    # mac dinh tu choi khi co bat ky loi nao
            hoi = {"ma": "", "thao_tac": ""}
        self.tra(200, {"ma": hoi.get("ma"), "thao_tac": hoi.get("thao_tac"), "ket_qua": ket_qua,
                       "het_han": int(time.time()) + 60}, nonce, route)

    # ---------- Tinh huong A: ve tinh
    def lead(self):
        bearer = self.headers.get("Authorization", "")[7:]
        vt = None
        for v in CH.get("ve_tinh", []):
            if v["bat"] and kyso.khop(kyso.bam(bearer.encode()), v["token_bam"]) and "lead" in v["pham_vi"]:
                vt = v
        if not vt:
            return self.loi(401, "token-ve-tinh-sai")
        than = self.doc_than()
        if than is None:
            return self.loi(413, "than-qua-lon")
        try:
            d = kyso.doc_json(than)
        except kyso.LoiJson as e:
            return self.loi(400, str(e))
        sdt = "".join(ch for ch in str(d.get("sdt", "")) if ch.isdigit())[:12]
        if len(sdt) < 9:
            return self.loi(400, "sdt-sai")
        c = ket_noi()
        try:
            c.execute("BEGIN IMMEDIATE")
            co = c.execute("SELECT 1 FROM lead WHERE sdt=?", (sdt,)).fetchone()
            if not co:   # chi lay truong cho phep; truong la (vd trang_thai) bi bo
                c.execute("INSERT INTO lead VALUES(?,?,?,?,?)", (sdt, str(d.get("ten", ""))[:60],
                          str(d.get("nhu_cau", ""))[:200], vt["id"], int(time.time())))
            c.execute("INSERT INTO lead_lich_su VALUES(?,?,?)", (sdt, vt["id"], int(time.time())))
            c.execute("COMMIT")
        finally:
            c.close()
        self.tra(200 if co else 201, {"ket_qua": "da-co" if co else "da-tao"})

    def cong(self, duong_dan):
        khoa_cong = self.headers.get("X-Khoa-Cong", "")
        vt = None
        for v in CH.get("ve_tinh", []):
            if kyso.khop(kyso.bam(khoa_cong.encode()), v["khoa_cong_bam"]):
                vt = v
        if khoa_cong and (not vt or not vt["cong_bat"]):
            return self.loi(403, "khoa-cong-tat")
        # Chi tin IP khach do ve tinh bao khi yeu cau mang dung khoa cong dang bat.
        ip = self.headers.get("X-IP-Khach", self.client_address[0]) if vt else self.client_address[0]
        if duong_dan not in TRANG_CONG:
            ghi_log("CONG", "duong-dan-la")
            duong_dan = "/trang/gioi-thieu"
        self.tra(200, {"trang": TRANG_CONG[duong_dan], "ip_khach_ghi_nhan": ip})


# ------------------------------------------------------------------ phia goi
def goi(phuong_thuc, route, than=b"", query="", nonce=None, ts=None):
    """Gui mot yeu cau may co ky toi ben kia. Tra ve (ma, tieu_de, than, nonce)."""
    k = CH["khoa_gui"]
    ts = ts or int(time.time())
    nonce = nonce or str(uuid.uuid4())
    u = urllib.parse.urlsplit(CH["doi_tac_url"])
    tieu_de = {"Authorization": "Bearer " + k["bearer"], "X-Khoa": k["id"], "X-Thoi-Gian": str(ts),
               "X-Nonce": nonce, "X-Chu-Ky": kyso.ky(k["ky"], kyso.chuoi_yeu_cau(phuong_thuc, route, ts, nonce, than)),
               "Content-Type": "application/json"}
    cn = http.client.HTTPConnection(u.hostname, u.port, timeout=5)
    cn.request(phuong_thuc, route + ("?" + query if query else ""), body=than or None, headers=tieu_de)
    r = cn.getresponse()
    return r.status, {k.lower(): v for k, v in r.getheaders()}, r.read(), nonce


def kiem_phan_hoi(route, nonce, tieu_de, than, pham_vi):
    """Kiem phan hoi 2xx co ky cua ben kia. Tra ve ma loi hoac None."""
    if os.environ.get("CHE_DO_THU") == "1" and CH.get("moi_truong") == "phat-trien":
        return None          # che do thu chi co tac dung o moi truong phat trien
    if kyso.bi_tat("chu-ky-phan-hoi"):
        return None
    if "x-chu-ky" not in tieu_de:
        return "khong-ky"
    khoa = kyso.tim_khoa(CH["khoa_nhan"], tieu_de.get("x-khoa", ""))
    if not khoa:
        return "khoa-khong-hieu-luc"
    if pham_vi not in khoa["pham_vi"]:
        return "thieu-pham-vi-phan-hoi"
    try:
        ts = int(tieu_de.get("x-thoi-gian", ""))
    except ValueError:
        return "thoi-gian-sai"
    if abs(time.time() - ts) > kyso.LECH_TOI_DA:
        return "lech-thoi-gian"
    if not kyso.khop(kyso.ky(khoa["ky"], kyso.chuoi_phan_hoi(route, ts, nonce, than)), tieu_de["x-chu-ky"]):
        return "chu-ky-sai"
    return None


def gui_outbox():
    """Worker gui: giu cho bang lease + fencing token, gui, kiem ACK, cap nhat chi khi fencing con dung."""
    c = ket_noi()
    if dang_cach_ly(c):
        print("Dang cach ly: khong gui.")
        return
    bay_gio = int(time.time())
    c.execute("BEGIN IMMEDIATE")
    viec = c.execute("SELECT seq, than, fencing FROM hop_thu_di WHERE trang_thai='cho' AND gui_sau<=? AND lease_den<? "
                     "ORDER BY seq LIMIT 20", (bay_gio, bay_gio)).fetchall()
    giu = []
    for seq, than, f in viec:
        c.execute("UPDATE hop_thu_di SET lease_den=?, fencing=? WHERE seq=?", (bay_gio + 30, f + 1, seq))
        giu.append((seq, than, f + 1))
    c.execute("COMMIT")
    for seq, than, f in giu:
        loi = None
        try:
            ma, td, tl, nonce = goi("POST", "/may/su-kien", than.encode())
            if ma == 200:
                loi = kiem_phan_hoi("/may/su-kien", nonce, td, tl, "phanhoi:ack")
                if not loi:
                    ack = json.loads(tl)
                    if ack.get("id") != json.loads(than)["id"] or ack.get("ket_qua") not in ("da-nhan", "trung"):
                        loi = "ack-khong-khop"
            else:
                loi = f"http-{ma}"
        except (OSError, ValueError) as e:
            loi = "mang-" + type(e).__name__
        if loi:
            ghi_log("ACK", loi)
            c.execute("UPDATE hop_thu_di SET lan_thu=lan_thu+1, so_lan_gui=so_lan_gui+1, "
                      "gui_sau=?+min(3600, 1<<(lan_thu+1)), lease_den=0, "
                      "trang_thai=CASE WHEN lan_thu+1>=8 THEN 'loi' ELSE 'cho' END WHERE seq=? AND fencing=?",
                      (int(time.time()), seq, f))
            print(f"seq={seq}: CHUA GIAO ({loi}), giu trong hang doi")
        else:
            n = c.execute("UPDATE hop_thu_di SET trang_thai='da-giao', so_lan_gui=so_lan_gui+1, lease_den=0 "
                          "WHERE seq=? AND fencing=?", (seq, f)).rowcount
            print(f"seq={seq}: DA GIAO" if n else f"seq={seq}: fencing cu, bo qua")
    if not giu:
        print("Khong co su kien cho gui.")


def keo_doi_soat():
    c = ket_noi()
    if dang_cach_ly(c):
        print("Dang cach ly: khong keo.")
        return
    r = c.execute("SELECT gia_tri FROM con_tro WHERE ten='doi_tac'").fetchone()
    sau = r[0] if r else 0
    try:
        ma, td, tl, nonce = goi("GET", "/may/doi-soat", query=f"sau={sau}")
    except OSError:
        print(f"Ben kia khong tra loi: con tro giu nguyen {sau}")
        return
    loi = f"http-{ma}" if ma != 200 else kiem_phan_hoi("/may/doi-soat", nonce, td, tl, "phanhoi:doisoat")
    if loi:
        ghi_log("DOISOAT", loi)
        print(f"Trang doi soat KHONG hop le ({loi}): khong luu gi, con tro giu nguyen {sau}")
        return
    trang = kyso.doc_json(tl)
    khoa = kyso.tim_khoa(CH["khoa_nhan"], td.get("x-khoa", "")) or {"pham_vi": []}
    c.execute("BEGIN IMMEDIATE")
    try:
        for sk in trang["su_kien"]:
            if kyso.kiem_su_kien(sk):
                raise ValueError("su-kien-sai")
            if not kyso.bi_tat("scope-trang") and "events:" + sk["loai"] not in khoa["pham_vi"]:
                raise ValueError("ngoai-pham-vi:" + sk["loai"])
            ap_dung(c, sk)
        c.execute("INSERT OR REPLACE INTO con_tro VALUES('doi_tac',?)", (int(trang["con_tro"]),))
        c.execute("COMMIT")
        print(f"Da doi soat {len(trang['su_kien'])} su kien, con tro {sau} -> {trang['con_tro']}")
    except ValueError as e:
        c.execute("ROLLBACK")
        ghi_log("DOISOAT", str(e))
        print(f"Tu choi CA TRANG ({e}): khong luu gi, con tro giu nguyen {sau}")


def hoi_dieu_kien(ma_hs, thao_tac):
    """Peer hoi Core. Fail-closed: moi loi deu thanh deny."""
    ket_qua = "deny"
    try:
        ma, td, tl, nonce = goi("POST", "/may/dieu-kien", kyso.ma_hoa({"ma": ma_hs, "thao_tac": thao_tac}))
        loi = f"http-{ma}" if ma != 200 else kiem_phan_hoi("/may/dieu-kien", nonce, td, tl, "phanhoi:dieukien")
        if loi:
            ghi_log("DIEUKIEN", loi)
        else:
            tl = kyso.doc_json(tl)
            if tl["ma"] == ma_hs and tl["thao_tac"] == thao_tac and tl["het_han"] >= time.time() \
                    and tl["het_han"] <= time.time() + 60 and tl["ket_qua"] == "allow":
                ket_qua = "allow"
    except Exception as e:
        ghi_log("DIEUKIEN", type(e).__name__)
    print(f"Dieu kien {ma_hs} {thao_tac}: {ket_qua}")
    return ket_qua


def cach_ly(lenh):
    c = ket_noi()
    if lenh == "bat":
        c.execute("INSERT OR REPLACE INTO trang_thai VALUES('cach_ly','bat')")
        c.execute("INSERT INTO nhat_ky VALUES(?,?,?)", (int(time.time()), "CACH-LY-BAT", "dong lenh"))
        print("Da BAT cach ly: moi route may tra 503, khong gui, khong keo.")
    elif lenh == "go":
        mk = sys.stdin.readline().strip()
        q = CH["quan_tri"]
        dung = kyso.khop(hashlib.pbkdf2_hmac("sha256", mk.encode(), bytes.fromhex(q["muoi"]), 200000).hex(), q["bam"])
        c.execute("INSERT INTO nhat_ky VALUES(?,?,?)", (int(time.time()), "CACH-LY-GO", "dung" if dung else "SAI-MAT-KHAU"))
        if not dung:
            sys.exit("Tu choi go cach ly: sai mat khau quan tri (da ghi nhat ky).")
        c.execute("INSERT OR REPLACE INTO trang_thai VALUES('cach_ly','tat')")
        print("Da GO cach ly.")
    else:
        print("Cach ly:", "BAT" if dang_cach_ly(c) else "tat")


def xem(bang):
    c = ket_noi()
    cot = {"hop_thu_di": "seq, loai, trang_thai, lan_thu, so_lan_gui", "hop_thu_den": "substr(id,1,8), loai",
           "ho_so": "*", "de_cu": "*", "quyen_xem": "*", "lead": "sdt, ten, nguon_dau", "lead_lich_su": "*",
           "con_tro": "*", "nonce": "count(*)", "nhat_ky": "ma, chi_tiet"}[bang]
    for r in c.execute(f"SELECT {cot} FROM {bang}"):
        print(" | ".join(str(x) for x in r))


def main():
    global CH, DB
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    os.umask(0o077)
    CH = json.load(open(sys.argv[1], encoding="utf-8"))
    DB = os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), CH["ten"] + ".db")
    tao_bang()
    lenh, ts = sys.argv[2], sys.argv[3:]
    if lenh == "chay":
        print(f"{CH['ten']} nghe 127.0.0.1:{CH['cong']}", flush=True)
        ThreadingHTTPServer(("127.0.0.1", CH["cong"]), XuLy).serve_forever()
    elif lenh == "tao-su-kien":
        tao_su_kien(*ts)
    elif lenh == "gui":
        gui_outbox()
    elif lenh == "keo":
        keo_doi_soat()
    elif lenh == "hoi":
        hoi_dieu_kien(*ts)
    elif lenh == "cach-ly":
        cach_ly(ts[0])
    elif lenh == "xem":
        xem(ts[0])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
