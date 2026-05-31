#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/dcbk_common.sh"

usage() {
    cat <<EOF
Usage:
  $(basename "$0") [options]

Purpose:
  Run the DCBK SMD stage for one or more ligands and one or more replicas.
  The script can auto-generate cv.dat from complex_md/lig*/comp_raw2.pdb and
  then launch SMD folders such as:

    complex_md/lig1/exit_smd_rep1
    complex_md/lig2/exit_smd_rep1

Options:
  --complex-dir PATH       complex_md directory. Default: ./complex_md
  --cv-file PATH           CV file. Default: <complex-dir parent>/cv.dat
  --ligands CSV            Ligand indices, e.g. 1,2,3,4. Default: auto-detect
  --replicas CSV           Replica ids, e.g. 1,2,3. Default: 1
  --suffix-pattern TEXT    Directory pattern. Use {rep}. Default: exit_smd_rep{rep}
  --rk2 VALUE              rk2 value written to dist.example.RST. Default: 5.0
  --no-generate-cv         Reuse existing cv.dat instead of rebuilding it
  --help                   Show this message.

Environment:
  DCBK_PYTHON              Python executable. Default: python3
  DCBK_MD_ENGINE           Amber executable. Default: pmemd.cuda
  DCBK_AMBER_SH            Optional amber.sh path to source.
  DCBK_CONDA_SH            Optional conda.sh path to source.
  DCBK_CONDA_ENV           Optional conda env to activate.
EOF
}

complex_dir="./complex_md"
cv_file=""
ligands_csv=""
replicas_csv="1"
suffix_pattern="exit_smd_rep{rep}"
rk2="5.0"
generate_cv=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --complex-dir)
            complex_dir="${2:-}"
            shift 2
            ;;
        --cv-file)
            cv_file="${2:-}"
            shift 2
            ;;
        --ligands)
            ligands_csv="${2:-}"
            shift 2
            ;;
        --replicas)
            replicas_csv="${2:-}"
            shift 2
            ;;
        --suffix-pattern)
            suffix_pattern="${2:-}"
            shift 2
            ;;
        --rk2)
            rk2="${2:-}"
            shift 2
            ;;
        --no-generate-cv)
            generate_cv=0
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

python_bin="$(dcbk_python)"
dcbk_activate_optional_env
trap dcbk_cleanup_optional_env EXIT

dcbk_require_cmd "${python_bin}"
dcbk_check_python_module "${python_bin}" mdtraj
dcbk_require_cmd cpptraj
export DCBK_MD_ENGINE="${DCBK_MD_ENGINE:-pmemd.cuda}"
dcbk_require_cmd "${DCBK_MD_ENGINE}"

complex_dir="$(dcbk_abs_path "${complex_dir}")"
dcbk_require_dir "${complex_dir}"

if [[ -z "${cv_file}" ]]; then
    cv_file="$(dirname "${complex_dir}")/cv.dat"
fi
cv_file="$(dcbk_abs_path "${cv_file}")"

declare -a ligand_dirs=()
if [[ -n "${ligands_csv}" ]]; then
    IFS=',' read -r -a ligand_ids <<< "${ligands_csv}"
    for lig_id in "${ligand_ids[@]}"; do
        lig_id="${lig_id//[[:space:]]/}"
        [[ -n "${lig_id}" ]] || continue
        ligand_dirs+=("${complex_dir}/lig${lig_id}")
    done
else
    while IFS= read -r lig_dir; do
        ligand_dirs+=("${lig_dir}")
    done < <(dcbk_discover_ligand_dirs "${complex_dir}")
fi
[[ ${#ligand_dirs[@]} -gt 0 ]] || dcbk_die "No ligand directories were found under ${complex_dir}."

for lig_dir in "${ligand_dirs[@]}"; do
    dcbk_require_dir "${lig_dir}"
    dcbk_require_file "${lig_dir}/comp_sol.prmtop"
    dcbk_require_file "${lig_dir}/comp_sol.inpcrd"
    dcbk_require_file "${lig_dir}/equil3.rst"
done

if [[ "${generate_cv}" -eq 1 ]]; then
    dcbk_log "Generating ${cv_file} from comp_raw2.pdb files."
    : > "${cv_file}"
    for lig_dir in "${ligand_dirs[@]}"; do
        dcbk_require_file "${lig_dir}/comp_raw2.pdb"
        "${python_bin}" "${SCRIPT_DIR}/find_closest_atoms.py" "${lig_dir}/comp_raw2.pdb" >> "${cv_file}"
    done
fi

dcbk_require_file "${cv_file}"
expected_lines=$(( ${#ligand_dirs[@]} * 2 ))
actual_lines="$(wc -l < "${cv_file}")"
[[ "${actual_lines}" -ge "${expected_lines}" ]] || \
    dcbk_die "${cv_file} contains ${actual_lines} lines, but at least ${expected_lines} are required."

IFS=',' read -r -a replica_ids <<< "${replicas_csv}"
[[ ${#replica_ids[@]} -gt 0 ]] || dcbk_die "At least one replica id is required."

for rep in "${replica_ids[@]}"; do
    rep="${rep//[[:space:]]/}"
    [[ -n "${rep}" ]] || continue
    smd_suffix="${suffix_pattern//\{rep\}/${rep}}"
    dcbk_log "Running SMD replica '${rep}' into suffix '${smd_suffix}'."

    for idx in "${!ligand_dirs[@]}"; do
        lig_dir="${ligand_dirs[$idx]}"
        smd_dir="${lig_dir}/${smd_suffix}"
        mkdir -p "${smd_dir}"

        dcbk_stage_file "${lig_dir}/comp_sol.prmtop" "${smd_dir}/comp_sol.prmtop"
        dcbk_stage_file "${lig_dir}/comp_sol.inpcrd" "${smd_dir}/comp_sol.inpcrd"
        dcbk_stage_file "${lig_dir}/equil3.rst" "${smd_dir}/equil3.rst"
        dcbk_stage_file "${SCRIPT_DIR}/smd_example/asmd.in" "${smd_dir}/asmd.in"
        dcbk_stage_file "${SCRIPT_DIR}/smd_example/dist.example.RST" "${smd_dir}/dist.example.RST"
        dcbk_stage_file "${SCRIPT_DIR}/smd_example/mdrun.sh" "${smd_dir}/mdrun.sh" 755

        igr1="$(sed -n "$((idx * 2 + 1))p" "${cv_file}")"
        igr2="$(sed -n "$((idx * 2 + 2))p" "${cv_file}")"
        [[ -n "${igr1}" && -n "${igr2}" ]] || dcbk_die "Missing CV entries for $(basename "${lig_dir}") in ${cv_file}."

        (
            cd "${smd_dir}"
            cp -f equil3.rst SuMD_0.rst
            cpptraj <<'EOF'
parm comp_sol.prmtop
trajin equil3.rst
strip :WAT,Na+,Cl-
trajout equil3.pdb
go
EOF

            sed -i.bak "s/^\(\s*igr1=\).*/\1${igr1}/" dist.example.RST
            sed -i "s/^\(\s*igr2=\).*/\1${igr2}/" dist.example.RST
            sed -i "s/^\(\s*rk2=\).*/\1${rk2},/" dist.example.RST
            ./mdrun.sh
        )
    done
done

dcbk_log "DCBK SMD workflow completed."
printf '%s\n' \
    "Complex MD: ${complex_dir}" \
    "CV file:    ${cv_file}"
