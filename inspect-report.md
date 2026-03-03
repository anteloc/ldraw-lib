
 OVERVIEW
 ────────────────────────────────────────────
| key                | value                                          |
| ---                | ---                                            |
| version            | 2.0                                            |
| generator          | glTF-Transform v4.3.0                          |
| extensionsUsed     | EXT_meshopt_compression, KHR_mesh_quantization |
| extensionsRequired | EXT_meshopt_compression, KHR_mesh_quantization |



 SCENES
 ────────────────────────────────────────────
| #   | name     | rootName | bboxMin                    | bboxMax                   | renderVertexCount¹ | uploadVertexCount | uploadNaiveVertexCount |
| --- | ---      | ---      | ---                        | ---                       | ---                | ---               | ---                    |
| 0   | AuxScene |          | -0.12561, -0.01046, -0.324 | 0.12561, 0.11581, 0.25743 | 6,614,023          | 2,673,365         | 2,673,365              |

¹ Expected number of vertices processed by the vertex shader for one render
  pass, without considering the vertex cache.

² Expected number of vertices uploaded to GPU, assuming each Accessor
  is uploaded only once. Actual number uploaded may be higher, 
  dependent on the implementation and vertex buffer layout.

³ Expected number of vertices uploaded to GPU, assuming each Primitive
  is uploaded once, duplicating vertex attributes shared among Primitives.



 MESHES
 ────────────────────────────────────────────
| #   | name | mode      | meshPrimitives | glPrimitives | vertices  | indices | attributes                                             | instances | size¹     |
| --- | ---  | ---       | ---            | ---          | ---       | ---     | ---                                                    | ---       | ---       |
| 0   |      | TRIANGLES | 1              | 1,436,888    | 1,668,182 | u32     | NORMAL:i8_norm, POSITION:i16_norm, TEXCOORD_0:u16_norm | 1         | 38.93 MB  |
| 1   |      | LINES     | 1              | 821,387      | 829,509   | u32     | POSITION:i16_norm, TEXCOORD_0:u16_norm                 | 1         | 14.87 MB  |
| 2   |      | TRIANGLES | 1              | 196,230      | 143,901   | u32     | NORMAL:i8_norm, POSITION:i16_norm, TEXCOORD_0:u16_norm | 1         | 4.23 MB   |
| 3   |      | TRIANGLES | 1              | 23,965       | 31,773    | u16     | NORMAL:i8_norm, POSITION:i16_norm, TEXCOORD_0:u16_norm | 1         | 556.84 KB |

⁴ size estimates GPU memory required by a mesh, in isolation. If accessors are
  shared by other mesh primitives, but the meshes themselves are not reused, then
  the sum of all mesh sizes will overestimate the asset's total size. See "dedup".



 MATERIALS
 ────────────────────────────────────────────
| #   | name               | instances | textures         | alphaMode | doubleSided |
| --- | ---                | ---       | ---              | ---       | ---         |
| 0   | PaletteMaterial001 | 1         | baseColorTexture | OPAQUE    |             |
| 1   | PaletteMaterial002 | 1         | baseColorTexture | OPAQUE    |             |
| 2   | PaletteMaterial003 | 1         | baseColorTexture | OPAQUE    |             |
| 3   | PaletteMaterial004 | 1         | baseColorTexture | OPAQUE    |             |



 TEXTURES
 ────────────────────────────────────────────
| #   | name             | uri | slots            | instances | mimeType  | compression | resolution | size      | gpuSize⁵ |
| --- | ---              | --- | ---              | ---       | ---       | ---         | ---        | ---       | ---      |
| 0   | PaletteBaseColor |     | baseColorTexture | 4         | image/png |             | 64x4       | 171 Bytes | 1.4 KB   |

⁵ gpuSize estimates minimum VRAM memory allocation. Older devices may require
  additional memory for GPU compression formats.



 ANIMATIONS
 ────────────────────────────────────────────
No animations found.

