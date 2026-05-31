import random
import sys
from rdkit import Chem
from rdkit.Chem import BRICS, Descriptors, SanitizeFlags, AllChem
import os
import subprocess


def preprocess_molecule(mol):
    if mol is None:
        return None
    try:
        mol = Chem.AddHs(mol, addCoords=True)
        Chem.SanitizeMol(mol, sanitizeOps=SanitizeFlags.SANITIZE_ALL ^ SanitizeFlags.SANITIZE_KEKULIZE)
    except:
        try:
            Chem.SetAromaticity(mol)
            Chem.SetHybridization(mol)
            Chem.SanitizeMol(mol, sanitizeOps=SanitizeFlags.SANITIZE_ALL ^ SanitizeFlags.SANITIZE_KEKULIZE)
        except:
            return None
    try:
        AllChem.UFFOptimizeMolecule(mol)
    except:
        pass
    return mol


def fix_fragment_hydrogens(fragment):
    if fragment is None:
        return None
    try:
        frag = Chem.AddHs(fragment)
        AllChem.EmbedMolecule(frag, randomSeed=42)
        AllChem.UFFOptimizeMolecule(frag)
        Chem.SanitizeMol(frag)
        return frag
    except Exception as e:
        print(f"[Warning] Fragment failed to fix: {e}")
        return fragment


def get_molecular_weight(mol):
    if mol is None:
        return 0.0
    return round(Descriptors.MolWt(mol), 2)


def fragment_molecule(mol):
    if mol is None:
        return []
    try:
        bonds = list(BRICS.FindBRICSBonds(mol))
    except:
        return [mol]
    if not bonds:
        return [mol]
    selected_bond = random.choice(bonds)
    emol = Chem.EditableMol(mol)
    try:
        emol.RemoveBond(*selected_bond[0])
    except:
        return [mol]
    fragmented_mol = emol.GetMol()
    try:
        fragments = Chem.GetMolFrags(fragmented_mol, asMols=True)
        return list(fragments) if len(fragments) >= 2 else [mol]
    except:
        return [mol]


def write_to_sdf(molecules, output_file, names=None):
    if names is None:
        names = [f"Molecule_{i+1}" for i in range(len(molecules))]
    writer = Chem.SDWriter(output_file)
    for mol, name in zip(molecules, names):
        if mol is not None:
            mol.SetProp("_Name", name)
            writer.write(mol)
    writer.close()


def convert_sdf_to_mol2_with_obabel(sdf_file, mol2_file):
    try:
        cmd = [
            "obabel", sdf_file, "-O", mol2_file,
            "-h", "--gen3d", "-p", "7.4", "--partialcharge", "gasteiger"
        ]
        subprocess.run(cmd, check=True)
        print(f"Successfully converted {sdf_file} to {mol2_file} with correct atom types")
        return True
    except Exception as e:
        print(f"Error: Open Babel conversion failed: {e}")
        return False


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <mol2_file>")
        sys.exit(1)

    mol2_file = sys.argv[1]
    mol = Chem.MolFromMol2File(mol2_file) or Chem.MolFromMolFile(mol2_file) or Chem.MolFromSmiles(mol2_file)

    if mol is None:
        print("Error: Unable to read molecule from file. Check file path and format.")
        sys.exit(1)

    mol = preprocess_molecule(mol)
    if mol is None:
        print("Error: Failed to preprocess molecule. Check structure validity.")
        sys.exit(1)

    original_mol_weight = get_molecular_weight(mol)

    #new
    def get_filtered_fragments(mol, min_mw=20, min_count=3, max_retries=5):
        """
        Fragment the molecule, filter by molecular weight, and retry if not enough fragments.
        """
        for attempt in range(max_retries):
            fragments_round1 = fragment_molecule(mol)
            if not fragments_round1:
                continue
            largest_frag = max(fragments_round1, key=lambda x: x.GetNumAtoms() if x else 0)

            fragments_round2 = fragment_molecule(largest_frag)
            combined = list(fragments_round1) + list(fragments_round2)
            if largest_frag in combined:
                combined.remove(largest_frag)

            # Fix H, filter by MW
            filtered = []
            for f in combined:
                if f is None:
                    continue
                fixed = fix_fragment_hydrogens(f)
                if fixed and get_molecular_weight(fixed) > min_mw:
                    filtered.append(fixed)

            if len(filtered) >= min_count:
                return filtered

        return filtered  # return whatever was found after max retries

    mol = fix_fragment_hydrogens(mol)
    final_fragments = get_filtered_fragments(mol, min_mw=70, min_count=3, max_retries=5)

    base_name = os.path.splitext(os.path.basename(mol2_file))[0]
    smiles_file = f"{base_name}_fragments.smi"
    sdf_file = f"{base_name}_fragments.sdf"
    mol2_output_file = f"{base_name}_fragments.mol2"

    all_molecules = [mol] + final_fragments
    all_names = ["Original"] + [f"Fragment_{i+1}" for i in range(len(final_fragments))]

    with open(smiles_file, "w") as f:
        f.write("SMILES,NAME\n")
        for mol, name in zip(all_molecules, all_names):
            smiles = Chem.MolToSmiles(mol) if mol else ""
            f.write(f"{smiles},{name}\n")

    write_to_sdf(all_molecules, sdf_file, all_names)
    success = convert_sdf_to_mol2_with_obabel(sdf_file, mol2_output_file)

    if success:
        print(f"Results saved to:")
        print(f"  1. SMILES format: {smiles_file}")
        print(f"  2. SDF format: {sdf_file}")
        print(f"  3. Mol2 format: {mol2_output_file}")
    else:
        print(f"Warning: Failed to generate Mol2. Using SDF instead: {sdf_file}")

    print(f"Original molecular weight: {original_mol_weight} Da")
    for i, frag in enumerate(final_fragments, 1):
        print(f"Fragment {i}: {Chem.MolToSmiles(frag)} | MW: {get_molecular_weight(frag)} Da")
