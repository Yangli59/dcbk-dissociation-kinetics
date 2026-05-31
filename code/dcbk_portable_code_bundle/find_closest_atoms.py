import sys
import mdtraj as md
import numpy as np

pdb_file = sys.argv[1]
traj = md.load(pdb_file)
top = traj.topology

lig_atoms = [atom.index for atom in top.atoms if atom.residue.index == 0]
prot_atoms = [atom.index for atom in top.atoms if atom.residue.index > 0]

coords = traj.xyz[0]
lig_coords = coords[lig_atoms]
prot_coords = coords[prot_atoms]

dist_matrix = np.linalg.norm(lig_coords[:, None, :] - prot_coords[None, :, :], axis=-1)
flat_indices = np.dstack(np.unravel_index(np.argsort(dist_matrix, axis=None), dist_matrix.shape))[0]

used_lig = set()
used_prot = set()
lig_selected = []
prot_selected = []

for lig_idx, prot_idx in flat_indices:
    lig_atom = lig_atoms[lig_idx]
    prot_atom = prot_atoms[prot_idx]
    if lig_atom not in used_lig and prot_atom not in used_prot:
        lig_selected.append(lig_atom + 1)
        prot_selected.append(prot_atom + 1)
        used_lig.add(lig_atom)
        used_prot.add(prot_atom)
    if len(lig_selected) == 3:
        break

if len(lig_selected) < 3:
    print("Warning: less than 3 unique ligand-protein atom pairs found.", file=sys.stderr)

print(",".join(str(x) for x in prot_selected) + ",")
print(",".join(str(x) for x in lig_selected) + ",")
