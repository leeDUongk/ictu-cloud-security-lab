#!/usr/bin/env bash
# Bài 9 — ghi mốc thời gian của một sự cố và tính chỉ số thời gian.
#   bash moc.sh <kịch bản> <mốc> "ghi chú"   ghi một mốc (kịch bản 1 hoặc 2; mốc t0..t4)
#   bash moc.sh                              in các mốc đã ghi và chỉ số của từng kịch bản
# Mốc: t0 xâm nhập (bắt đầu tạo điều kiện), t1 phát hiện, t2 ngăn chặn xong,
#      t3 diệt trừ xong, t4 phục hồi xong (kiểm thử lại đạt).
set -euo pipefail
F=~/lab9/moc.txt
mkdir -p ~/lab9

if [[ $# -ge 2 ]]; then
  [[ "$1" =~ ^[12]$ ]] || { echo "Kịch bản phải là 1 hoặc 2" >&2; exit 1; }
  [[ "$2" =~ ^t[0-4]$ ]] || { echo "Mốc phải là t0, t1, t2, t3 hoặc t4" >&2; exit 1; }
  now=$(date +%s)
  printf '%s|%s|%s|%s\n' "$now" "$1" "$2" "${3:-}" >> "$F"
  printf 'Kịch bản %s, %s = %s UTC  %s\n' "$1" "$2" "$(date -u -d "@$now" '+%F %T')" "${3:-}"
  exit 0
fi

[[ -s "$F" ]] || { echo "Chưa ghi mốc nào ($F)."; exit 0; }
fmt() { local s=$1; printf '%d phút %02d giây' $((s/60)) $((s%60)); }
for kb in 1 2; do
  grep -q "^[0-9]*|$kb|" "$F" || continue
  echo "== Kịch bản $kb =="
  declare -A T=()
  while IFS='|' read -r ts k m note; do
    [[ "$k" == "$kb" ]] || continue
    T[$m]=$ts
    printf '  %s  %s UTC  %s\n' "$m" "$(date -u -d "@$ts" '+%T')" "$note"
  done < "$F"
  [[ -n "${T[t0]:-}" && -n "${T[t1]:-}" ]] && echo "  Thời gian phát hiện (t1-t0): $(fmt $((T[t1]-T[t0])))"
  [[ -n "${T[t1]:-}" && -n "${T[t2]:-}" ]] && echo "  Thời gian ngăn chặn (t2-t1): $(fmt $((T[t2]-T[t1])))"
  [[ -n "${T[t1]:-}" && -n "${T[t4]:-}" ]] && echo "  Thời gian phục hồi (t4-t1): $(fmt $((T[t4]-T[t1])))"
  unset T
done
