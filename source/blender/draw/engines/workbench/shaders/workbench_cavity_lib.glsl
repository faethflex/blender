/* SPDX-FileCopyrightText: 2017-2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#pragma once
#include "infos/workbench_composite_info.hh"

#include "draw_view_lib.glsl"
#include "workbench_common_lib.glsl"

SHADER_LIBRARY_CREATE_INFO(draw_view)
SHADER_LIBRARY_CREATE_INFO(workbench_composite)
SHADER_LIBRARY_CREATE_INFO(workbench_resolve_cavity)

/*  From The Alchemy screen-space ambient obscurance algorithm
 * http://graphics.cs.williams.edu/papers/AlchemyHPG11/VV11AlchemyAO.pdf */

#ifdef WORKBENCH_CAVITY
#  define USE_CAVITY
#  define cavityJitter jitter_tx
#  define samples_coords cavity_samples
#endif

#ifdef USE_CAVITY

void cavity_compute(vec2 screenco,
                    depth2D depthBuffer,
                    sampler2D normalBuffer,
                    out float cavities,
                    out float edges)
{
  cavities = edges = 0.0f;

  float depth = texture(depthBuffer, screenco).x;

  /* Early out if background and in front. */
  if (depth == 1.0f || depth == 0.0f) {
    return;
  }

  vec3 position = drw_point_screen_to_view(vec3(screenco, depth));
  vec3 normal = workbench_normal_decode(texture(normalBuffer, screenco));

  vec2 jitter_co = (screenco * world_data.viewport_size.xy) * world_data.cavity_jitter_scale;
  vec3 noise = texture(cavityJitter, jitter_co).rgb;

  /* find the offset in screen space by multiplying a point
   * in camera space at the depth of the point by the projection matrix. */
  vec2 offset;
  float homcoord = drw_view().winmat[2][3] * position.z + drw_view().winmat[3][3];
  offset.x = drw_view().winmat[0][0] * world_data.cavity_distance / homcoord;
  offset.y = drw_view().winmat[1][1] * world_data.cavity_distance / homcoord;
  /* convert from -1...1 range to 0..1 for easy use with texture coordinates */
  offset *= 0.5f;

  /* NOTE: Putting noise usage here to put some ALU after texture fetch. */
  vec2 rotX = noise.rg;
  vec2 rotY = vec2(-rotX.y, rotX.x);

  int sample_start = world_data.cavity_sample_start;
  int sample_end = world_data.cavity_sample_end;
  for (int i = sample_start; i < sample_end && i < 512; i++) {
    /* sample_coord.xy is sample direction (normalized).
     * sample_coord.z is sample distance from disk center. */
    vec3 sample_coord = samples_coords[i].xyz;
    /* Rotate with random direction to get jittered result. */
    vec2 dir_jittered = vec2(dot(sample_coord.xy, rotX), dot(sample_coord.xy, rotY));
    dir_jittered.xy *= sample_coord.z + noise.b;

    vec2 uvcoords = screenco + dir_jittered * offset;
    /* Out of screen case. */
    if (any(greaterThan(abs(uvcoords - 0.5f), vec2(0.5f)))) {
      continue;
    }
    /* Sample depth. */
    float s_depth = texture(depthBuffer, uvcoords).r;
    /* Handle Background case */
    bool is_background = (s_depth == 1.0f);
    /* This trick provide good edge effect even if no neighbor is found. */
    s_depth = (is_background) ? depth : s_depth;
    vec3 s_pos = drw_point_screen_to_view(vec3(uvcoords, s_depth));

    if (is_background) {
      s_pos.z -= world_data.cavity_distance;
    }

    vec3 dir = s_pos - position;
    float len = length(dir);
    float f_cavities = dot(dir, normal);
    float f_edge = -f_cavities;
    float f_bias = 0.05f * len + 0.0001f;

    float attenuation = 1.0f / (len * (1.0f + len * len * world_data.cavity_attenuation));

    /* use minor bias here to avoid self shadowing */
    if (f_cavities > -f_bias) {
      cavities += f_cavities * attenuation;
    }

    if (f_edge > f_bias) {
      edges += f_edge * attenuation;
    }
  }
  cavities *= world_data.cavity_sample_count_inv;
  edges *= world_data.cavity_sample_count_inv;

  /* don't let cavity wash out the surface appearance */
  cavities = clamp(cavities * world_data.cavity_valley_factor, 0.0f, 1.0f);
  edges = edges * world_data.cavity_ridge_factor;
}

#endif /* USE_CAVITY */
