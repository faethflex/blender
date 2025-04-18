/* SPDX-FileCopyrightText: 2022 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

/**
 * Setup pass: CoC and luma aware downsample to half resolution of the input scene color buffer.
 *
 * An addition to the downsample CoC, we output the maximum slight out of focus CoC to be
 * sure we don't miss a pixel.
 *
 * Input:
 *  Full-resolution color & depth buffer
 * Output:
 *  Half-resolution Color, signed CoC (out_coc.x), and max slight focus abs CoC (out_coc.y).
 */

#include "infos/eevee_depth_of_field_info.hh"

COMPUTE_SHADER_CREATE_INFO(eevee_depth_of_field_setup)

#include "draw_view_lib.glsl"
#include "eevee_colorspace_lib.glsl"
#include "eevee_depth_of_field_lib.glsl"
#include "gpu_shader_math_vector_lib.glsl"

void main()
{
  vec2 fullres_texel_size = 1.0f / vec2(textureSize(color_tx, 0).xy);
  /* Center uv around the 4 full-resolution pixels. */
  vec2 quad_center = vec2(gl_GlobalInvocationID.xy * 2 + 1) * fullres_texel_size;

  vec4 colors[4];
  vec4 cocs;
  for (int i = 0; i < 4; i++) {
    vec2 sample_uv = quad_center + quad_offsets[i] * fullres_texel_size;
    /* NOTE: We use samplers without filtering. */
    colors[i] = colorspace_safe_color(textureLod(color_tx, sample_uv, 0.0f));
    cocs[i] = dof_coc_from_depth(dof_buf, sample_uv, textureLod(depth_tx, sample_uv, 0.0f).r);
  }

  cocs = clamp(cocs, -dof_buf.coc_abs_max, dof_buf.coc_abs_max);

  vec4 weights = dof_bilateral_coc_weights(cocs);
  weights *= dof_bilateral_color_weights(colors);
  /* Normalize so that the sum is 1. */
  weights *= safe_rcp(reduce_add(weights));

  ivec2 out_texel = ivec2(gl_GlobalInvocationID.xy);
  vec4 out_color = weighted_sum_array(colors, weights);
  imageStore(out_color_img, out_texel, out_color);

  float out_coc = dot(cocs, weights);
  imageStore(out_coc_img, out_texel, vec4(out_coc));
}
