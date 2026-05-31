# /code – Computational workflows for DCBK

This directory contains all custom Python and shell scripts used for:

- simulation processing
- PMF reconstruction
- feature generation
- machine learning (training, evaluation, SHAP analysis)
- figure generation

## Folder structure
code/
├── dcbk_portable_code_bundle/
├── ml_models/
├── shap_analysis/
└── figure_generation/

text

## Quick start

1. **Set up the environment** (conda recommended):
   ```bash
   conda env create -f ../environment.yml
   conda activate dcbk
2. **Run the main pipeline**
   ```bash
   cd dcbk_portable_code_bundle
   bash DCBK_premd.sh   # equilibration
   bash DCBK_md.sh      # MD simulation
   bash DCBK_smd.sh     # PMF reconstruction
   
## For ML and SHAP steps, see the ml_models/ and shap_analysis/ subdirectories.

## How to cite this code
If you use this code, please include the following Code availability statement:

The complete set of custom scripts used for simulation‑processing, PMF reconstruction, feature generation, machine learning, SHAP analysis and figure generation was implemented in Python and shell scripts. All code is publicly available on GitHub at https://github.com/Yangli59/dcbk-dissociation-kinetics. The code is released under the MIT License.

## License
All code in this directory is released under the MIT License. See the root LICENSE file.
