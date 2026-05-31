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
  Run the DCBK umbrella-sampling and WHAM stages on one or more SMD outputs.

Options:
  --complex-dir PATH         complex_md directory. Default: ./complex_md
  --ligands CSV              Ligand indices, e.g. 1,2,3,4. Default: auto-detect
  --replicas CSV             Replica ids, e.g. 1,2,3. Default: 1
  --suffix-pattern TEXT      SMD directory pattern. Use {rep}. Default: exit_smd_rep{rep}
  --extract-start FLOAT      Start distance for frame extraction. Default: 0
  --extract-end FLOAT        End distance for frame extraction. Default: 30
  --extract-step FLOAT       Distance spacing for frame extraction. Default: 0.5
  --tolerances CSV           Extraction tolerances. Default: 0.2,0.1,0.05,0.01
  --window-start FLOAT       First US window distance. Default: 25.0
  --window-end FLOAT         Last US window distance. Default: 1.0
  --window-step FLOAT        US window increment. Default: -1.0
  --meta-step FLOAT          Window spacing used in metadata.dat. Default: -3.0
  --wham-min FLOAT           WHAM lower bound. Default: 0
  --wham-max FLOAT           WHAM upper bound. Default: 25
  --wham-bins INT            WHAM bin count. Default: 260
  --wham-temp FLOAT          WHAM temperature in K. Default: 300
  --wham-force FLOAT         Force constant written to metadata.dat. Default: 10.0
  --help                     Show this message.

Environment:
  DCBK_PYTHON                Python executable. Default: python3
  DCBK_MD_ENGINE             Amber executable. Default: pmemd.cuda
  DCBK_AMBER_SH              Optional amber.sh path to source.
  DCBK_CONDA_SH              Optional conda.sh path to source.
  DCBK_CONDA_ENV             Optional conda env to activate.
EOF
}

complex_dir="./complex_md"
ligands_csv=""
replicas_csv="1"
suffix_pattern="exit_smd_rep{rep}"
extract_start="0"
extract_end="30"
extract_step="0.5"
tolerances_csv="0.2,0.1,0.05,0.01"
window_start="25.0"
window_end="1.0"
window_step="-1.0"
meta_step="-3.0"
wham_min="0"
wham_max="25"
wham_bins="260"
wham_temp="300"
wham_force="10.0"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --complex-dir)
            complex_dir="${2:-}"
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
        --extract-start)
            extract_start="${2:-}"
            shift 2
            ;;
        --extract-end)
            extract_end="${2:-}"
            shift 2
            ;;
        --extract-step)
            extract_step="${2:-}"
            shift 2
            ;;
        --tolerances)
            tolerances_csv="${2:-}"
            shift 2
            ;;
        --window-start)
            window_start="${2:-}"
            shift 2
            ;;
        --window-end)
            window_end="${2:-}"
            shift 2
            ;;
        --window-step)
            window_step="${2:-}"
            shift 2
            ;;
        --meta-step)
            meta_step="${2:-}"
            shift 2
            ;;
        --wham-min)
            wham_min="${2:-}"
            shift 2
            ;;
        --wham-max)
            wham_max="${2:-}"
            shift 2
            ;;
        --wham-bins)
            wham_bins="${2:-}"
            shift 2
            ;;
        --wham-temp)
            wham_temp="${2:-}"
            shift 2
            ;;
        --wham-force)
            wham_force="${2:-}"
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

python_bin="$(dcbk_python)"
dcbk_activate_optional_env
trap dcbk_cleanup_optional_env EXIT

dcbk_require_cmd "${python_bin}"
dcbk_check_python_module "${python_bin}" numpy
dcbk_require_cmd cpptraj
dcbk_require_cmd wham
export DCBK_MD_ENGINE="${DCBK_MD_ENGINE:-pmemd.cuda}"
dcbk_require_cmd "${DCBK_MD_ENGINE}"

complex_dir="$(dcbk_abs_path "${complex_dir}")"
dcbk_require_dir "${complex_dir}"

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

