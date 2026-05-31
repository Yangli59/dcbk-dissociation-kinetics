#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/dcbk_common.sh"

: "${DCBK_PYTHON:=python3}"

output_file="${1:-cv.dat}"
complex_dir="${2:-complex_md}"

dcbk_require_cmd "${DCBK_PYTHON}"
dcbk_check_python_module "${DCBK_PYTHON}" mdtraj
dcbk_require_dir "${complex_dir}"

: > "${output_file}"
while IFS= read -r lig_dir; do
    pdb_file="${lig_dir}/comp_raw2.pdb"
    if [[ -f "${pdb_file}" ]]; then
        "${DCBK_PYTHON}" "${SCRIPT_DIR}/find_closest_atoms.py" "${pdb_file}" >> "${output_file}"
    else
        dcbk_log "Warning: ${pdb_file} not found. Skipping."
    fi
done < <(dcbk_discover_ligand_dirs "${complex_dir}")

dcbk_log "cv.dat generated at $(dcbk_abs_path "${output_file}")"
