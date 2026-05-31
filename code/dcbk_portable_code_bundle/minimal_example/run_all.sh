#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./run_all.sh [config_file]

Description:
  One-click wrapper for the full DCBK workflow:
    premd -> md -> smd -> usmd

  If no config file is given, the script uses:
    ./example.env

Config highlights:
  PROTEIN_PDB      Required
  LIGAND_FILE      Required
  PREFIX           Optional, default: ligand basename
  WORK_ROOT        Optional, default: ./runs
  START_STAGE      Optional: premd | md | smd | usmd
  STOP_AFTER       Optional: premd | md | smd | usmd

Example:
  ./run_all.sh
  ./run_all.sh ./my_case.env
EOF
}

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
    log "ERROR: $*"
    exit 1
}

stage_index() {
    case "$1" in
        premd) echo 0 ;;
        md) echo 1 ;;
        smd) echo 2 ;;
        usmd) echo 3 ;;
        *) return 1 ;;
    esac
}

abs_path() {
    python3 - "$1" <<'PY'
import os
import sys

print(os.path.abspath(sys.argv[1]))
PY
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${1:-${SCRIPT_DIR}/example.env}"
CONFIG_FILE="$(abs_path "${CONFIG_FILE}")"
[[ -f "${CONFIG_FILE}" ]] || die "Config file not found: ${CONFIG_FILE}"

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

: "${PROTEIN_PDB:?Set PROTEIN_PDB in ${CONFIG_FILE}}"
: "${LIGAND_FILE:?Set LIGAND_FILE in ${CONFIG_FILE}}"

PROTEIN_PDB="$(abs_path "${PROTEIN_PDB}")"
LIGAND_FILE="$(abs_path "${LIGAND_FILE}")"
[[ -f "${PROTEIN_PDB}" ]] || die "Protein file not found: ${PROTEIN_PDB}"
[[ -f "${LIGAND_FILE}" ]] || die "Ligand file not found: ${LIGAND_FILE}"

PREMD_FRAGMENTS="${PREMD_FRAGMENTS:-}"
if [[ -n "${PREMD_FRAGMENTS}" ]]; then
    PREMD_FRAGMENTS="$(abs_path "${PREMD_FRAGMENTS}")"
    [[ -f "${PREMD_FRAGMENTS}" ]] || die "PREMD_FRAGMENTS not found: ${PREMD_FRAGMENTS}"
fi

WORK_ROOT="${WORK_ROOT:-${SCRIPT_DIR}/runs}"
WORK_ROOT="$(abs_path "${WORK_ROOT}")"
mkdir -p "${WORK_ROOT}"

ligand_base="$(basename "${LIGAND_FILE}")"
ligand_stem="${ligand_base%.*}"
PREFIX="${PREFIX:-${ligand_stem}}"

START_STAGE="${START_STAGE:-premd}"
STOP_AFTER="${STOP_AFTER:-usmd}"
START_IDX="$(stage_index "${START_STAGE}")" || die "Invalid START_STAGE: ${START_STAGE}"
STOP_IDX="$(stage_index "${STOP_AFTER}")" || die "Invalid STOP_AFTER: ${STOP_AFTER}"
(( START_IDX <= STOP_IDX )) || die "START_STAGE must not come after STOP_AFTER."

run_stage() {
    local stage_name="$1"
    local idx
    idx="$(stage_index "${stage_name}")"
    (( idx >= START_IDX && idx <= STOP_IDX ))
}

RUN_DIR="${WORK_ROOT}/${PREFIX}"
mkdir -p "${RUN_DIR}"

MD_TIME_NS="${MD_TIME_NS:-5}"
NUM_LIGANDS="${NUM_LIGANDS:-}"
GPUID="${GPUID:-0}"
RESID="${RESID:-}"
SSBOND="${SSBOND:-}"
MD_PREPARE_ONLY="${MD_PREPARE_ONLY:-0}"

LIGANDS_CSV="${LIGANDS_CSV:-}"
REPLICAS="${REPLICAS:-1}"
SMD_SUFFIX_PATTERN="${SMD_SUFFIX_PATTERN:-exit_smd_rep{rep}}"
SMD_RK2="${SMD_RK2:-5.0}"
GENERATE_CV="${GENERATE_CV:-1}"
CV_FILE="${CV_FILE:-}"

US_EXTRACT_START="${US_EXTRACT_START:-0}"
US_EXTRACT_END="${US_EXTRACT_END:-30}"
US_EXTRACT_STEP="${US_EXTRACT_STEP:-0.5}"
US_TOLERANCES="${US_TOLERANCES:-0.2,0.1,0.05,0.01}"
US_WINDOW_START="${US_WINDOW_START:-25.0}"
US_WINDOW_END="${US_WINDOW_END:-1.0}"
US_WINDOW_STEP="${US_WINDOW_STEP:--1.0}"
WHAM_META_STEP="${WHAM_META_STEP:--3.0}"
WHAM_MIN="${WHAM_MIN:-0}"
WHAM_MAX="${WHAM_MAX:-25}"
WHAM_BINS="${WHAM_BINS:-260}"
WHAM_TEMP="${WHAM_TEMP:-300}"
WHAM_FORCE="${WHAM_FORCE:-10.0}"

ALIGNED_PROTEIN="${RUN_DIR}/${PREFIX}_protein.pdb"
ALIGNED_LIGANDS="${RUN_DIR}/${PREFIX}_fixed.sdf"
COMPLEX_DIR="${RUN_DIR}/complex_md"

if run_stage premd; then
    log "Stage 1/4: premd"
    premd_cmd=(
        "${CODE_DIR}/DCBK_premd.sh"
        --protein "${PROTEIN_PDB}"
        --ligand "${LIGAND_FILE}"
        --prefix "${PREFIX}"
        --output-dir "${RUN_DIR}"
    )
    if [[ -n "${PREMD_FRAGMENTS}" ]]; then
        premd_cmd+=(--fragments "${PREMD_FRAGMENTS}")
    fi
    "${premd_cmd[@]}"
else
    log "Skipping premd because START_STAGE=${START_STAGE}"
fi

if run_stage md; then
    log "Stage 2/4: md"
    [[ -f "${ALIGNED_PROTEIN}" ]] || die "Expected premd output not found: ${ALIGNED_PROTEIN}"
    [[ -f "${ALIGNED_LIGANDS}" ]] || die "Expected premd output not found: ${ALIGNED_LIGANDS}"

    md_cmd=(
        "${CODE_DIR}/DCBK_md.sh"
        --protein "${ALIGNED_PROTEIN}"
        --ligands "${ALIGNED_LIGANDS}"
        --time "${MD_TIME_NS}"
        --workdir "${RUN_DIR}"
        --gpuid "${GPUID}"
    )
    if [[ -n "${NUM_LIGANDS}" ]]; then
        md_cmd+=(--num "${NUM_LIGANDS}")
    fi
    if [[ -n "${RESID}" ]]; then
        md_cmd+=(--resid "${RESID}")
    fi
    if [[ -n "${SSBOND}" ]]; then
        md_cmd+=(--ssbond "${SSBOND}")
    fi
    if [[ "${MD_PREPARE_ONLY}" == "1" ]]; then
        md_cmd+=(--prepare-only)
    fi
    "${md_cmd[@]}"

    if [[ "${MD_PREPARE_ONLY}" == "1" && "${STOP_AFTER}" != "md" ]]; then
        die "MD_PREPARE_ONLY=1 prevents later SMD/USMD stages. Set STOP_AFTER=md or disable MD_PREPARE_ONLY."
    fi
else
    log "Skipping md because requested stage range starts later."
fi

if run_stage smd; then
    log "Stage 3/4: smd"
    [[ -d "${COMPLEX_DIR}" ]] || die "Complex directory not found: ${COMPLEX_DIR}"

    smd_cmd=(
        "${CODE_DIR}/DCBK_smd.sh"
        --complex-dir "${COMPLEX_DIR}"
        --replicas "${REPLICAS}"
        --suffix-pattern "${SMD_SUFFIX_PATTERN}"
        --rk2 "${SMD_RK2}"
    )
    if [[ -n "${LIGANDS_CSV}" ]]; then
        smd_cmd+=(--ligands "${LIGANDS_CSV}")
    fi
    if [[ "${GENERATE_CV}" != "1" ]]; then
        smd_cmd+=(--no-generate-cv)
    fi
    if [[ -n "${CV_FILE}" ]]; then
        smd_cmd+=(--cv-file "${CV_FILE}" --no-generate-cv)
    fi
    "${smd_cmd[@]}"
else
    log "Skipping smd because requested stage range ends earlier."
fi

if run_stage usmd; then
    log "Stage 4/4: usmd"
    [[ -d "${COMPLEX_DIR}" ]] || die "Complex directory not found: ${COMPLEX_DIR}"

    usmd_cmd=(
        "${CODE_DIR}/DCBK_usmd.sh"
        --complex-dir "${COMPLEX_DIR}"
        --replicas "${REPLICAS}"
        --suffix-pattern "${SMD_SUFFIX_PATTERN}"
        --extract-start "${US_EXTRACT_START}"
        --extract-end "${US_EXTRACT_END}"
        --extract-step "${US_EXTRACT_STEP}"
        --tolerances "${US_TOLERANCES}"
        --window-start "${US_WINDOW_START}"
        --window-end "${US_WINDOW_END}"
        --window-step "${US_WINDOW_STEP}"
        --meta-step "${WHAM_META_STEP}"
        --wham-min "${WHAM_MIN}"
        --wham-max "${WHAM_MAX}"
        --wham-bins "${WHAM_BINS}"
        --wham-temp "${WHAM_TEMP}"
        --wham-force "${WHAM_FORCE}"
    )
    if [[ -n "${LIGANDS_CSV}" ]]; then
        usmd_cmd+=(--ligands "${LIGANDS_CSV}")
    fi
    "${usmd_cmd[@]}"
else
    log "Skipping usmd because requested stage range ends earlier."
fi

log "Pipeline completed."
printf '%s\n' \
    "Run directory: ${RUN_DIR}" \
    "Protein used:  ${PROTEIN_PDB}" \
    "Ligand used:   ${LIGAND_FILE}"
