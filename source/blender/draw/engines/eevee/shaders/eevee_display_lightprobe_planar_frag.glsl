/* SPDX-FileCopyrightText: 2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "infos/eevee_lightprobe_sphere_info.hh"

FRAGMENT_SHADER_CREATE_INFO(eevee_display_lightprobe_planar)

#include "draw_view_lib.glsl"
#include "eevee_lightprobe_sphere_lib.glsl"

vec2 sampling_uv(vec2 screen_uv)
{
  /* Render is inverted in Y. */
  screen_uv.y = 1.0f - screen_uv.y;
  return screen_uv;
}

void main()
{
  vec2 uv = gl_FragCoord.xy / vec2(textureSize(planar_radiance_tx, 0).xy);
  float depth = texture(planar_depth_tx, vec3(sampling_uv(uv), probe_index)).r;
  if (depth == 1.0f) {
    vec3 ndc = drw_screen_to_ndc(vec3(uv, 0.0f));
    vec3 wP = drw_point_ndc_to_world(ndc);
    vec3 V = drw_world_incident_vector(wP);
    vec3 R = -reflect(V, probe_normal);

    SphereProbeUvArea world_atlas_coord = reinterpret_as_atlas_coord(world_coord_packed);
    out_color = lightprobe_spheres_sample(R, 0.0f, world_atlas_coord);
  }
  else {
    out_color = texture(planar_radiance_tx, vec3(sampling_uv(uv), probe_index));
  }
  out_color.a = 0.0f;
}
