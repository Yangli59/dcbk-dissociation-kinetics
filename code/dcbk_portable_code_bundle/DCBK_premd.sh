#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/dcbk_common.sh"

usage() {
    cat <<EOF
Usage:
  $(basename "$0") --protein target_protein.pdb --ligand target.mol2 [options]

Purpose:
  Prepare a portable DCBK fragment bundle from one bound ligand pose.
  The script can generate fragments from the input ligand or reuse an
  existing fragment SDF, then align all molecules to the reference pose
  and write:

    <prefix>_protein.pdb
    <prefix>_fragments.sdf
    <prefix>_fixed.sdf

Options:
  --protein PATH       Protein PDB file.
  --ligand PATH        Reference ligand pose (.mol2/.sdf/.mol/.pdb).
  --fragments PATH     Existing fragment ensemble in SDF format.
  --prefix NAME        Output prefix. Default: ligand basename.
  --output-dir PATH    Output directory. Default: current directory.
  --help               Show this message.

Environment:
  DCBK_PYTHON          Python executable. Default: python3
  DCBK_CONDA_SH        Optional conda.sh path to source.
  DCBK_CONDA_ENV       Optional conda env to activate.
EOF
}

protein=""
ligand=""
fragments=""
prefix=""
output_dir="$(pwd)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --protein)
            protein="${2:-}"
            shift 2
            ;;
        --ligand)
            ligand="${2:-}"
            shift 2
            ;;
        --fragments)
            fragments="${2:-}"
            shift 2
            ;;
        --prefix)
            prefix="${2:-}"
            shift 2
            ;;
        --output-dir)
            output_dir="${2:-}"
            shift 2
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
[[ -n "${ligand}" ]] || { usage; dcbk_die "--ligand is required."; }

python_bin="$(dcbk_python)"
dcbk_activate_optional_env
trap dcbk_cleanup_optional_env EXIT

dcbk_require_cmd "${python_bin}"
dcbk_check_python_module "${python_bin}" rdkit
dcbk_require_file "${protein}"
dcbk_require_file "${ligand}"
[[ -z "${fragments}" ]] || dcbk_require_file "${fragments}"

protein_abs="$(dcbk_abs_path "${protein}")"
ligand_abs="$(dcbk_abs_path "${ligand}")"
output_dir="$(dcbk_abs_path "${output_dir}")"
mkdir -p "${output_dir}"

ligand_base="$(basename "${ligand_abs}")"
ligand_stem="${ligand_base%.*}"
prefix="${prefix:-${ligand_stem}}"

protein_out="${output_dir}/${prefix}_protein.pdb"
fragments_out="${output_dir}/${prefix}_fragments.sdf"
fixed_out="${output_dir}/${prefix}_fixed.sdf"

dcbk_log "Preparing fragment bundle for prefix '${prefix}'."
cp -f "${protein_abs}" "${protein_out}"

if [[ -n "${fragments}" ]]; then
    fragments_abs="$(dcbk_abs_path "${fragments}")"
    if [[ "${fragments_abs}" != "${fragments_out}" ]]; then
        cp -f "${fragments_abs}" "${fragments_out}"
    fi
else
    dcbk_log "No fragment SDF provided; generating fragments with fragmentation.py."
    (
        cd "${output_dir}"
        "${python_bin}" "${SCRIPT_DIR}/fragmentation.py" "${ligand_abs}"
    )

    generated_sdf="${output_dir}/${ligand_stem}_fragments.sdf"
    dcbk_require_file "${generated_sdf}"
    if [[ "${generated_sdf}" != "${fragments_out}" ]]; then
        cp -f "${generated_sdf}" "${fragments_out}"
    fi

    if [[ -f "${output_dir}/${ligand_stem}_fragments.smi" ]]; then
        if [[ "${output_dir}/${ligand_stem}_fragments.smi" != "${output_dir}/${prefix}_fragments.smi" ]]; then
            cp -f "${output_dir}/${ligand_stem}_fragments.smi" "${output_dir}/${prefix}_fragments.smi"
        fi
    fi
    if [[ -f "${output_dir}/${ligand_stem}_fragments.mol2" ]]; then
        if [[ "${output_dir}/${ligand_stem}_fragments.mol2" != "${output_dir}/${prefix}_fragments.mol2" ]]; then
            cp -f "${output_dir}/${ligand_stem}_fragments.mol2" "${output_dir}/${prefix}_fragments.mol2"
        fi
    fi
fi

dcbk_log "Aligning fragments to the reference ligand pose."
"${python_bin}" "${SCRIPT_DIR}/align_fragments.py" \
    --reference "${ligand_abs}" \
    --fragments "${fragments_out}" \
    --output "${fixed_out}"

dcbk_log "Preparation completed."
printf '%s\n' \
    "Protein:   ${protein_out}" \
    "Fragments: ${fragments_out}" \
    "Aligned:   ${fixed_out}" \
    "Next step: ${SCRIPT_DIR}/DCBK_md.sh --protein ${protein_out} --ligands ${fixed_out}"
