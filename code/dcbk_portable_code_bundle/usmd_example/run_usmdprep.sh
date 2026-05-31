#!/usr/bin/env bash
set -euo pipefail

: "${DCBK_PYTHON:=python3}"
: "${DCBK_US_EXTRACT_START:=0}"
: "${DCBK_US_EXTRACT_END:=30}"
: "${DCBK_US_EXTRACT_STEP:=0.5}"
: "${DCBK_US_TOLERANCES:=0.2,0.1,0.05,0.01}"

IFS=',' read -r -a tolerances <<< "${DCBK_US_TOLERANCES}"

for tolerance in "${tolerances[@]}"; do
    tolerance="${tolerance//[[:space:]]/}"
    [[ -n "${tolerance}" ]] || continue
    "${DCBK_PYTHON}" extract_window.py \
        -i asmd.nc \
        -p comp_sol.prmtop \
        -d 05_Pull_dist.dat \
        -start "${DCBK_US_EXTRACT_START}" \
        -end "${DCBK_US_EXTRACT_END}" \
        -space "${DCBK_US_EXTRACT_STEP}" \
        -tol "${tolerance}"
done

if [[ -f "COM_dist.RST" && -f "dist.example.RST" ]]; then
    iresid_line="$(grep '^[[:space:]]*iresid=' dist.example.RST || true)"
    igr1_line="$(grep '^[[:space:]]*igr1=' dist.example.RST || true)"
    igr2_line="$(grep '^[[:space:]]*igr2=' dist.example.RST || true)"

    if [[ -n "${iresid_line}" && -n "${igr1_line}" && -n "${igr2_line}" ]]; then
        cp COM_dist.RST COM_dist.RST.bak
        sed -i.bak "
            /^[[:space:]]*iresid=/c\\ ${iresid_line}
            /^[[:space:]]*igr1=/c\\ ${igr1_line}
            /^[[:space:]]*igr2=/c\\ ${igr2_line}
        " COM_dist.RST
    fi
elif [[ -f "COM_dist.RST" && ! -f "dist.example.RST" && -f "cv.in" ]]; then
    cv_line="$(grep '^[[:space:]]*cv_i[[:space:]]*=' cv.in || true)"

    if [[ -n "${cv_line}" ]]; then
        values="$(echo "${cv_line}" | sed -E 's/.*cv_i[[:space:]]*=[[:space:]]*//; s/[[:space:]]//g' | sed 's/,$//')"
        IFS=',' read -r -a arr <<< "${values}"
        n="${#arr[@]}"

        if [[ "${n}" -ge 4 ]]; then
            group_size=$(( (n - 2) / 2 ))
        else
            group_size=1
        fi

        igr1_list=()
        for ((i = 0; i < group_size && i < n; i++)); do
            value="${arr[$i]}"
            if [[ -n "${value}" && "${value}" != "0" ]]; then
                igr1_list+=("${value}")
            fi
        done

        igr2_list=()
        start=$((group_size + 1))
        end=$((group_size + group_size))
        for ((i = start; i <= end && i < n; i++)); do
            value="${arr[$i]}"
            if [[ -n "${value}" && "${value}" != "0" ]]; then
                igr2_list+=("${value}")
            fi
        done

        igr1_line=""
        if [[ ${#igr1_list[@]} -gt 0 ]]; then
            igr1_line="igr1=$(IFS=,; printf '%s,' "${igr1_list[*]}")"
        fi

        igr2_line=""
        if [[ ${#igr2_list[@]} -gt 0 ]]; then
            igr2_line="igr2=$(IFS=,; printf '%s,' "${igr2_list[*]}")"
        fi

        replace_or_add() {
            local key="$1"
            local line="$2"
            local file="$3"

            if grep -q "^[[:space:]]*${key}=" "${file}"; then
                if [[ -n "${line}" ]]; then
                    sed -i.bak "s|^[[:space:]]*${key}=.*|${line}|" "${file}"
                else
                    sed -i.bak "/^[[:space:]]*${key}=/d" "${file}"
                fi
            elif [[ -n "${line}" ]]; then
                if grep -q '^/' "${file}"; then
                    sed -i.bak "/^\\//i ${line}" "${file}"
                else
                    echo "${line}" >> "${file}"
                fi
            fi
        }

        cp COM_dist.RST COM_dist.RST.bak
        replace_or_add "igr1" "${igr1_line}" "COM_dist.RST"
        replace_or_add "igr2" "${igr2_line}" "COM_dist.RST"
    fi
fi
