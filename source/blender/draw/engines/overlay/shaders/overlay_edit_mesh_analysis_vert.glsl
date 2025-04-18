/* SPDX-FileCopyrightText: 2016-2022 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "infos/overlay_edit_mode_info.hh"

VERTEX_SHADER_CREATE_INFO(overlay_edit_mesh_analysis)

#include "draw_model_lib.glsl"
#include "draw_view_clipping_lib.glsl"
#include "draw_view_lib.glsl"

vec3 weight_to_rgb(float t)
{
  if (t < 0.0f) {
    /* Minimum color, gray */
    return vec3(0.25f, 0.25f, 0.25f);
  }
  else if (t > 1.0f) {
    /* Error color. */
    return vec3(1.0f, 0.0f, 1.0f);
  }
  else {
    return texture(weightTex, t).rgb;
  }
}

void main()
{
  vec3 world_pos = drw_point_object_to_world(pos);
  gl_Position = drw_point_world_to_homogenous(world_pos);
  weightColor = vec4(weight_to_rgb(weight), 1.0f);

  view_clipping_distances(world_pos);
}
