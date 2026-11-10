"""Thu vien dung chung cho Bai tap nang cao 3 (ket noi may chu - may chu): ky, kiem, doc JSON an toan.

Hop dong ky (ca hai ben phai lam GIONG HET nhau, kiem bang vector test chung):
  Yeu cau : METHOD \n ROUTE \n TIMESTAMP \n NONCE \n sha256(than nhan duoc)
  Phan hoi: RESPONSE \n ROUTE \n TIMESTAMP \n NONCE_CUA_YEU_CAU \n sha256(than gui di)
  ROUTE la duong dan khong co query, vd /may/su-kien. Chu ky = HMAC-SHA256(khoa ky, chuoi chuan), hex.
CHI DUNG TRONG LAB.
"""
import hashlib
import hmac
import json
import os
import time

LECH_TOI_DA = 300          # giay, do lech dong ho cho phep
NONCE_SONG = 600           # giay, thoi gian nho nonce
THAN_TOI_DA = 64 * 1024    # byte

# Truong cho phep trong mot su kien (danh sach trang). Khong ten, khong giay to, khong ghi chu.
TRUONG_SU_KIEN = {"id", "phien_ban", "loai", "ma", "gia_tri"}
GIA_TRI_HOP_LE = {
    "ho-so": {"cntt", "ketoan", "dien"},           # ma nghe cua ho so an danh
    "dong-y": {"co"},
    "rut-dong-y": {"rut"},
    "ket-qua-de-cu": {"nhan", "tu-choi"},
    "quyen-xem": {"cap", "thu-hoi"},
}


def bam(du_lieu):
    return hashlib.sha256(du_lieu).hexdigest()


def chuoi_yeu_cau(phuong_thuc, route, ts, nonce, than):
    return "\n".join([phuong_thuc, route, str(ts), nonce, bam(than)]).encode()


def chuoi_phan_hoi(route, ts, nonce_yeu_cau, than):
    return "\n".join(["RESPONSE", route, str(ts), nonce_yeu_cau, bam(than)]).encode()


def ky(khoa_hex, chuoi):
    return hmac.new(bytes.fromhex(khoa_hex), chuoi, hashlib.sha256).hexdigest()


def khop(a, b):
    """So sanh thoi gian hang, tranh do ri thong tin qua thoi gian."""
    return hmac.compare_digest(str(a).encode(), str(b).encode())


def bi_tat(ten):
    """Chi de thu dot bien trong lab: LAB_TAT_KIEM=nonce,chu-ky-phan-hoi,scope-trang tat tung buoc kiem."""
    return ten in os.environ.get("LAB_TAT_KIEM", "").split(",")


def tim_khoa(ds_khoa, khoa_id, bay_gio=None):
    """Tra ve khoa con hieu luc (chua thu hoi, chua het han) theo id, hoac None."""
    bay_gio = bay_gio or time.time()
    for k in ds_khoa:
        if khop(k["id"], khoa_id) and not k.get("thu_hoi") and k.get("het_han", 0) > bay_gio:
            return k
    return None


class LoiJson(ValueError):
    pass


def doc_json(than):
    """Phan tich JSON: tu choi khoa trung, chi nhan doi tuong."""
    def khong_trung(cap):
        d = {}
        for k, v in cap:
            if k in d:
                raise LoiJson("khoa-trung")
            d[k] = v
        return d
    try:
        obj = json.loads(than.decode("utf-8"), object_pairs_hook=khong_trung)
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise LoiJson("json-sai")
    if not isinstance(obj, dict):
        raise LoiJson("json-sai")
    return obj


def kiem_su_kien(sk):
    """Danh sach trang truong va gia tri. Tra ve ma loi hoac None."""
    if set(sk) - TRUONG_SU_KIEN or set(sk) != TRUONG_SU_KIEN:
        return "truong-sai"
    if sk["loai"] not in GIA_TRI_HOP_LE or sk["gia_tri"] not in GIA_TRI_HOP_LE[sk["loai"]]:
        return "gia-tri-sai"
    if not isinstance(sk["phien_ban"], int) or not str(sk["ma"]).startswith("HS-") or len(str(sk["ma"])) > 20:
        return "gia-tri-sai"
    return None


def ma_hoa(obj):
    """Encode JSON MOT lan; ky va gui dung chuoi byte nay."""
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")


if __name__ == "__main__":
    # python3 kyso.py vector-test.json : tu kiem cai dat nay voi vector test chung cua hop dong.
    import sys
    v = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "vector-test.json", encoding="utf-8"))
    y, p = v["yeu_cau"], v["phan_hoi"]
    cy = chuoi_yeu_cau(y["phuong_thuc"], y["route"], y["thoi_gian"], y["nonce"], y["than"].encode())
    cp = chuoi_phan_hoi(p["route"], p["thoi_gian"], p["nonce_yeu_cau"], p["than"].encode())
    for ten, chuoi, mong in (("Yeu cau", cy, y["chu_ky_mong_doi"]), ("Phan hoi", cp, p["chu_ky_mong_doi"])):
        tinh = ky(v["khoa_ky"], chuoi)
        print(f"--- {ten}: chuoi chuan (moi dong mot thanh phan)")
        print(chuoi.decode())
        print(f"chu ky tinh duoc : {tinh}")
        print(f"chu ky hop dong  : {mong}  -> {'KHOP' if khop(tinh, mong) else 'KHONG KHOP'}")
