#!/usr/bin/env python3
"""Bài 9 — ghép các nguồn nhật ký thành một dòng thời gian, quy mọi thời điểm về UTC.

Chạy trên ONE-Lab (cần sudo để đọc nhật ký OpenNebula):
    python3 dong-thoi-gian.py              # từ 5 giây trước mốc t0 đầu tiên (moc.sh) đến hiện tại
    python3 dong-thoi-gian.py --kb 2       # từ 5 giây trước mốc t0 của kịch bản 2
    python3 dong-thoi-gian.py 90           # 90 phút gần nhất

Nguồn và cách quy giờ:
  moc.txt    mốc do sinh viên ghi bằng moc.sh (giây Unix, vốn là UTC)
  oned.log   giờ địa phương của ONE-Lab, KHÔNG ghi múi giờ -> đổi theo múi giờ của máy
  auth.log   ISO 8601 có múi giờ (+07:00)
  noibo.log  nhật ký dịch vụ 8080 trong web-paas, giờ của máy ảo (UTC), không ghi múi giờ
Chỉ đọc, không sửa gì.
"""
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

NOW = datetime.now(timezone.utc)
MOC = os.path.expanduser("~/lab9/moc.txt")
KB = None
if len(sys.argv) > 2 and sys.argv[1] == "--kb":
    KB = sys.argv[2]


def moc_cua(ten):
    """Thời điểm các mốc tên `ten` (t0, t4...) của kịch bản KB (hoặc mọi kịch bản)."""
    if not os.path.exists(MOC):
        return []
    kq = []
    for ln in open(MOC, encoding="utf-8"):
        p = ln.split("|")
        if len(p) >= 3 and p[2] == ten and KB in (None, p[1]):
            kq.append(datetime.fromtimestamp(int(p[0]), timezone.utc))
    return kq


DEN = NOW
if len(sys.argv) > 1 and KB is None:
    TU = NOW - timedelta(minutes=int(sys.argv[1]))
else:
    t0 = moc_cua("t0")
    TU = (min(t0) - timedelta(seconds=5)) if t0 else NOW - timedelta(minutes=60)
    if KB is not None and moc_cua("t4"):
        DEN = max(moc_cua("t4")) + timedelta(seconds=5)
LOCAL = datetime.now().astimezone().tzinfo
SSH = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=4", "root@172.16.100.205"]

# Các lời gọi API đáng quan tâm; bỏ qua các lời gọi đọc thông tin định kỳ.
API = re.compile(r"one\.(acl\.(addrule|delrule)|vm\.(action|attachnic|detachnic|disksaveas|allocate)|"
                 r"secgroup\.update|template\.instantiate|user\.(allocate|enable|passwd|delete)|vn\.allocate)")


def doc(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=20).stdout.splitlines()
    except Exception:
        return []


su_kien = []


def them(t, nguon, noi_dung):
    if TU <= t <= DEN:
        su_kien.append((t, nguon, noi_dung))


# 1. Mốc của sinh viên
if os.path.exists(MOC):
    for ln in open(MOC, encoding="utf-8"):
        p = ln.rstrip("\n").split("|", 3)
        if len(p) == 4 and KB in (None, p[1]):
            them(datetime.fromtimestamp(int(p[0]), timezone.utc), "MOC", f"Kịch bản {p[1]}, {p[2]}: {p[3]}")

# 2. oned.log: chỉ dòng "invoked" của API quan tâm và dòng kết quả thất bại
cho = {}
for ln in doc(["sudo", "cat", "/var/log/one/oned.log"]):
    m = re.match(r"(\w{3} \w{3} +\d+ \d\d:\d\d:\d\d \d{4}) \[Z0\]\[ReM\]\[\w\]: Req:(\d+) UID:(\S+) (.*)", ln)
    if not m:
        continue
    t = datetime.strptime(m.group(1), "%a %b %d %H:%M:%S %Y").replace(tzinfo=LOCAL).astimezone(timezone.utc)
    req, uid, rest = m.group(2), m.group(3), m.group(4)
    if "invoked" in rest and API.search(rest):
        cho[req] = True
        rest = re.sub(r"^IP:\S+ ", "", rest).replace(" invoked ,", "")
        them(t, "oned.log", f"UID:{uid} {rest}"[:95])
    elif "result FAILURE" in rest and req in cho:
        them(t, "oned.log", f"UID:{uid} {rest.split('result ', 1)[1]}"[:95])

# Lệnh làm thay đổi trạng thái (bỏ qua list, show).
THAY_DOI = re.compile(r"/usr/bin/one\w+ (create|delete|update|poweroff|resume|suspend|terminate|"
                      r"disable|enable|nic-\w+|chmod|chown|passwd|instantiate)")

# 3. auth.log: lệnh OpenNebula chạy qua sudo, đăng nhập SSH
for ln in doc(["sudo", "cat", "/var/log/auth.log"]):
    m = re.match(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)\.\d+([+-]\d\d:\d\d) \S+ (.*)", ln)
    if not m:
        continue
    t = datetime.fromisoformat(m.group(1) + m.group(2)).astimezone(timezone.utc)
    rest = m.group(3)
    c = re.search(r"sudo:\s+(\S+) : PWD=\S+ ; USER=oneadmin ; COMMAND=(/usr/bin/one.*)", rest)
    if c and THAY_DOI.search(c.group(2)):
        them(t, "auth.log", f"{c.group(1)} (sudo oneadmin): {c.group(2).replace('/usr/bin/', '')}"[:95])
    elif re.search(r"sshd\[\d+\]: (Failed password|Accepted password) ", rest):
        them(t, "auth.log", re.sub(r"sshd\[\d+\]: ", "", rest)[:95])

# 4. Nhật ký dịch vụ 8080 trong web-paas (máy ảo chạy giờ UTC)
for ln in doc(SSH + ["cat /var/log/noibo.log 2>/dev/null"]):
    m = re.match(r"(\S+) - - \[(\d\d/\w{3}/\d{4} \d\d:\d\d:\d\d)\] \"(\S+ \S+)[^\"]*\" (\d+)", ln)
    if m:
        t = datetime.strptime(m.group(2), "%d/%b/%Y %H:%M:%S").replace(tzinfo=timezone.utc)
        them(t, "noibo.log", f"{m.group(1)} {m.group(3)} -> {m.group(4)}")

print(f"Dòng thời gian từ {TU:%H:%M:%S} đến {DEN:%H:%M:%S} UTC ({len(su_kien)} sự kiện)")
print(f"{'Giờ UTC':8}  {'Nguồn':9}  Sự kiện")
for t, nguon, nd in sorted(su_kien, key=lambda x: x[0]):
    print(f"{t:%H:%M:%S}  {nguon:9}  {nd}")
