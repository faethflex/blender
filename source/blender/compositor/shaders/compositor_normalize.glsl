/* SPDX-FileCopyrightText: 2022 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "gpu_shader_compositor_texture_utilities.glsl"

void main()
{
  ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
  float value = texture_load(input_tx, texel).x;
  float normalized_value = (value - minimum) * scale;
  float clamped_value = clamp(normalized_value, 0.0f, 1.0f);
  imageStore(output_img, texel, vec4(clamped_value));
}