IFS=',' read -r -a replica_ids <<< "${replicas_csv}"
[[ ${#replica_ids[@]} -gt 0 ]] || dcbk_die "At least one replica id is required."

export DCBK_PYTHON="${python_bin}"
export DCBK_US_EXTRACT_START="${extract_start}"
export DCBK_US_EXTRACT_END="${extract_end}"
export DCBK_US_EXTRACT_STEP="${extract_step}"
export DCBK_US_TOLERANCES="${tolerances_csv}"
export DCBK_US_WINDOW_START="${window_start}"
export DCBK_US_WINDOW_END="${window_end}"
export DCBK_US_WINDOW_STEP="${window_step}"
export DCBK_WHAM_META_START="${window_start}"
export DCBK_WHAM_META_END="${window_end}"
export DCBK_WHAM_META_STEP="${meta_step}"
export DCBK_WHAM_FORCE_CONSTANT="${wham_force}"
export DCBK_WHAM_MIN="${wham_min}"
export DCBK_WHAM_MAX="${wham_max}"
export DCBK_WHAM_BINS="${wham_bins}"
export DCBK_WHAM_TEMP="${wham_temp}"

for rep in "${replica_ids[@]}"; do
    rep="${rep//[[:space:]]/}"
    [[ -n "${rep}" ]] || continue
    smd_suffix="${suffix_pattern//\{rep\}/${rep}}"
    dcbk_log "Running USMD/WHAM for replica '${rep}' in suffix '${smd_suffix}'."

    for lig_dir in "${ligand_dirs[@]}"; do
        target_dir="${lig_dir}/${smd_suffix}"
        dcbk_require_dir "${target_dir}"
        dcbk_require_file "${target_dir}/comp_sol.prmtop"
        dcbk_require_file "${target_dir}/asmd.nc"
        dcbk_require_file "${target_dir}/05_Pull_dist.dat"
        dcbk_require_file "${target_dir}/dist.example.RST"

        dcbk_stage_file "${SCRIPT_DIR}/usmd_example/extract_window.py" "${target_dir}/extract_window.py" 755
        dcbk_stage_file "${SCRIPT_DIR}/usmd_example/run_usmdprep.sh" "${target_dir}/run_usmdprep.sh" 755
        dcbk_stage_file "${SCRIPT_DIR}/usmd_example/run_window_cuda.sh" "${target_dir}/run_window_cuda.sh" 755
        dcbk_stage_file "${SCRIPT_DIR}/usmd_example/01_min.in" "${target_dir}/01_min.in"
        dcbk_stage_file "${SCRIPT_DIR}/usmd_example/02_heat.in" "${target_dir}/02_heat.in"
        dcbk_stage_file "${SCRIPT_DIR}/usmd_example/03_density.in" "${target_dir}/03_density.in"
        dcbk_stage_file "${SCRIPT_DIR}/usmd_example/04_eq.in" "${target_dir}/04_eq.in"
        dcbk_stage_file "${SCRIPT_DIR}/usmd_example/06_Prod.in" "${target_dir}/06_Prod.in"
        dcbk_stage_file "${SCRIPT_DIR}/usmd_example/COM_dist.RST" "${target_dir}/COM_dist.RST"
        dcbk_stage_file "${SCRIPT_DIR}/wham_example/01_fix_dist.sh" "${target_dir}/01_fix_dist.sh" 755
        dcbk_stage_file "${SCRIPT_DIR}/wham_example/02_prepare_meta.sh" "${target_dir}/02_prepare_meta.sh" 755
        dcbk_stage_file "${SCRIPT_DIR}/wham_example/03_run_wham.sh" "${target_dir}/03_run_wham.sh" 755

        (
            cd "${target_dir}"
            ./run_usmdprep.sh
            ./run_window_cuda.sh
            ./01_fix_dist.sh
            ./02_prepare_meta.sh
            ./03_run_wham.sh
        )
    done
done

dcbk_log "DCBK USMD/WHAM workflow completed."
printf '%s\n' \
    "Complex MD: ${complex_dir}" \
    "WHAM range: ${wham_min} to ${wham_max} with ${wham_bins} bins"
