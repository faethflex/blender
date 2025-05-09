/* SPDX-FileCopyrightText: 2019-2022 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

/**
 * Draw particles as shapes using primitive expansion.
 */

#include "infos/overlay_extra_info.hh"

VERTEX_SHADER_CREATE_INFO(overlay_particle_shape)

#include "draw_model_lib.glsl"
#include "draw_view_clipping_lib.glsl"
#include "draw_view_lib.glsl"
#include "gpu_shader_math_matrix_lib.glsl"
#include "select_lib.glsl"

vec3 rotate(vec3 vec, vec4 quat)
{
  /* The quaternion representation here stores the w component in the first index. */
  return vec + 2.0f * cross(quat.yzw, cross(quat.yzw, vec) + quat.x * vec);
}

/* Could be move to a shared library. */
vec2 circle_position(float angle)
{
  return vec2(cos(angle), sin(angle));
}

void main()
{
  select_id_set(drw_custom_id());

  int particle_id = gl_VertexID;
  int shape_vert_id = gl_VertexID;

  switch (shape_type) {
    case PART_SHAPE_AXIS:
    case PART_SHAPE_CROSS:
      shape_vert_id = gl_VertexID % 6;
      particle_id = gl_VertexID / 6;
      break;
    case PART_SHAPE_CIRCLE:
      shape_vert_id = gl_VertexID % (PARTICLE_SHAPE_CIRCLE_RESOLUTION * 2);
      particle_id = gl_VertexID / (PARTICLE_SHAPE_CIRCLE_RESOLUTION * 2);
      break;
  }

  ParticlePointData part = part_pos[particle_id];

  uint axis_id = uint(shape_vert_id) >> 1u;
  uint axis_vert = uint(shape_vert_id) & 1u;

#ifdef GPU_METAL
  /* Metal has a different provoking vertex convention. */
  axis_vert ^= 1u;
#endif

  vec3 shape_pos = vec3(0.0f);
  switch (shape_type) {
    case PART_SHAPE_AXIS:
      shape_pos = vec3(axis_id == 0, axis_id == 1, axis_id == 2) * 2.0f * float(axis_vert != 0u);
      break;
    case PART_SHAPE_CROSS:
      shape_pos = vec3(axis_id == 0, axis_id == 1, axis_id == 2) *
                  (axis_vert == 0u ? 1.0f : -1.0f);
      break;
    case PART_SHAPE_CIRCLE:
      shape_pos.xy = circle_position(M_TAU * float((shape_vert_id + 1) / 2) /
                                     float(PARTICLE_SHAPE_CIRCLE_RESOLUTION));
      break;
  }

  finalColor = vec4(1.0f);
  if (shape_type == PART_SHAPE_AXIS) {
    /* Works because of flat interpolation. */
    finalColor.rgb = shape_pos;
  }
  else {
    finalColor.rgb = part.value < 0.0f ? ucolor.rgb : texture(weightTex, part.value).rgb;
  }

  /* Draw-size packed in alpha. */
  shape_pos *= ucolor.a;

  vec3 world_pos = part.position;
  if (shape_type == PART_SHAPE_CIRCLE) {
    /* World sized, camera facing geometry. */
    world_pos += transform_direction(drw_view().viewinv, shape_pos);
  }
  else {
    world_pos += rotate(shape_pos, part.rotation);
  }
  gl_Position = drw_point_world_to_homogenous(world_pos);
  edgeStart = edgePos = ((gl_Position.xy / gl_Position.w) * 0.5f + 0.5f) * sizeViewport;

  view_clipping_distances(world_pos);
}
