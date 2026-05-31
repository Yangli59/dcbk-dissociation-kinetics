# Minimal Example

This directory provides the shortest shareable entry point for running the full DCBK workflow.

## Files

- `run_all.sh`: one-click wrapper for `premd -> md -> smd -> usmd`
- `example.env`: editable configuration file
- `inputs/`: put the test protein and ligand here

## Quick Start

1. Put your files in `inputs/` using the default names:
   - `target_protein.pdb`
   - `target_ligand.mol2`
2. Edit `example.env` only if you need different filenames, output locations, or stage parameters.
3. Run:

```bash
cd minimal_example
./run_all.sh
```

Outputs will be written to:

```bash
minimal_example/runs/target/
```

## Common Variants

Run only through MD input generation:

```bash
STOP_AFTER="md"
MD_PREPARE_ONLY="1"
```

Restart from SMD using an existing `runs/target/complex_md`:

```bash
START_STAGE="smd"
STOP_AFTER="usmd"
```

Use a precomputed fragment file instead of generating fragments:

```bash
PREMD_FRAGMENTS="${CONFIG_DIR}/inputs/target_fragments.sdf"
```

## Dependencies

The same dependencies described in the parent [README](../README.md) apply here.
