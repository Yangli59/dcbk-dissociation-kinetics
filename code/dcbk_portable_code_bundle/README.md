# DCBK Code Bundle

This directory now exposes the DCBK workflow through four portable entry scripts:

- `DCBK_premd.sh`: generate or reuse fragment ensembles and align them to the reference ligand pose.
- `DCBK_md.sh`: build Amber systems and run the MD preparation/production stage.
- `DCBK_smd.sh`: generate `cv.dat` and launch the SMD stage.
- `DCBK_usmd.sh`: run umbrella sampling and WHAM on one or more SMD outputs.

## Minimum Requirements

- Amber executables on `PATH` or `AMBERHOME` configured: `tleap`, `pdb4amber`, `antechamber`, `parmchk2`, `cpptraj`, and `pmemd.cuda` or another engine exposed via `DCBK_MD_ENGINE`
- `wham` on `PATH`
- A Python environment with:
  - `rdkit` for `DCBK_premd.sh`
  - `mdtraj` for `DCBK_smd.sh`
  - `numpy` for `DCBK_usmd.sh`

Optional environment helpers:

- `DCBK_AMBER_SH=/path/to/amber.sh`
- `DCBK_CONDA_SH=/path/to/conda.sh`
- `DCBK_CONDA_ENV=my_env`
- `DCBK_PYTHON=python3`
- `DCBK_MD_ENGINE=pmemd.cuda`

## Typical Workflow

From a clean working directory containing a protein PDB and a docked ligand:

```bash
../08_dcbk_code/DCBK_premd.sh \
  --protein target_protein.pdb \
  --ligand target.mol2 \
  --prefix target

../08_dcbk_code/DCBK_md.sh \
  --protein target_protein.pdb \
  --ligands target_fixed.sdf \
  --time 5

../08_dcbk_code/DCBK_smd.sh \
  --complex-dir complex_md \
  --replicas 1,2,3

../08_dcbk_code/DCBK_usmd.sh \
  --complex-dir complex_md \
  --replicas 1,2,3
```

## Minimal Example

For a shareable one-click entry point, use [minimal_example/README.md](./minimal_example/README.md).

The shortest path is:

```bash
cd minimal_example
./run_all.sh
```

## Notes

- `DCBK_premd.sh` writes standardized outputs: `<prefix>_protein.pdb`, `<prefix>_fragments.sdf`, and `<prefix>_fixed.sdf`.
- `DCBK_smd.sh` auto-builds `cv.dat` unless `--no-generate-cv` is supplied.
- `DCBK_usmd.sh` stages the required `usmd_example` and `wham_example` template files into each SMD directory automatically.
- `FlexSim.py` was patched to remove site-specific `pdb4amber` paths and to support `--prepare-only` plus a configurable MD engine.
