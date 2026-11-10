#!/bin/bash
# Goi nut Peer voi cau hinh trong ~/ketnoi-lab. Vd: bash peer.sh keo
exec python3 "$(dirname "$0")/nut.py" "${KETNOI_DIR:-$HOME/ketnoi-lab}/peer.json" "$@"
