QuakeWorx MOOSE-FARMS DynamicElastic Application
Created By Chunhui Zhao, Feb 24th, 2026

## Single-fault benchmarks (generate_input.py)

# Generate the .i input file (writes to output_dir from defaults)
python generate_input.py config/example_config_tpv205_2d.json

# Preview without writing (print to stdout)
python generate_input.py config/example_config_tpv205_2d.json --dry-run

# Override output directory
python generate_input.py config/example_config_tpv205_2d.json --output-dir /tmp/my_run

# See all default parameters for a benchmark
python generate_input.py --list-params --benchmark tpv205_2d

For the website backend, the call would be something like:

from generate_input import generate

# user_config_path = path to the JSON file the user submitted
output_path, rendered_content = generate(user_config_path)

# rendered_content is the complete MOOSE .i file as a string
# output_path is where it would be written

## Multi-fault pipeline (generate_multifault.py)

Generates a complete MOOSE .i input file for multi-fault 2D dynamic rupture
simulations from a single JSON config. Automates: .geo generation, Gmsh
meshing, element extraction, and .i file rendering.

# Full pipeline (generates .geo, runs Gmsh, renders .i)
python generate_multifault.py config/example_config_multifault.json

# Preview without mesh generation (dry-run)
python generate_multifault.py config/example_config_multifault.json --dry-run

# Override output directory
python generate_multifault.py config/example_config_multifault.json --output-dir /tmp/my_run

Key design choices (following farms_benchmark/tpv142D_tria.i reference):
  - CZM material: SlipWeakeningFrictionczm2dParametricStudy (declares total_shear_traction)
  - AuxKernels: FarmsMaterialRealAux for local (fault-aligned) quantities
    (local_shear_jump, local_normal_jump, local_shear_traction, etc.)
  - VectorPostprocessors: SideValueSampler (1 block per fault, boundary-based, sorted spatially)
  - Outputs: Exodus + CSV with configurable intervals

## Unit tests

  - tests/test_generate_input.py — tests covering all functions plus integration tests
  - tests/test_generate_multifault.py — tests for multi-fault pipeline
  - Run with: python -m unittest discover -s tests -v
