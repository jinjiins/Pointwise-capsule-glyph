# Pointwise-capsule-glyph
Pointwise Glyph generator for capsule/sphere-cone butterfly surface meshes and normal-extruded farfield blocks.

## User Inputs

The main configuration parameters are collected in the `User Input` section near the top of `capsule_generator.glf`.

### Geometry Parameters

| Variable     |  Default | Description                                                                   |
| ------------ | -------: | ----------------------------------------------------------------------------- |
| `Rb`         |    `3.0` | Base radius of the capsule body.                                              |
| `RnRb_ratio` |    `1.5` | Radius ratio used to compute the nose radius as `Rn = Rb / RnRb_ratio`.       |
| `Rn`         | computed | Nose radius. This value is automatically computed from `Rb` and `RnRb_ratio`. |
| `Rs`         |    `0.2` | Shoulder radius. Must satisfy `0 < Rs < Rb`.                                  |
| `thetac`     |   `70.0` | Cone/frustum angle in degrees. Must satisfy `0 < thetac < 90`.                |

### Domain Options

| Variable    | Default | Description                                                                                                                           |
| ----------- | ------: | ------------------------------------------------------------------------------------------------------------------------------------- |
| `IsAxi`     |     `0` | Domain type. `0` generates a full 360-degree domain. `1` generates a half 180-degree domain from `theta = -90 deg` to `+90 deg`.      |
| `IsExtrude` |     `1` | Mesh generation mode. `0` creates only the database and surface mesh. `1` performs structured normal extrusion from the surface mesh. |

For `IsAxi = 1`, the two azimuthal boundary planes are placed on the `y = 0` plane, and the extrusion boundary condition is set using `ConstantY`.

### Circumferential and Surface Mesh Controls

| Variable            | Default | Description                                                                                                                                                                                  |
| ------------------- | ------: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Nconnector`        |    `64` | Total circumferential cell count for the full 360-degree domain. This value must be a multiple of 8. For a half-domain case, the active circumferential cell count becomes `Nconnector / 2`. |
| `butterflyFraction` |   `0.6` | Fraction of the nose arc occupied by the butterfly topology. For example, `0.6` places the transition ring at 60% of the arc from the stagnation point to the nose-frustum junction.         |
| `NnoseAlignedCells` |    `10` | Axial cell count in the aligned nose region after the butterfly block. If set to `0`, the value is automatically estimated based on the local circumferential spacing.                       |
| `NfrustumCells`     |    `71` | Axial cell count along the frustum region. If set to `0`, the value is automatically estimated.                                                                                              |
| `NedgeCells`        |     `9` | Axial cell count along the shoulder/edge region. If set to `0`, the value is automatically estimated.                                                                                        |

The default input produces:

```text
Full 360-degree domain
Nconnector = 64
Active circumferential cells = 64
Axial cells = 10 + 71 + 9 = 90
```

For the full-domain case, the topology consists of 12 butterfly domains and 8 aligned downstream strip domains.

### Surface Smoothing Controls

| Variable                      | Default | Description                                                                                                                                                               |
| ----------------------------- | ------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `butterflyFloatingIterations` |    `15` | Number of elliptic solver iterations applied to the butterfly interior edges after assigning Floating boundary conditions. If set to `0`, butterfly smoothing is skipped. |
| `ellipticIterations`          |    `40` | Number of elliptic solver iterations applied to the downstream aligned strip domains. If set to `0`, downstream smoothing is skipped.                                     |

### Normal Extrusion Controls

These parameters are used only when `IsExtrude = 1`.

| Variable             |      Default | Description                                                                                                                                       |
| -------------------- | -----------: | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FirstLayerHeight`   |     `5.0e-6` | Initial wall-normal spacing for the first extrusion layer.                                                                                        |
| `GrowthPhaseCount`   |       `auto` | Number of extrusion growth phases. If set to `auto`, the script automatically detects the defined `GrowthRate(i)` and `GrowthIteration(i)` pairs. |
| `GrowthRate(i)`      | user-defined | Spacing growth factor for extrusion phase `i`.                                                                                                    |
| `GrowthIteration(i)` | user-defined | Number of extrusion layers generated during phase `i`.                                                                                            |

The default extrusion schedule is:

| Phase | Growth rate | Layers |
| ----: | ----------: | -----: |
|     1 |       `1.2` |   `30` |
|     2 |       `1.0` |   `80` |
|     3 |       `1.2` |   `30` |

Therefore, the default setting generates:

```text
Total extrusion layers = 30 + 80 + 30 = 140
Extrusion-direction points = 141
```

### Extrusion Direction and Smoothing

| Variable                     | Default | Description                                                                                                                                                                                |
| ---------------------------- | ------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `AutoOrientWallNormal`       |     `1` | Automatically orients each surface block so that extrusion proceeds in the outward wall-normal direction.                                                                                  |
| `ExtrudeFlip`                |     `0` | Global extrusion-direction switch. If `AutoOrientWallNormal = 1`, `ExtrudeFlip = 0` gives outward normal extrusion, while `ExtrudeFlip = 1` reverses all blocks for inward/debug marching. |
| `NormalKinseyBarthSmoothing` | `{3 3}` | Kinsey-Barth smoothing parameter for the structured normal extrusion. A scalar value is internally converted to `{value value}`.                                                           |
| `NormalVolumeSmoothing`      |   `0.3` | Volume smoothing parameter for normal extrusion.                                                                                                                                           |

### Boundary Constraints for Extrusion

| Variable                        |     Default | Description                                                                       |
| ------------------------------- | ----------: | --------------------------------------------------------------------------------- |
| `HalfDomainBoundaryConstraint`  | `ConstantY` | Boundary constraint applied to the symmetry planes when `IsAxi = 1`.              |
| `IsShoulderEndConstraint`       |         `1` | Enables a constraint on the aft shoulder-end ring during normal extrusion.        |
| `ShoulderEndBoundaryConstraint` | `ConstantX` | Keeps the aft shoulder-end ring on the constant `x = P4x` plane during extrusion. |

The shoulder-end constraint is useful because the aft ring should remain planar while the remaining surface domains are extruded in the wall-normal direction.

### Input Constraints

The script checks the following conditions before mesh generation:

```text
Rb > 0
RnRb_ratio > 0
Rn > 0
0 < Rs < Rb
0 < thetac < 90 deg
IsAxi = 0 or 1
IsExtrude = 0 or 1
Nconnector must be an integer multiple of 8 and at least 8
0 < butterflyFraction < 1
Axial cell counts must be non-negative integers
Elliptic solver iteration counts must be non-negative integers
```

When `IsExtrude = 1`, at least one valid growth phase must be defined using `GrowthRate(i)` and `GrowthIteration(i)`.
