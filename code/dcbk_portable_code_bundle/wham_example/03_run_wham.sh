#!/usr/bin/env bash
set -euo pipefail

: "${DCBK_WHAM_MIN:=0}"
: "${DCBK_WHAM_MAX:=25}"
: "${DCBK_WHAM_BINS:=260}"
: "${DCBK_WHAM_TOL:=0.00000001}"
: "${DCBK_WHAM_TEMP:=300}"
: "${DCBK_WHAM_PAD:=0}"

wham "${DCBK_WHAM_MIN}" "${DCBK_WHAM_MAX}" "${DCBK_WHAM_BINS}" "${DCBK_WHAM_TOL}" "${DCBK_WHAM_TEMP}" "${DCBK_WHAM_PAD}" metadata.dat out.pmf
sed '1d' out.pmf | awk '{print $1,"",$2}' > plot.dat
