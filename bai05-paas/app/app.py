"""Ứng dụng mẫu Bài 5: đăng ký học phần (Flask + SQLite).

Ứng dụng áp dụng các biện pháp của mục 5.4 (tham số hóa, kiểm tra quyền sở hữu,
khuôn mẫu tự mã hóa, cookie an toàn, bí mật ngoài mã nguồn). Chỉ chạy trong máy ảo lab.
"""
import os
import sqlite3
from functools import wraps

from flask import Flask, abort, g, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash


def load_env_file(path):
    """Nạp các dòng KHOA=GIATRI từ tệp bí mật (quyền 600) vào os.environ."""
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())


load_env_file(os.environ.get("DEMOAPP_ENV_FILE", "/etc/demoapp/env"))

app = Flask(__name__)
app.config.update(
    SECRET_KEY=os.environ.get("DEMOAPP_SECRET_KEY", "chi-dung-khi-kiem-thu"),
    DATABASE=os.environ.get("DEMOAPP_DB", "/var/lib/demoapp/demo.db"),
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SECURE=os.environ.get("DEMOAPP_COOKIE_SECURE", "1") == "1",
    SESSION_COOKIE_SAMESITE="Lax",
)

COURSES = [
    ("INT101", "Nhập môn an toàn thông tin"),
    ("INT205", "An toàn điện toán đám mây"),
    ("INT210", "Mật mã ứng dụng"),
    ("INT230", "Lập trình web an toàn"),
]
USERS = [("an", "An@12345"), ("binh", "Binh@12345")]


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(app.config["DATABASE"])
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    db = get_db()
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY, username TEXT UNIQUE NOT NULL, pw_hash TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS courses (
            code TEXT PRIMARY KEY, name TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS registrations (
            id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL,
            course_code TEXT NOT NULL, note TEXT NOT NULL DEFAULT '');
        """
    )
    for username, password in USERS:
        db.execute(
            "INSERT OR IGNORE INTO users (username, pw_hash) VALUES (?, ?)",
            (username, generate_password_hash(password)),
        )
    db.executemany("INSERT OR IGNORE INTO courses (code, name) VALUES (?, ?)", COURSES)
    db.commit()


def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("login"))
        return view(*args, **kwargs)
    return wrapped


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        row = get_db().execute(
            "SELECT id, pw_hash FROM users WHERE username = ?",
            (request.form.get("username", ""),),
        ).fetchone()
        if row and check_password_hash(row["pw_hash"], request.form.get("password", "")):
            session.clear()
            session["user_id"] = row["id"]
            session["username"] = request.form["username"]
            return redirect(url_for("index"))
        error = "Sai tên đăng nhập hoặc mật khẩu."
    return render_template("login.html", error=error)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/")
@login_required
def index():
    rows = get_db().execute(
        "SELECT r.id, r.course_code, c.name FROM registrations r "
        "JOIN courses c ON c.code = r.course_code WHERE r.user_id = ? ORDER BY r.id",
        (session["user_id"],),
    ).fetchall()
    return render_template("index.html", rows=rows)


@app.route("/timkiem")
@login_required
def search():
    q = request.args.get("q", "")
    # Truy vấn tham số hóa: dữ liệu người dùng đi riêng, không ghép vào câu lệnh.
    rows = get_db().execute(
        "SELECT code, name FROM courses WHERE name LIKE ? ORDER BY code",
        ("%" + q + "%",),
    ).fetchall()
    return render_template("search.html", q=q, rows=rows)


@app.route("/dangky", methods=["POST"])
@login_required
def register():
    code = request.form.get("course_code", "")
    note = request.form.get("note", "")[:500]
    db = get_db()
    if db.execute("SELECT 1 FROM courses WHERE code = ?", (code,)).fetchone() is None:
        abort(400)
    cur = db.execute(
        "INSERT INTO registrations (user_id, course_code, note) VALUES (?, ?, ?)",
        (session["user_id"], code, note),
    )
    db.commit()
    return redirect(url_for("view_registration", reg_id=cur.lastrowid))


@app.route("/phieu/<int:reg_id>")
@login_required
def view_registration(reg_id):
    # Kiểm tra quyền sở hữu ở máy chủ: chỉ trả về phiếu của chính người đăng nhập.
    row = get_db().execute(
        "SELECT r.id, r.user_id, r.course_code, r.note, c.name FROM registrations r "
        "JOIN courses c ON c.code = r.course_code WHERE r.id = ? AND r.user_id = ?",
        (reg_id, session["user_id"]),
    ).fetchone()
    if row is None:
        abort(404)
    return render_template("phieu.html", row=row)


@app.errorhandler(500)
def server_error(exc):
    return render_template("error.html"), 500


with app.app_context():
    os.makedirs(os.path.dirname(app.config["DATABASE"]), exist_ok=True)
    init_db()
