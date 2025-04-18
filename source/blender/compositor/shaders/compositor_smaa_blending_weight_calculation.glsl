/* SPDX-FileCopyrightText: 2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "gpu_shader_compositor_texture_utilities.glsl"
#include "gpu_shader_smaa_lib.glsl"

void main()
{
  ivec2 texel = ivec2(gl_GlobalInvocationID.xy);

  /* Add 0.5 to evaluate the input sampler at the center of the pixel and divide by the image size
   * to get the coordinates into the sampler's expected [0, 1] range. */
  vec2 coordinates = (vec2(texel) + vec2(0.5f)) / vec2(texture_size(edges_tx));

  float4 offset[3];
  vec2 pixel_coordinates;
  SMAABlendingWeightCalculationVS(coordinates, pixel_coordinates, offset);

  vec4 weights = SMAABlendingWeightCalculationPS(
      coordinates, pixel_coordinates, offset, edges_tx, area_tx, search_tx, vec4(0.0f));
  imageStore(weights_img, texel, weights);
}
