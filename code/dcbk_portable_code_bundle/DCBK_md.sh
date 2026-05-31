#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/dcbk_common.sh"

usage() {
    cat <<EOF
Usage:
  $(basename "$0") --protein target_protein.pdb --ligands target_fixed.sdf [options]

Purpose:
  Prepare Amber systems for the DCBK whole-ligand/fragment ensemble and
  launch the MD workflow that builds:

    complex_md/lig1
    complex_md/lig2
    ...

Options:
  --protein PATH        Protein PDB file.
  --ligands PATH        Multi-molecule ligand SDF/MOL2 file.
  --time NS             Production MD time in ns. Default: 5
  --workdir PATH        Work directory for complex_md. Default: current directory.
  --num N               Override ligand count.
  --gpuid ID            GPU id exported to CUDA_VISIBLE_DEVICES. Default: 0
  --resid MASK          Amber restraint mask forwarded to FlexSim.py
  --ssbond SPEC         Disulfide definition forwarded to FlexSim.py
  --prepare-only        Generate inputs but skip the actual MD execution.
  --help                Show this message.

Environment:
  AMBERHOME             Amber installation root.
  DCBK_MD_ENGINE        Amber executable. Default: pmemd.cuda
  DCBK_PYTHON           Python executable. Default: python3
  DCBK_AMBER_SH         Optional amber.sh path to source.
  DCBK_CONDA_SH         Optional conda.sh path to source.
  DCBK_CONDA_ENV        Optional conda env to activate.
EOF
}

protein=""
ligands=""
time_ns="5"
workdir="$(pwd)"
num=""
gpuid="0"
resid=""
ssbond=""
prepare_only=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --protein)
            protein="${2:-}"
            shift 2
            ;;
        --ligands)
            ligands="${2:-}"
            shift 2
            ;;
        --time)
            time_ns="${2:-}"
            shift 2
            ;;
        --workdir)
            workdir="${2:-}"
            shift 2
            ;;
        --num)
            num="${2:-}"
            shift 2
            ;;
        --gpuid)
            gpuid="${2:-}"
            shift 2
            ;;
        --resid)
            resid="${2:-}"
            shift 2
            ;;
        --ssbond)
            ssbond="${2:-}"
            shift 2
            ;;
        --prepare-only)
            prepare_only=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage
            dcbk_die "Unknown option: $1"
            ;;
    esac
done

[[ -n "${protein}" ]] || { usage; dcbk_die "--protein is required."; }
[[ -n "${ligands}" ]] || { usage; dcbk_die "--ligands is required."; }

python_bin="$(dcbk_python)"
dcbk_activate_optional_env
trap dcbk_cleanup_optional_env EXIT

dcbk_require_cmd "${python_bin}"
dcbk_require_file "${protein}"
dcbk_require_file "${ligands}"
dcbk_require_cmd obabel
dcbk_require_cmd antechamber
dcbk_require_cmd parmchk2
dcbk_require_cmd tleap
dcbk_require_cmd pdb4amber

md_engine="${DCBK_MD_ENGINE:-pmemd.cuda}"
if [[ "${prepare_only}" -eq 0 ]]; then
    dcbk_require_cmd "${md_engine}"
fi

protein_abs="$(dcbk_abs_path "${protein}")"
ligands_abs="$(dcbk_abs_path "${ligands}")"
workdir="$(dcbk_abs_path "${workdir}")"
mkdir -p "${workdir}"

dcbk_log "Starting DCBK MD setup in ${workdir}."
cmd=(
    "${python_bin}" "${SCRIPT_DIR}/FlexSim.py"
    -pro "${protein_abs}"
    -lig "${ligands_abs}"
    -time "${time_ns}"
    -gpuid "${gpuid}"
    -d "${workdir}"
    --md-engine "${md_engine}"
)

if [[ -n "${num}" ]]; then
    cmd+=(-num "${num}")
fi
if [[ -n "${resid}" ]]; then
    cmd+=(-resid "${resid}")
fi
if [[ -n "${ssbond}" ]]; then
    cmd+=(-ssbond "${ssbond}")
fi
if [[ "${prepare_only}" -eq 1 ]]; then
    cmd+=(--prepare-only)
fi

"${cmd[@]}"

dcbk_log "DCBK MD workflow completed."
printf '%s\n' \
    "Workdir:    ${workdir}" \
    "Complex MD: ${workdir}/complex_md"
