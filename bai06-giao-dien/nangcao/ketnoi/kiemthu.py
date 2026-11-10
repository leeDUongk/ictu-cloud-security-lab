#!/usr/bin/env python3
"""Bo kiem thu ket noi Core - ve tinh - Peer (ca kiem thu A7, B12). CHI DUNG TRONG LAB.

  python3 kiemthu.py                     chay tat ca ca kiem thu
  LAB_TAT_KIEM=nonce python3 kiemthu.py  thu dot bien: tat mot buoc kiem, bo kiem thu phai co ca TRUOT
                                         (nonce | chu-ky-phan-hoi | scope-trang)
Tu dung Core :8201, Peer :8202, hai proxy gia mao :8203 (Core->Peer) va :8204 (Peer->Core) trong thu muc tam.
"""
import http.client
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid

DAY = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, DAY)
import kyso  # noqa: E402

TMP = tempfile.mkdtemp(prefix="ketnoi-")
PY = sys.executable
KQ = []
TIEN_TRINH = {}


def lenh(*a, nhap=None, env=None):
    r = subprocess.run([PY, os.path.join(DAY, a[0])] + list(a[1:]), capture_output=True, text=True, input=nhap,
                       env={**os.environ, **(env or {})}, cwd=TMP, timeout=30)
    return r.returncode, r.stdout          # stderr la nhat ky ma loi, khong dung de cham


def nut(ten, *a, nhap=None, env=None):
    return lenh("nut.py", os.path.join(TMP, ten + ".json"), *a, nhap=nhap, env=env)


def cau_hinh(ten):
    return json.load(open(os.path.join(TMP, ten + ".json")))


def luu(ten, ch):
    json.dump(ch, open(os.path.join(TMP, ten + ".json"), "w"))


def dem(ten, sql, *tham_so):
    c = sqlite3.connect(os.path.join(TMP, ten + ".db"))
    r = c.execute(sql, tham_so).fetchone()
    c.close()
    return r[0] if r else None


def che_do(tep, gia_tri):
    open(os.path.join(TMP, tep), "w").write(gia_tri)


def khoi_dong(ten, args):
    p = subprocess.Popen([PY, os.path.join(DAY, args[0])] + args[1:], cwd=TMP, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL)
    TIEN_TRINH[ten] = p


def cho_cong(cong):
    for _ in range(50):
        try:
            http.client.HTTPConnection("127.0.0.1", cong, timeout=1).connect()
            return
        except OSError:
            time.sleep(0.1)


def gui_tho(cong, phuong_thuc, route, than=b"", khoa=None, **sua):
    """Gui yeu cau may tu tay, co the lam hong tung phan de thu."""
    ts = sua.get("ts", int(time.time()))
    nonce = sua.get("nonce", str(uuid.uuid4()))
    td = {"Content-Type": "application/json"}
    if khoa:
        route_ky = sua.get("route_ky", route)
        td.update({"Authorization": "Bearer " + sua.get("bearer", khoa["bearer"]), "X-Khoa": khoa["id"],
                   "X-Thoi-Gian": str(ts), "X-Nonce": nonce,
                   "X-Chu-Ky": sua.get("chu_ky", kyso.ky(khoa["ky"], kyso.chuoi_yeu_cau(phuong_thuc, route_ky, ts,
                                                                                          nonce, than)))})
    td.update(sua.get("them", {}))
    cn = http.client.HTTPConnection("127.0.0.1", cong, timeout=5)
    cn.request(phuong_thuc, route, body=than or None, headers=td)
    r = cn.getresponse()
    return r.status, {k.lower(): v for k, v in r.getheaders()}, r.read()


def ca(ma, mo_ta, mong_doi, ham):
    try:
        dat, thuc_te = ham()
    except Exception as e:
        dat, thuc_te = False, "ngoai le " + type(e).__name__
    KQ.append((ma, mo_ta, mong_doi, thuc_te, dat))


def su_kien(loai, ma, gia_tri, sk_id=None):
    return {"id": sk_id or str(uuid.uuid4()), "phien_ban": int(time.time() * 1000), "loai": loai, "ma": ma,
            "gia_tri": gia_tri}


