#!/usr/bin/env bash
set -euo pipefail

: "${DCBK_MD_ENGINE:=pmemd.cuda}"

"${DCBK_MD_ENGINE}" -O -i asmd.in -o asmd.out -p comp_sol.prmtop -c SuMD_0.rst -r asmd.rst -x asmd.nc -ref SuMD_0.rst
