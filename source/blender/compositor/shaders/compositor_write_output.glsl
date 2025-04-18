/* SPDX-FileCopyrightText: 2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "gpu_shader_compositor_texture_utilities.glsl"

void main()
{
  ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
  ivec2 output_texel = texel + lower_bound;
  if (any(greaterThan(output_texel, upper_bound))) {
    return;
  }

  vec4 input_color = texture_load(input_tx, texel);

#if defined(DIRECT_OUTPUT)
  vec4 output_color = input_color;
#elif defined(OPAQUE_OUTPUT)
  vec4 output_color = vec4(input_color.rgb, 1.0f);
#elif defined(ALPHA_OUTPUT)
  float alpha = texture_load(alpha_tx, texel).x;
  vec4 output_color = vec4(input_color.rgb, alpha);
#endif

  imageStore(output_img, texel + lower_bound, output_color);
}