def main():
    lenh("tao-khoa.py", TMP, "--core-goi", "http://127.0.0.1:8203")
    core, peer = cau_hinh("core"), cau_hinh("peer")
    core.update(cong=8201, gioi_han_phut=40)
    peer.update(cong=8202, doi_tac_url="http://127.0.0.1:8204")
    luu("core", core)
    luu("peer", peer)
    env = dict(l.split("=", 1) for l in open(os.path.join(TMP, "vetinh.env")).read().split())
    che_do("cd-c2p", "trong-suot")
    che_do("cd-p2c", "trong-suot")
    khoi_dong("core", ["nut.py", os.path.join(TMP, "core.json"), "chay"])
    khoi_dong("peer", ["nut.py", os.path.join(TMP, "peer.json"), "chay"])
    khoi_dong("px1", ["gia-mao.py", "8203", "http://127.0.0.1:8202", os.path.join(TMP, "cd-c2p")])
    khoi_dong("px2", ["gia-mao.py", "8204", "http://127.0.0.1:8201", os.path.join(TMP, "cd-p2c")])
    for cong in (8201, 8202, 8203, 8204):
        cho_cong(cong)
    p2c = peer["khoa_gui"]          # khoa Peer dung de goi Core
    c2p = core["khoa_gui"]

    # ---------------- Tinh huong A: ve tinh
    def lead(token, obj):
        return gui_tho(8201, "POST", "/may/lead", kyso.ma_hoa(obj), them={"Authorization": "Bearer " + token})
    ld = {"ten": "Khach A", "sdt": "0912000001", "nhu_cau": "tu van"}
    ca("A1", "Lead khong token", "401", lambda: (lambda r: (r[0] == 401, str(r[0])))(
        gui_tho(8201, "POST", "/may/lead", kyso.ma_hoa(ld))))
    ca("A2", "Lead token sai", "401", lambda: (lambda r: (r[0] == 401, str(r[0])))(lead("ab" * 32, ld)))
    ca("A3", "Lead token ve tinh da tat", "401", lambda: (lambda r: (r[0] == 401, str(r[0])))(
        lead(env["TOKEN_CHATBOT"], ld)))
    ca("A4", "Lead hop le", "201, tao ban ghi", lambda: (lambda r: (r[0] == 201 and dem("core", "SELECT count(*) FROM lead") == 1,
                                                          f"{r[0]}, {dem('core', 'SELECT count(*) FROM lead')} ban ghi"))(
        lead(env["TOKEN_LANDING"], ld)))
    ca("A5", "Lead trung so dien thoai", "khong tao moi, them lich su",
       lambda: (lambda r: (dem("core", "SELECT count(*) FROM lead") == 1 and dem("core", "SELECT count(*) FROM lead_lich_su") == 2,
                           f"{r[0]}, lead={dem('core', 'SELECT count(*) FROM lead')}, lich su={dem('core', 'SELECT count(*) FROM lead_lich_su')}"))(
           lead(env["TOKEN_LANDING"], {**ld, "ten": "Ten khac"})))
    ca("A6", "Lead co truong la trang_thai", "truong la bi bo",
       lambda: (lambda r: (r[0] == 201 and "trang_thai" not in str(dem("core", "SELECT ten||nguon_dau FROM lead WHERE sdt='0912000002'")),
                           f"{r[0]}, luu: {dem('core', 'SELECT ten FROM lead WHERE sdt=?', '0912000002')}"))(
           lead(env["TOKEN_LANDING"], {"ten": "Khach B", "sdt": "0912000002", "trang_thai": "vip"})))
    ca("A7", "Cong voi khoa ve tinh da tat", "403", lambda: (lambda r: (r[0] == 403, str(r[0])))(
        gui_tho(8201, "GET", "/cong/trang/gioi-thieu", them={"X-Khoa-Cong": env["KHOA_CONG_CHATBOT"]})))
    ca("A8", "Gia X-IP-Khach khi khong co khoa", "dung IP ket noi",
       lambda: (lambda r: (json.loads(r[2])["ip_khach_ghi_nhan"] == "127.0.0.1", json.loads(r[2])["ip_khach_ghi_nhan"]))(
           gui_tho(8201, "GET", "/cong/trang/gioi-thieu", them={"X-IP-Khach": "203.0.113.9"})))
    ca("A9", "Co khoa cong dung: tin X-IP-Khach", "203.0.113.9",
       lambda: (lambda r: (json.loads(r[2])["ip_khach_ghi_nhan"] == "203.0.113.9", json.loads(r[2])["ip_khach_ghi_nhan"]))(
           gui_tho(8201, "GET", "/cong/trang/gioi-thieu", them={"X-IP-Khach": "203.0.113.9",
                                                                  "X-Khoa-Cong": env["KHOA_CONG_LANDING"]})))
    ca("A10", "Phan hoi cong co no-store", "Cache-Control: no-store",
       lambda: (lambda r: (r[1].get("cache-control") == "no-store", r[1].get("cache-control")))(
           gui_tho(8201, "GET", "/cong/admin/xuat-du-lieu")))

    # ---------------- Tinh huong B: kiem yeu cau den (gui vao Core bang khoa cua Peer)
    def so_hang():
        return dem("core", "SELECT count(*) FROM nonce") + dem("core", "SELECT count(*) FROM hop_thu_den")
    ok = kyso.ma_hoa(su_kien("ket-qua-de-cu", "HS-0001", "nhan"))

    def yc_sai(ma_mong, **sua):
        def f():
            truoc = so_hang()
            r = gui_tho(8201, "POST", "/may/su-kien", sua.pop("than", ok), p2c if sua.pop("co_khoa", True) else None, **sua)
            return r[0] == ma_mong and so_hang() == truoc, f"{r[0]}, DB {'khong doi' if so_hang() == truoc else 'DOI'}"
        return f
    ca("B1", "Khong bearer", "401, DB khong doi", yc_sai(401, co_khoa=False))
    ca("B2", "Bearer sai", "401, DB khong doi", yc_sai(401, bearer="00" * 32))
    ca("B3", "Chu ky sai", "401, DB khong doi", yc_sai(401, chu_ky="11" * 32))
    ca("B4", "Ky cho route khac", "401, DB khong doi", yc_sai(401, route_ky="/may/doi-soat"))
    ca("B5", "Lech thoi gian 301 giay", "401, DB khong doi", yc_sai(401, ts=int(time.time()) - 301))

    def phat_lai():
        n = str(uuid.uuid4())
        sk = kyso.ma_hoa(su_kien("ket-qua-de-cu", "HS-0001", "nhan"))
        r1 = gui_tho(8201, "POST", "/may/su-kien", sk, p2c, nonce=n)
        r2 = gui_tho(8201, "POST", "/may/su-kien", sk, p2c, nonce=n)
        return r1[0] == 200 and r2[0] == 401, f"lan 1: {r1[0]}, lan 2: {r2[0]}"
    ca("B6", "Gui lai dung yeu cau cu (cung nonce)", "lan 2: 401", phat_lai)
    def ngoai_pham_vi():
        # Chu ky hop le nen nonce duoc ghi (chong phat lai), nhung su kien khong vao hop thu den.
        truoc = dem("core", "SELECT count(*) FROM hop_thu_den")
        r = gui_tho(8201, "POST", "/may/su-kien", kyso.ma_hoa(su_kien("rut-dong-y", "HS-0001", "rut")), p2c)
        sau = dem("core", "SELECT count(*) FROM hop_thu_den")
        return r[0] == 403 and sau == truoc, f"{r[0]}, inbox {'khong doi' if sau == truoc else 'DOI'}"
    ca("B7", "Khoa Peer dua su kien rut-dong-y", "403, inbox khong doi", ngoai_pham_vi)
    ca("B8", "Than lon hon 64 KB", "413", lambda: (lambda r: (r[0] == 413, str(r[0])))(
        gui_tho(8201, "POST", "/may/su-kien", b"x" * 70000, p2c)))
    ca("B9", "JSON co khoa trung", "400", lambda: (lambda r: (r[0] == 400, str(r[0])))(
        gui_tho(8201, "POST", "/may/su-kien", ok[:-1] + b',"loai":"quyen-xem"}', p2c)))
    ca("B10", "Truong ngoai danh sach trang (ho_ten)", "400", lambda: (lambda r: (r[0] == 400, str(r[0])))(
        gui_tho(8201, "POST", "/may/su-kien", kyso.ma_hoa({**su_kien("quyen-xem", "HS-0001", "cap"), "ho_ten": "X"}), p2c)))

    # ---------------- Kiem phan hoi (Core gui su kien sang Peer qua proxy :8203)
    def gui_voi(che, chuan_bi=None, khoi_phuc=None, env_gui=None):
        def f():
            che_do("cd-c2p", che)
            ma = "HS-%04d" % (100 + len(KQ))
            nut("core", "tao-su-kien", "ho-so", ma, "cntt")
            if chuan_bi:
                chuan_bi()
            _, out = nut("core", "gui", env=env_gui)
            if khoi_phuc:
                khoi_phuc()
            tt = dem("core", "SELECT trang_thai FROM hop_thu_di WHERE than LIKE ?", f'%"{ma}"%')
            o_peer = dem("peer", "SELECT count(*) FROM ho_so WHERE ma=?", ma)
            che_do("cd-c2p", "trong-suot")
            dong = (out.strip().splitlines() or [""])[-1]       # dong cuoi la su kien moi nhat (seq lon nhat)
            return tt, o_peer, dong[dong.find("(") + 1:dong.find(")")] if "(" in dong else dong
        return f

    def p_dung():
        tt, op, out = gui_voi("trong-suot")()
        return tt == "da-giao" and op == 1, f"{tt}, Peer co {op}"
    ca("P1", "ACK ky dung", "da-giao", p_dung)

    def p_sai(che, **kw):
        def f():
            tt, op, out = gui_voi(che, **kw)()
            return tt == "cho", f"{tt} ({out})"
        return f
    ca("P2", "ACK bi bo chu ky", "con cho", p_sai("bo-chu-ky"))
    ca("P3", "Doi 1 byte than ACK sau khi ky", "con cho", p_sai("doi-than"))
    ca("P4", "ACK gia, su kien khong toi Peer", "con cho", p_sai("ack-gia"))
    nut("core", "tao-su-kien", "ho-so", "HS-0050", "cntt")           # lay ACK that dau tien cho proxy
    che_do("cd-c2p", "phat-lai-ack")
    nut("core", "gui")
    ca("P5", "ACK cu phat lai (ky nonce khac)", "con cho", p_sai("phat-lai-ack"))

    def doi_khoa(truong, gia_tri):
        def f():
            ch = cau_hinh("core")
            ch["khoa_nhan"][0][truong] = gia_tri
            luu("core", ch)
        return f
    goc = cau_hinh("core")["khoa_nhan"][0]
    ca("P6", "ACK ky bang khoa da thu hoi", "con cho", p_sai("trong-suot", chuan_bi=doi_khoa("thu_hoi", True),
                                                          khoi_phuc=doi_khoa("thu_hoi", False)))
    ca("P7", "ACK ky bang khoa het han", "con cho", p_sai("trong-suot", chuan_bi=doi_khoa("het_han", 1),
                                                       khoi_phuc=doi_khoa("het_han", goc["het_han"])))
    ca("P8", "Khoa thieu quyen phanhoi:ack", "con cho",
       p_sai("trong-suot", chuan_bi=doi_khoa("pham_vi", [p for p in goc["pham_vi"] if p != "phanhoi:ack"]),
             khoi_phuc=doi_khoa("pham_vi", goc["pham_vi"])))
    ca("P9", "CHE_DO_THU=1 o san xuat", "bi bo qua, con cho", p_sai("bo-chu-ky", env_gui={"CHE_DO_THU": "1"}))

    # ---------------- Doi soat theo cursor (Core keo trang cua Peer qua proxy)
    def con_tro():
        return dem("core", "SELECT gia_tri FROM con_tro WHERE ten='doi_tac'") or 0
    nut("peer", "tao-su-kien", "ket-qua-de-cu", "HS-0001", "nhan")
    nut("peer", "tao-su-kien", "quyen-xem", "HS-0001", "cap")

    def k_dung():
        _, out = nut("core", "keo")
        return con_tro() == 2 and dem("core", "SELECT quyen FROM quyen_xem WHERE ma='HS-0001'") == "cap", f"con tro {con_tro()}"
    ca("K1", "Trang doi soat ky dung", "luu 2, con tro 0->2", k_dung)
    nut("peer", "tao-su-kien", "ket-qua-de-cu", "HS-0002", "tu-choi")

    def k_sai(che):
        def f():
            truoc = con_tro()
            che_do("cd-c2p", che)
            nut("core", "keo")
            che_do("cd-c2p", "trong-suot")
            return con_tro() == truoc and dem("core", "SELECT count(*) FROM quyen_xem WHERE ma='HS-0003'") == 0, \
                f"con tro {truoc}->{con_tro()}"
        return f
    ca("K2", "Trang bi chen su kien cap quyen", "khong luu, con tro dung", k_sai("chen-su-kien"))
    ca("K3", "Trang bi bo chu ky", "khong luu, con tro dung", k_sai("bo-chu-ky"))

    def k_offline():
        TIEN_TRINH["peer"].terminate()
        TIEN_TRINH["peer"].wait()
        truoc = con_tro()
        nut("core", "keo")
        khoi_dong("peer", ["nut.py", os.path.join(TMP, "peer.json"), "chay"])
        cho_cong(8202)
        return con_tro() == truoc, f"con tro {truoc}->{con_tro()}"
    ca("K4", "Peer offline luc doi soat", "con tro dung", k_offline)
    nut("peer", "tao-su-kien", "rut-dong-y", "HS-0009", "rut")      # Peer khong co quyen loai nay
    ca("K5", "Trang co 1 su kien ngoai scope khoa ky", "tu choi ca trang", k_sai("trong-suot"))

    # ---------------- Toan ven
    def trung():
        sk = kyso.ma_hoa(su_kien("ket-qua-de-cu", "HS-0007", "nhan"))
        r1 = gui_tho(8201, "POST", "/may/su-kien", sk, p2c)
        r2 = gui_tho(8201, "POST", "/may/su-kien", sk, p2c)
        return json.loads(r2[2])["ket_qua"] == "trung", f"{json.loads(r1[2])['ket_qua']}, {json.loads(r2[2])['ket_qua']}"
    ca("T1", "Cung su kien gui 2 lan (nonce khac)", "lan 2: trung", trung)

    def xung_dot():
        i = str(uuid.uuid4())
        gui_tho(8201, "POST", "/may/su-kien", kyso.ma_hoa(su_kien("ket-qua-de-cu", "HS-0008", "nhan", i)), p2c)
        r = gui_tho(8201, "POST", "/may/su-kien", kyso.ma_hoa(su_kien("ket-qua-de-cu", "HS-0008", "tu-choi", i)), p2c)
        return r[0] == 409, str(r[0])
    ca("T2", "Cung ID, than khac", "409 xung dot", xung_dot)

    def hai_worker():
        # Chi dem su kien cua ca nay (HS-03xx): su kien cu den han gui lai cung co the duoc giao trong luc nay.
        for i in range(6):
            nut("core", "tao-su-kien", "ho-so", "HS-%04d" % (300 + i), "ketoan")
        p = [subprocess.Popen([PY, os.path.join(DAY, "nut.py"), os.path.join(TMP, "core.json"), "gui"], cwd=TMP,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) for _ in range(2)]
        for x in p:
            x.wait()
        gui = dem("core", "SELECT sum(so_lan_gui) FROM hop_thu_di WHERE than LIKE '%HS-03%'")
        moi = dem("peer", "SELECT count(*) FROM ho_so WHERE ma LIKE 'HS-03%'")
        return gui == 6 and moi == 6, f"so lan gui {gui}, Peer nhan {moi}"
    ca("T3", "Hai worker gui cung luc 6 su kien", "moi su kien gui 1 lan", hai_worker)

    def rut_cuoi():
        nut("core", "tao-su-kien", "ho-so", "HS-0400", "dien")
        nut("core", "gui")
        nut("core", "tao-su-kien", "rut-dong-y", "HS-0400", "rut")
        nut("core", "gui")
        gui_tho(8202, "POST", "/may/su-kien", kyso.ma_hoa(su_kien("dong-y", "HS-0400", "co")), c2p)
        return dem("peer", "SELECT dong_y FROM ho_so WHERE ma='HS-0400'") == "rut", \
            dem("peer", "SELECT dong_y FROM ho_so WHERE ma='HS-0400'")
    ca("T4", "Dong y lai sau khi rut", "van rut", rut_cuoi)

    def huy_snapshot():
        nut("core", "tao-su-kien", "ho-so", "HS-0401", "dien")
        nut("core", "tao-su-kien", "rut-dong-y", "HS-0401", "rut")
        return dem("core", "SELECT trang_thai FROM hop_thu_di WHERE loai='ho-so' AND than LIKE '%HS-0401%'") == "huy", \
            dem("core", "SELECT trang_thai FROM hop_thu_di WHERE loai='ho-so' AND than LIKE '%HS-0401%'")
    ca("T5", "Rut dong y khi snapshot con cho gui", "snapshot bi huy", huy_snapshot)

    # ---------------- Hoi dieu kien (Peer hoi Core qua proxy :8204)
    def hoi(ma, mong, che="trong-suot"):
        def f():
            che_do("cd-p2c", che)
            _, out = nut("peer", "hoi", ma, "de-cu")
            che_do("cd-p2c", "trong-suot")
            kq = out.strip().split()[-1]
            return kq == mong, kq
        return f
    nut("core", "tao-su-kien", "ho-so", "HS-0500", "cntt")
    ca("D1", "Ho so con dong y", "allow", hoi("HS-0500", "allow"))
    ca("D2", "Ho so da rut dong y", "deny", hoi("HS-0400", "deny"))
    ca("D3", "Proxy sua deny thanh allow", "deny (fail-closed)", hoi("HS-0400", "deny", "doi-than"))

    # ---------------- Van hanh
    def cach_ly():
        nut("core", "cach-ly", "bat")
        truoc = so_hang()
        r = gui_tho(8201, "POST", "/may/su-kien", kyso.ma_hoa(su_kien("ket-qua-de-cu", "HS-0001", "nhan")), p2c)
        return r[0] == 503 and so_hang() == truoc, f"{r[0]}, DB {'khong doi' if so_hang() == truoc else 'DOI'}"
    ca("V1", "Bat cach ly", "503, DB khong doi", cach_ly)

    def go_sai():
        ma, out = nut("core", "cach-ly", "go", nhap="sai-mat-khau\n")
        return ma != 0 and dem("core", "SELECT count(*) FROM nhat_ky WHERE chi_tiet='SAI-MAT-KHAU'") == 1, \
            "tu choi, co nhat ky" if ma else "DA GO"
    ca("V2", "Go cach ly sai mat khau", "tu choi, co nhat ky", go_sai)

    def go_dung():
        mk = open(os.path.join(TMP, "quan-tri.txt")).read()
        ma, out = nut("core", "cach-ly", "go", nhap=mk)
        return ma == 0, out.strip()
    ca("V3", "Go cach ly dung mat khau", "da go", go_dung)

    def tan_suat():
        for i in range(45):
            r = gui_tho(8201, "GET", "/may/doi-soat", b"", p2c)
            if r[0] == 429:
                return "retry-after" in r[1], f"429 o yeu cau {i + 1}, Retry-After={r[1].get('retry-after')}"
        return False, "khong co 429"
    ca("V4", "Qua 40 yeu cau/phut", "429 + Retry-After", tan_suat)

    for p in TIEN_TRINH.values():
        p.terminate()
    # In bang ket qua
    print(f"{'Ma':<4} {'Ca kiem thu':<40} {'Mong doi':<26} {'Thuc te':<30} KQ")
    for ma, mt, md, tt, d in KQ:
        print(f"{ma:<4} {mt[:40]:<40} {md[:26]:<26} {str(tt)[:30]:<30} {'DAT' if d else 'TRUOT'}")
    truot = sum(1 for k in KQ if not k[4])
    tat = os.environ.get("LAB_TAT_KIEM")
    print(f"Tong: {len(KQ)} ca, DAT {len(KQ) - truot}, TRUOT {truot}" + (f"  (LAB_TAT_KIEM={tat})" if tat else ""))
    shutil.rmtree(TMP, ignore_errors=True)
    sys.exit(1 if truot else 0)


if __name__ == "__main__":
    main()
