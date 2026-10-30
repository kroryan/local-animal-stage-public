# Local Animal Stage — Godot Source Extraction

This repository contains a deliberately stripped Godot source snapshot of the **Local Animal Stage** presentation and connectome visualization components.

It is a standalone open-source code excerpt intended for review, attribution, and study. It is **not a complete application** and is not expected to run or build independently.

The proprietary QORVYX game, simulation, economic engine, and commercial integrations remain separate and are not included in this repository.

## Included

- A minimal Godot project shell and an observatory entry scene.
- Animal laboratory and station presentation scripts.
- Connectome visualization and leaky integrate-and-fire (LIF) runtime components.
- Chart presentation helpers.
- TauPlot, included unchanged under its BSD-3-Clause license.
- Eight animal preview GLB models copied unchanged from Open Animal Stage commit `4cb2c8610c801febf355279e58a920897ce99e3e`.
- Applicable third-party license texts, copyright notices, and attribution documentation.

## Original Projects and Derivative Work

This source extraction includes code and assets derived from the following projects by **Pr1nted**:

### Open Fly

Original project: https://github.com/Pr1nted/Open-Fly

Copyright 2026 Pr1nted  
License: Apache License 2.0

The `connectome_brain.gd` implementation is derived from and adapted from the connectome simulation and leaky integrate-and-fire runtime developed in Open Fly.

The Godot implementation contains modifications and adaptations for the Local Animal Stage environment.

### Open Animal Stage

Original project: https://github.com/Pr1nted/Open-Animal-Stage

Copyright 2026 Pr1nted  
License: Apache License 2.0

The animal laboratory, station presentation, and associated stage scripts are derived from and adapted from the original Open Animal Stage project.

The included animal preview GLB models are copied unchanged from commit `4cb2c8610c801febf355279e58a920897ce99e3e`.

The Godot presentation scripts contain modifications for the Local Animal Stage environment.

### Attribution and Changes

The original authors retain their respective copyright notices.

This repository preserves the applicable original license texts and NOTICE files.

The derived components have been adapted to Godot and separated from the original browser-based implementation.

All direct game-economy integrations and proprietary product-specific references have been removed from this source extraction.

These modifications are not endorsed or maintained by the original project author.

## Intentionally Excluded

The following components are not included:

- Proprietary QORVYX game simulation and economic engine.
- AI agents and behavior trees.
- Networking and multiplayer infrastructure.
- DRM and platform services.
- Server-side code.
- Commercial product interface and integrations.
- Build outputs and signing keys.
- Local brain datasets and connectome packages.
- Brain rosters and proprietary data exports.
- Proprietary artwork, audio, and fonts.

This repository does not contain third-party connectome datasets, including FlyWire, MaleCNS, Fish1, Ciona, C. elegans, or larval Drosophila brain data.

The source extraction is not a runnable replacement for the full application.

## Third-Party Components

**Open Fly**  
Copyright 2026 Pr1nted  
Apache License 2.0

**Open Animal Stage**  
Copyright 2026 Pr1nted  
Apache License 2.0

**TauPlot**  
BSD-3-Clause License

**Leaky integrate-and-fire model lineage**  
Based on the neuron model developed by Philip Shiu and Nico Spiller, as documented in the original Open Fly project. The applicable upstream MIT license and attribution are retained.

See `NOTICE`, `THIRD_PARTY.md`, and `THIRD_PARTY_LICENSES/` for the relevant legal notices and license texts.

## Licensing

This source extraction is released under the **Apache License, Version 2.0**.

See the repository's `LICENSE` file for the full license text.

The Apache 2.0 license applies to the included source code to the extent that the repository contributors have the right to license it.

Third-party components retain their original copyright notices and applicable licenses. Their inclusion does not transfer ownership or remove existing attribution requirements.

This license does not apply to proprietary QORVYX software, assets, datasets, or systems excluded from this repository.

No additional rights are granted over third-party connectome datasets.

## Development and Distribution

This repository is a one-time source extraction intended for transparency and review.

It is not synchronized with the proprietary QORVYX project.

No automatic mirroring, source synchronization, or proprietary code export workflow is configured.

The full QORVYX commercial game remains a separate product.

## Acknowledgements

Special thanks to **Pr1nted**, creator of Open Fly and Open Animal Stage, whose open-source implementations provided the foundation for the connectome runtime and animal-stage presentation adapted in this project.

The original projects, copyright notices, and license requirements are preserved and acknowledged.
