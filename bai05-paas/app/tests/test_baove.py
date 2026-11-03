"""Phép thử hành vi cho Phần E: kiểm chứng các biện pháp bảo vệ của ứng dụng mẫu.

Chạy:  cd /srv/demoapp/app && ../venv/bin/python -m unittest -v tests.test_baove
Mỗi phép thử dùng một cơ sở dữ liệu tạm, không đụng tới dữ liệu đang chạy.
"""
import os
import re
import tempfile
import unittest

_tmp = tempfile.mkdtemp()
os.environ["DEMOAPP_DB"] = os.path.join(_tmp, "test.db")
os.environ["DEMOAPP_ENV_FILE"] = os.path.join(_tmp, "khong-co.env")
os.environ["DEMOAPP_SECRET_KEY"] = "khoa-chi-de-kiem-thu"

from app import app  # noqa: E402


class BaoVeUngDung(unittest.TestCase):
    def setUp(self):
        app.config["TESTING"] = True
        self.client = app.test_client()

    def dang_nhap(self, client, user, password):
        return client.post("/login", data={"username": user, "password": password})

    def tao_phieu(self, client, code, note):
        r = client.post("/dangky", data={"course_code": code, "note": note})
        self.assertEqual(r.status_code, 302)
        return int(re.search(r"/phieu/(\d+)", r.headers["Location"]).group(1))

    def test_1_tim_kiem_co_dau_nhay(self):
        """A05: từ khóa có dấu nháy được coi là dữ liệu, trang trả về bình thường."""
        self.dang_nhap(self.client, "an", "An@12345")
        r = self.client.get("/timkiem", query_string={"q": "Mật mã' ứng dụng"})
        self.assertEqual(r.status_code, 200)
        r = self.client.get("/timkiem", query_string={"q": "điện toán"})
        self.assertIn("INT205", r.get_data(as_text=True))

    def test_2_khong_xem_duoc_phieu_nguoi_khac(self):
        """A01: người dùng an không mở được phiếu của binh."""
        binh = app.test_client()
        self.dang_nhap(binh, "binh", "Binh@12345")
        phieu_binh = self.tao_phieu(binh, "INT210", "phiếu của Bình")
        self.dang_nhap(self.client, "an", "An@12345")
        r = self.client.get(f"/phieu/{phieu_binh}")
        self.assertEqual(r.status_code, 404)
        self.assertEqual(binh.get(f"/phieu/{phieu_binh}").status_code, 200)

    def test_3_ghi_chu_hien_thi_nguyen_van(self):
        """A05: ghi chú có thẻ HTML được hiển thị dưới dạng chữ, không thành thẻ."""
        self.dang_nhap(self.client, "an", "An@12345")
        pid = self.tao_phieu(self.client, "INT205", "<b>đăng ký sớm</b>")
        html = self.client.get(f"/phieu/{pid}").get_data(as_text=True)
        self.assertIn("&lt;b&gt;đăng ký sớm&lt;/b&gt;", html)
        self.assertNotIn("<b>đăng ký sớm</b>", html)

    def test_4_cookie_phien_an_toan(self):
        """A07: cookie phiên có HttpOnly, Secure, SameSite=Lax."""
        r = self.dang_nhap(self.client, "an", "An@12345")
        cookie = r.headers.get("Set-Cookie", "")
        self.assertIn("HttpOnly", cookie)
        self.assertIn("Secure", cookie)
        self.assertIn("SameSite=Lax", cookie)

    def test_5_chua_dang_nhap_bi_chuyen_ve_trang_dang_nhap(self):
        """A01: mặc định từ chối khi chưa đăng nhập."""
        r = app.test_client().get("/phieu/1")
        self.assertEqual(r.status_code, 302)
        self.assertIn("/login", r.headers["Location"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
