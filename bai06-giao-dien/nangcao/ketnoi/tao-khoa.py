#!/usr/bin/env python3
"""Sinh bo khoa va cau hinh cho Core, Peer, ve tinh. CHI DUNG TRONG LAB.

  python3 tao-khoa.py THU_MUC [--core-goi URL] [--han-ngay N]

Ket qua trong THU_MUC (quyen 0600):
  core.json, peer.json   cau hinh tung nut: khoa gui cua minh + khoa nhan cua ben kia (ban bam bearer)
  vetinh.env             token lead va khoa cong cua hai ve tinh
  quan-tri.txt           mat khau quan tri de go cach ly
Moi chieu mot bo khoa rieng (bearer + khoa ky), sinh tu bo tao so ngau nhien an toan, 32 byte.
"""
import hashlib
import json
import os
import secrets
import sys
import time

if len(sys.argv) < 2:
    sys.exit(__doc__)
thu_muc = sys.argv[1]
core_goi = "http://127.0.0.1:8102"
han_ngay = 90
if "--core-goi" in sys.argv:
    core_goi = sys.argv[sys.argv.index("--core-goi") + 1]
if "--han-ngay" in sys.argv:
    han_ngay = float(sys.argv[sys.argv.index("--han-ngay") + 1])
os.makedirs(thu_muc, exist_ok=True)
os.umask(0o077)


def bam(s):
    return hashlib.sha256(s.encode()).hexdigest()


def bo_khoa(ten, pham_vi):
    bearer, ky = secrets.token_hex(32), secrets.token_hex(32)
    gui = {"id": ten, "bearer": bearer, "ky": ky}
    nhan = {"id": ten, "bearer_bam": bam(bearer), "ky": ky, "pham_vi": pham_vi,
            "het_han": int(time.time() + han_ngay * 86400), "thu_hoi": False}
    return gui, nhan


# Chieu Core -> Peer: Core chi duoc dua su kien ho so/dong y; quyen phan hoi rieng.
c2p_gui, c2p_nhan = bo_khoa("c2p-1", ["events:ho-so", "events:dong-y", "events:rut-dong-y", "doisoat:doc",
                                      "phanhoi:ack", "phanhoi:doisoat", "phanhoi:dieukien"])
# Chieu Peer -> Core: Peer chi duoc dua ket qua de cu va quyen xem; duoc hoi dieu kien.
p2c_gui, p2c_nhan = bo_khoa("p2c-1", ["events:ket-qua-de-cu", "events:quyen-xem", "doisoat:doc", "dieukien:hoi",
                                      "phanhoi:ack", "phanhoi:doisoat"])

mat_khau = secrets.token_urlsafe(12)
muoi = secrets.token_hex(16)
quan_tri = {"muoi": muoi, "bam": hashlib.pbkdf2_hmac("sha256", mat_khau.encode(), bytes.fromhex(muoi), 200000).hex()}

ve_tinh, env = [], []
for ten, bat in (("vt-landing", True), ("vt-chatbot", False)):
    tok, kc = secrets.token_hex(32), secrets.token_hex(32)
    ve_tinh.append({"id": ten, "token_bam": bam(tok), "khoa_cong_bam": bam(kc), "bat": bat, "cong_bat": bat,
                    "pham_vi": ["lead"]})
    bien = ten.replace("vt-", "").upper()
    env += [f"TOKEN_{bien}={tok}", f"KHOA_CONG_{bien}={kc}"]

core = {"ten": "core", "cong": 8101, "doi_tac_url": core_goi, "moi_truong": "san-xuat", "gioi_han_phut": 120,
        "khoa_gui": c2p_gui, "khoa_nhan": [p2c_nhan], "ve_tinh": ve_tinh, "quan_tri": quan_tri}
peer = {"ten": "peer", "cong": 8102, "doi_tac_url": "http://127.0.0.1:8101", "moi_truong": "san-xuat",
        "gioi_han_phut": 120, "khoa_gui": p2c_gui, "khoa_nhan": [c2p_nhan], "quan_tri": quan_tri}

for ten, noi_dung in (("core.json", json.dumps(core, indent=1)), ("peer.json", json.dumps(peer, indent=1)),
                      ("vetinh.env", "\n".join(env) + "\n"), ("quan-tri.txt", mat_khau + "\n")):
    duong = os.path.join(thu_muc, ten)
    with open(duong, "w", encoding="utf-8") as f:
        f.write(noi_dung)
    os.chmod(duong, 0o600)
print(f"Da tao core.json, peer.json, vetinh.env, quan-tri.txt trong {thu_muc} (quyen 600)")
