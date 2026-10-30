# Local Animal Stage — Godot source extraction

This is a deliberately stripped Godot source snapshot for private review. It keeps the independent animal-stage presentation and connectome visualization while omitting the proprietary game's simulation and engine integration. It is not a complete application and is not expected to run or build.

## Included

- A minimal Godot project shell and an observatory entry scene for the presentation scripts.
- The animal laboratory and station presentation scripts.
- The connectome LIF runtime and chart presentation helper.
- TauPlot, included unchanged with its BSD-3-Clause license.
- Eight animal preview GLB models copied byte-for-byte from Open Animal Stage commit `4cb2c8610c801febf355279e58a920897ce99e3e`; the associated Apache-2.0 license and attribution are retained.

## Intentionally excluded

The game simulation/economy, AI agents and behavior trees, networking, DRM, platform services, server code, product UI, build outputs, signing keys, local brain datasets, connectome packages, brain rosters, and proprietary artwork/audio/fonts are not included. The retained scripts have had their direct economy adapter and product-specific labels removed. Consequently, the project is an incomplete source excerpt, not a runnable substitute.

## Licensing

Third-party notices and license texts for the included models, TauPlot, and the LIF model lineage are in [`THIRD_PARTY.md`](THIRD_PARTY.md) and [`THIRD_PARTY_LICENSES/`](THIRD_PARTY_LICENSES/). No project-wide license is granted for the extracted Godot scripts in this review snapshot; third-party licenses apply only to their identified components. Choose and add a project license before making this repository public.

This is a one-time review snapshot. No mirroring or synchronization workflow is configured.
