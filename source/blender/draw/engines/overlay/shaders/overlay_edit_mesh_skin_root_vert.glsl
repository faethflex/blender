/* SPDX-FileCopyrightText: 2019-2022 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "infos/overlay_edit_mode_info.hh"

VERTEX_SHADER_CREATE_INFO(overlay_edit_mesh_skin_root)
#ifdef GLSL_CPP_STUBS
#  define VERTEX_PULL
#endif

#include "draw_model_lib.glsl"
#include "draw_view_clipping_lib.glsl"
#include "draw_view_lib.glsl"
#include "gpu_shader_math_base_lib.glsl"

void main()
{
  mat3 imat = to_float3x3(drw_modelinv());
  vec3 right = normalize(imat * drw_view().viewinv[0].xyz);
  vec3 up = normalize(imat * drw_view().viewinv[1].xyz);
#ifdef VERTEX_PULL
  int instance_id = gl_VertexID / 64;
  int vert_id = gl_VertexID % 64;
  /* TODO(fclem): Use correct vertex format. For now we read the format manually. */
  float circle_size = size[instance_id * 4];
  vec3 lP = vec3(size[instance_id * 4 + 1], size[instance_id * 4 + 2], size[instance_id * 4 + 3]);

  float theta = M_TAU * (float(vert_id) / 63.0f);
  vec3 circle_P = vec3(cos(theta), 0.0f, sin(theta));
  finalColor = colorSkinRoot;
#else
  vec3 lP = local_pos;
  float circle_size = size;
  vec3 circle_P = pos;
  /* Manual stipple: one segment out of 2 is transparent. */
  finalColor = ((gl_VertexID & 1) == 0) ? colorSkinRoot : vec4(0.0f);
#endif
  vec3 screen_pos = (right * circle_P.x + up * circle_P.z) * circle_size;
  vec4 pos_4d = drw_modelmat() * vec4(lP + screen_pos, 1.0f);
  gl_Position = drw_view().winmat * (drw_view().viewmat * pos_4d);

  view_clipping_distances(pos_4d.xyz);
}
