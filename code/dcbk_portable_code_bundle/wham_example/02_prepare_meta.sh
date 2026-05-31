#!/usr/bin/env bash
set -euo pipefail

: "${DCBK_WHAM_META_START:=25.0}"
: "${DCBK_WHAM_META_END:=1.0}"
: "${DCBK_WHAM_META_STEP:=-3.0}"
: "${DCBK_WHAM_FORCE_CONSTANT:=10.0}"

: > metadata.dat
for distance in $(seq "${DCBK_WHAM_META_START}" "${DCBK_WHAM_META_STEP}" "${DCBK_WHAM_META_END}"); do
    echo "./dist_${distance}/prod_dist.dat ${distance} ${DCBK_WHAM_FORCE_CONSTANT}" >> metadata.dat
done
