#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

from rdkit import Chem
from rdkit.Chem import AllChem, rdFMCS


def load_single_molecule(path: Path):
    suffix = path.suffix.lower()
    if suffix in {".sdf", ".sd"}:
        supplier = Chem.SDMolSupplier(str(path), removeHs=False)
        for mol in supplier:
            if mol is not None:
                return mol
        return None
    if suffix == ".mol2":
        return Chem.MolFromMol2File(str(path), removeHs=False)
    if suffix == ".mol":
        return Chem.MolFromMolFile(str(path), removeHs=False)
    if suffix == ".pdb":
        return Chem.MolFromPDBFile(str(path), removeHs=False)
    raise ValueError(f"Unsupported reference format: {path}")


def load_multiple_molecules(path: Path):
    suffix = path.suffix.lower()
    if suffix not in {".sdf", ".sd"}:
        raise ValueError("Fragment input must be an SDF file.")

    molecules = []
    supplier = Chem.SDMolSupplier(str(path), removeHs=False)
    for mol in supplier:
        if mol is not None:
            molecules.append(mol)
    return molecules


def build_atom_map(reference, fragment):
    ref_no_h = Chem.RemoveHs(reference)
    frag_no_h = Chem.RemoveHs(fragment)

    if ref_no_h.GetNumAtoms() == 0 or frag_no_h.GetNumAtoms() == 0:
        return []

    ref_full_map = reference.GetSubstructMatch(ref_no_h)
    frag_full_map = fragment.GetSubstructMatch(frag_no_h)

    direct_match = ref_no_h.GetSubstructMatch(frag_no_h)
    if direct_match:
        return [
            (frag_full_map[i], ref_full_map[direct_match[i]])
            for i in range(len(direct_match))
        ]

    mcs = rdFMCS.FindMCS(
        [ref_no_h, frag_no_h],
        ringMatchesRingOnly=True,
        completeRingsOnly=True,
        atomCompare=rdFMCS.AtomCompare.CompareElements,
        bondCompare=rdFMCS.BondCompare.CompareOrderExact,
        timeout=5,
    )
    if not mcs.smartsString:
        return []

    core = Chem.MolFromSmarts(mcs.smartsString)
    if core is None:
        return []

    ref_match = ref_no_h.GetSubstructMatch(core)
    frag_match = frag_no_h.GetSubstructMatch(core)
    if not ref_match or not frag_match:
        return []

    return [
        (frag_full_map[frag_match[i]], ref_full_map[ref_match[i]])
        for i in range(len(ref_match))
    ]


def align_fragment(reference, fragment):
    aligned = Chem.Mol(fragment)
    if aligned.GetNumConformers() == 0:
        status = AllChem.EmbedMolecule(aligned, randomSeed=42)
        if status != 0:
            raise RuntimeError("Unable to generate a 3D conformer for fragment alignment.")

    atom_map = build_atom_map(reference, aligned)
    if len(atom_map) < 3:
        name = aligned.GetProp("_Name") if aligned.HasProp("_Name") else "unnamed_fragment"
        raise RuntimeError(f"Failed to find a stable atom mapping for {name}.")

    AllChem.AlignMol(aligned, reference, atomMap=atom_map)
    return aligned, len(atom_map)


def main():
    parser = argparse.ArgumentParser(
        description="Align fragment molecules to a reference ligand pose and write a portable *_fixed.sdf file."
    )
    parser.add_argument("--reference", required=True, help="Reference ligand with the desired binding pose (.mol2/.sdf/.mol/.pdb).")
    parser.add_argument("--fragments", required=True, help="Input fragment ensemble in SDF format.")
    parser.add_argument("--output", required=True, help="Output SDF path for the aligned molecules.")
    args = parser.parse_args()

    reference_path = Path(args.reference)
    fragments_path = Path(args.fragments)
    output_path = Path(args.output)

    reference = load_single_molecule(reference_path)
    if reference is None:
        raise SystemExit(f"Unable to read reference ligand: {reference_path}")
    if reference.GetNumConformers() == 0:
        raise SystemExit("Reference ligand does not contain 3D coordinates.")

    molecules = load_multiple_molecules(fragments_path)
    if not molecules:
        raise SystemExit(f"No readable molecules were found in {fragments_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    writer = Chem.SDWriter(str(output_path))
    try:
        for idx, molecule in enumerate(molecules, start=1):
            try:
                aligned, mapped_atoms = align_fragment(reference, molecule)
            except Exception as exc:
                raise SystemExit(f"Alignment failed for molecule #{idx}: {exc}") from exc

            if not aligned.HasProp("_Name"):
                aligned.SetProp("_Name", f"Molecule_{idx}")
            aligned.SetProp("AlignedTo", reference_path.name)
            aligned.SetProp("AlignedAtomCount", str(mapped_atoms))
            writer.write(aligned)
    finally:
        writer.close()

    print(f"Aligned {len(molecules)} molecules to {reference_path.name}")
    print(f"Output written to {output_path}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
