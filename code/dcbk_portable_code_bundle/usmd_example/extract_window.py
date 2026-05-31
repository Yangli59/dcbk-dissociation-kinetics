#!/usr/bin/env python3
import argparse
import os
import shutil
import subprocess
import sys

import numpy as np


def parse_args():
    parser = argparse.ArgumentParser(
        description="Extract restart frames at target distances for the DCBK USMD stage."
    )
    parser.add_argument("-i", required=True, help="Trajectory input file.")
    parser.add_argument("-p", required=True, help="Topology file.")
    parser.add_argument("-d", required=True, help="Distance file.")
    parser.add_argument("-start", required=True, type=float, help="Start distance.")
    parser.add_argument("-end", required=True, type=float, help="End distance.")
    parser.add_argument("-space", required=True, type=float, help="Distance spacing.")
    parser.add_argument("-tol", "--tolerance", type=float, default=float(os.environ.get("DCBK_US_TOLERANCE", "0.1")))
    return parser.parse_args()


def main():
    args = parse_args()

    for path in (args.i, args.p, args.d):
        if not os.path.isfile(path):
            raise SystemExit(f"Cannot find required input: {path}")

    cpptraj_path = shutil.which("cpptraj")
    if cpptraj_path is None:
        amberhome = os.getenv("AMBERHOME")
        if amberhome:
            cpptraj_path = os.path.join(amberhome, "bin", "cpptraj")
    if cpptraj_path is None or not os.path.isfile(cpptraj_path):
        raise SystemExit("cpptraj could not be located. Set AMBERHOME or add cpptraj to PATH.")

    spacing = args.space
    if args.end < args.start and spacing > 0:
        spacing *= -1
    if args.end > args.start and spacing < 0:
        spacing *= -1

    distances = np.loadtxt(args.d, skiprows=1, usecols=(1,))
    targets = np.arange(args.start, args.end + spacing, spacing)

    for target in targets:
        found_frame = False
        for frame_idx, distance in enumerate(distances):
            if (target - args.tolerance) < distance < (target + args.tolerance):
                with open("frame_extract.trajin", "w", encoding="utf-8") as handle:
                    handle.write(f"trajin {args.i} {frame_idx + 1} {frame_idx + 1} 1\n")
                    handle.write(f"trajout frame_{target:.1f}.rst restart\n")
                with open("frame_extract.trajin", "r", encoding="utf-8") as input_handle, open("out", "w", encoding="utf-8") as output_handle:
                    subprocess.run([cpptraj_path, args.p], stdin=input_handle, stdout=output_handle, check=True)
                os.remove("frame_extract.trajin")
                os.remove("out")
                found_frame = True
                break
        if not found_frame:
            print(f"No corresponding frame found for point: {target:.1f}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
