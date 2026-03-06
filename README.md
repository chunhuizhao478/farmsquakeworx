farmsquakeworx
=====

A MOOSE-based application for dynamic earthquake rupture simulations, featuring slip weakening friction, damage-breakage mechanics (CDBM), rate-state friction, and nonlocal damage regularization.

## Features

- **Multi-fault dynamic rupture** — Automated JSON-to-simulation pipeline for arbitrary 2D fault geometries ([MultiFault SandBox](CHANGELOG.md#multifault-sandbox-automated-multi-fault-dynamic-rupture-simulations))
- **Single-fault benchmarks** — TPV205 2D/3D, TPV14 2D, TPV26 3D with JSON config system
- **Damage-breakage mechanics** — 3D CDBM with slip weakening, nonlocal regularization, and static variants
- **Rate-state friction** — 2D/3D rate-state friction with custom interface kernels
- **Application presets** — Ready-to-use configurations for elastic, CDBM, CDBM+fault, and poroelastic simulations

## Quick Start

```bash
# Build the application
make -j4

# Run a single-fault benchmark
cd applications/dynamicelastic_app
python generate_input.py config/example_config_tpv205_2d.json

# Run a multi-fault simulation
python generate_multifault.py config/example_config_multifault.json

# Run unit tests
make -j4 -C unit && ./unit/farmsquakeworx-unit-opt
```

## Documentation

- [CHANGELOG.md](CHANGELOG.md) — Version history and release notes
- [devdoc/](devdoc/) — Developer documentation and design documents

## More Information

Built on the [MOOSE Framework](http://mooseframework.org/create-an-app/).
