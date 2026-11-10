#!/bin/bash
# Tao khoa (neu chua co) va chay nen Core :8101, Peer :8102, proxy gia mao :8103 (Core -> proxy -> Peer).
# Nhat ky o ~/ketnoi-lab/*.log. Dung: bash chay-nen.sh ; dung lai: bash chay-nen.sh tat
umask 077   # CSDL, nhat ky, cau hinh chi chu so huu doc duoc
D="$(cd "$(dirname "$0")" && pwd)"
L="${KETNOI_DIR:-$HOME/ketnoi-lab}"
if [ "$1" = "tat" ]; then
  pkill -f "$D/nut.py" ; pkill -f "$D/gia-mao.py" ; echo "Da dung Core, Peer, proxy"; exit 0
fi
[ -f "$L/core.json" ] || python3 "$D/tao-khoa.py" "$L" --core-goi http://127.0.0.1:8103
echo trong-suot > "$L/che-do-gia-mao"
nohup python3 "$D/nut.py" "$L/core.json" chay > "$L/core.log" 2>&1 &
nohup python3 "$D/nut.py" "$L/peer.json" chay > "$L/peer.log" 2>&1 &
nohup python3 "$D/gia-mao.py" 8103 http://127.0.0.1:8102 "$L/che-do-gia-mao" > "$L/gia-mao.log" 2>&1 &
sleep 1
ss -ltn | grep -E ':(8101|8102|8103) ' | awk '{print "Dang nghe", $4}'
