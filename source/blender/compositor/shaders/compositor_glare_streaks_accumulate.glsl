/* SPDX-FileCopyrightText: 2022 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "gpu_shader_compositor_texture_utilities.glsl"

void main()
{
  ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
  vec4 attenuated_streak = texture_load(streak_tx, texel) * attenuation_factor;
  vec4 current_accumulated_streaks = imageLoad(accumulated_streaks_img, texel);
  vec4 combined_streaks = current_accumulated_streaks + attenuated_streak;
  imageStore(accumulated_streaks_img, texel, vec4(combined_streaks.rgb, 1.0f));
}
