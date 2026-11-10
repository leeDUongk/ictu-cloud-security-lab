#!/bin/bash
# Goi nut Core voi cau hinh trong ~/ketnoi-lab. Vd: bash core.sh gui
exec python3 "$(dirname "$0")/nut.py" "${KETNOI_DIR:-$HOME/ketnoi-lab}/core.json" "$@"
