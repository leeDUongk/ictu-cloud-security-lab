#!/usr/bin/env bash
# Bài 9 — tóm tắt một tệp bắt gói tin (.pcap) bằng tcpdump, không cần Wireshark.
#   bash phan-tich-pcap.sh <tệp.pcap>
# In ra: (1) các gói mở kết nối (SYN) theo nguồn và cổng đích -> nhận ra dò cổng;
#        (2) các luồng TCP xếp theo số byte dữ liệu -> nhận ra luồng chuyển dữ liệu lớn.
# Giờ in theo UTC.
set -u
F="${1:?Dùng: bash phan-tich-pcap.sh <tệp.pcap>}"
[[ -r "$F" ]] || { echo "Không đọc được $F" >&2; exit 1; }
export TZ=UTC

echo "== Tổng quan =="
n=$(tcpdump -nn -r "$F" 2>/dev/null | wc -l)
dau=$(tcpdump -nn -tttt -r "$F" 2>/dev/null | head -1 | cut -c12-19)
cuoi=$(tcpdump -nn -tttt -r "$F" 2>/dev/null | tail -1 | cut -c12-19)
echo "$n gói, từ $dau đến $cuoi UTC"

echo
echo "== Gói SYN (mở kết nối) theo nguồn -> đích:cổng, kèm số lần và có được trả lời không =="
tcpdump -nn -r "$F" 'tcp[tcpflags] & tcp-syn != 0' 2>/dev/null | awk '
  { split($3,s,"."); split($5,d,"."); sub(":","",d[5]);
    src=s[1]"."s[2]"."s[3]"."s[4]; dst=d[1]"."d[2]"."d[3]"."d[4]; port=d[5];
    if ($0 ~ /Flags \[S\.\]/) { tra[dst" -> "src":"s[5]]++ }
    else { k=src" -> "dst":"port; syn[k]++ } }
  END { for (k in syn) printf "  %-34s SYN x%-3d %s\n", k, syn[k], (k in tra ? "co tra loi SYN-ACK" : "KHONG tra loi / RST") }' | sort

echo
echo "== Luồng TCP xếp theo số byte dữ liệu (5 luồng lớn nhất) =="
tcpdump -nn -q -r "$F" tcp 2>/dev/null | awk '
  { len=$NF; if (len+0==0) next; k=$3" > "$5; sub(":$","",k); b[k]+=len; p[k]++ }
  END { for (k in b) printf "%10d byte  %5d goi  %s\n", b[k], p[k], k }' | sort -rn | head -5
