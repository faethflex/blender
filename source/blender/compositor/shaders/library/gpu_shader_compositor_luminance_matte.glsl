/* SPDX-FileCopyrightText: 2022-2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "gpu_shader_common_color_utils.glsl"

void node_composite_luminance_matte(vec4 color,
                                    float high,
                                    float low,
                                    const vec3 luminance_coefficients,
                                    out vec4 result,
                                    out float matte)
{
  float luminance = get_luminance(color.rgb, luminance_coefficients);
  float alpha = clamp((luminance - low) / (high - low), 0.0f, 1.0f);
  matte = min(alpha, color.a);
  result = color * matte;
}
