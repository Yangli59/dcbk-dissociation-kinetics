#!/usr/bin/env bash

if [[ -n "${DCBK_COMMON_SH_LOADED:-}" ]]; then
    return 0
fi
DCBK_COMMON_SH_LOADED=1

dcbk_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

dcbk_log() {
    printf '[%s] %s\n' "$(dcbk_timestamp)" "$*" >&2
}

dcbk_die() {
    dcbk_log "ERROR: $*"
    exit 1
}

dcbk_require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || dcbk_die "Required command not found: $cmd"
}

dcbk_require_file() {
    local path="$1"
    [[ -f "$path" ]] || dcbk_die "Required file not found: $path"
}

dcbk_require_dir() {
    local path="$1"
    [[ -d "$path" ]] || dcbk_die "Required directory not found: $path"
}

dcbk_python() {
    printf '%s\n' "${DCBK_PYTHON:-python3}"
}

dcbk_abs_path() {
    local path="$1"
    python3 - "$path" <<'PY'
import os
import sys

print(os.path.abspath(sys.argv[1]))
PY
}

dcbk_activate_optional_env() {
    if [[ -n "${DCBK_AMBER_SH:-}" ]]; then
        # shellcheck source=/dev/null
        source "${DCBK_AMBER_SH}"
    elif [[ -n "${AMBERHOME:-}" && -f "${AMBERHOME}/amber.sh" ]]; then
        # shellcheck source=/dev/null
        source "${AMBERHOME}/amber.sh"
    fi

    if [[ -n "${DCBK_CONDA_SH:-}" ]]; then
        # shellcheck source=/dev/null
        source "${DCBK_CONDA_SH}"
    fi

    if [[ -n "${DCBK_CONDA_ENV:-}" ]]; then
        command -v conda >/dev/null 2>&1 || dcbk_die "DCBK_CONDA_ENV is set but 'conda' is unavailable."
        conda activate "${DCBK_CONDA_ENV}"
    fi

    if [[ -n "${DCBK_STARTCUDA_SH:-}" ]]; then
        # shellcheck source=/dev/null
        source "${DCBK_STARTCUDA_SH}"
    fi
}

dcbk_cleanup_optional_env() {
    if [[ -n "${DCBK_ENDCUDA_SH:-}" ]]; then
        # shellcheck source=/dev/null
        source "${DCBK_ENDCUDA_SH}"
    fi
}

dcbk_check_python_module() {
    local python_bin="$1"
    local module_name="$2"

    "$python_bin" -c "import ${module_name}" >/dev/null 2>&1 || \
        dcbk_die "Python module '${module_name}' is required but unavailable in ${python_bin}."
}

dcbk_script_dir() {
    local source_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    dcbk_abs_path "$(dirname "${source_path}")"
}

dcbk_discover_ligand_dirs() {
    local complex_dir="$1"
    find "$complex_dir" -maxdepth 1 -mindepth 1 -type d -name 'lig*' | sort -V
}

dcbk_stage_file() {
    local src="$1"
    local dest="$2"
    local mode="${3:-644}"

    dcbk_require_file "$src"
    install -m "$mode" "$src" "$dest"
}
