/* SPDX-FileCopyrightText: 2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

/**
 * Virtual shadow-mapping: Usage tagging
 *
 * Shadow pages are only allocated if they are visible.
 * This pass scans all volume froxels and tags tiles needed for shadowing.
 */

#include "infos/eevee_shadow_info.hh"

COMPUTE_SHADER_CREATE_INFO(eevee_shadow_tag_usage_volume)

#include "eevee_sampling_lib.glsl"
#include "eevee_shadow_tag_usage_lib.glsl"
#include "eevee_volume_lib.glsl"

void main()
{
  ivec3 froxel = ivec3(gl_GlobalInvocationID);

  if (any(greaterThanEqual(froxel, uniform_buf.volumes.tex_size))) {
    return;
  }

  vec3 extinction = imageLoadFast(in_extinction_img, froxel).rgb;
  vec3 scattering = imageLoadFast(in_scattering_img, froxel).rgb;

  if (is_zero(extinction) || is_zero(scattering)) {
    return;
  }

  float offset = sampling_rng_1D_get(SAMPLING_VOLUME_W);
  float jitter = interlieved_gradient_noise(vec2(froxel.xy), 0.0f, offset);

  vec3 uvw = (vec3(froxel) + vec3(0.5f, 0.5f, jitter)) * uniform_buf.volumes.inv_tex_size;
  vec3 ss_P = volume_resolve_to_screen(uvw);
  vec3 vP = drw_point_screen_to_view(vec3(ss_P.xy, ss_P.z));
  vec3 P = drw_point_view_to_world(vP);

  float depth = texelFetch(hiz_tx, froxel.xy, uniform_buf.volumes.tile_size_lod).r;
  if (depth < ss_P.z) {
    return;
  }

  vec2 pixel = ((vec2(froxel.xy) + 0.5f) * uniform_buf.volumes.inv_tex_size.xy) *
               uniform_buf.volumes.main_view_extent;

  int bias = uniform_buf.volumes.tile_size_lod;
  shadow_tag_usage(vP, P, drw_world_incident_vector(P), 0.01f, pixel, bias);
}
