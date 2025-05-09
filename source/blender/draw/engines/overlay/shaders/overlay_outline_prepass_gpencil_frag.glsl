/* SPDX-FileCopyrightText: 2018-2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "infos/overlay_outline_info.hh"

FRAGMENT_SHADER_CREATE_INFO(overlay_outline_prepass_gpencil)

#include "draw_grease_pencil_lib.glsl"

vec3 ray_plane_intersection(vec3 ray_ori, vec3 ray_dir, vec4 plane)
{
  float d = dot(plane.xyz, ray_dir);
  vec3 plane_co = plane.xyz * (-plane.w / dot(plane.xyz, plane.xyz));
  vec3 h = ray_ori - plane_co;
  float lambda = -dot(plane.xyz, h) / ((abs(d) < 1e-8f) ? 1e-8f : d);
  return ray_ori + ray_dir * lambda;
}

void main()
{
  if (gpencil_stroke_round_cap_mask(gp_interp_flat.sspos.xy,
                                    gp_interp_flat.sspos.zw,
                                    gp_interp_flat.aspect,
                                    gp_interp_noperspective.thickness.x,
                                    gp_interp_noperspective.hardness) < 0.001f)
  {
    discard;
    return;
  }

  if (!gpStrokeOrder3d) {
    /* Stroke order 2D. Project to gpDepthPlane. */
    bool is_persp = drw_view().winmat[3][3] == 0.0f;
    vec2 uvs = vec2(gl_FragCoord.xy) * sizeViewportInv;
    vec3 pos_ndc = vec3(uvs, gl_FragCoord.z) * 2.0f - 1.0f;
    vec4 pos_world = drw_view().viewinv * (drw_view().wininv * vec4(pos_ndc, 1.0f));
    vec3 pos = pos_world.xyz / pos_world.w;

    vec3 ray_ori = pos;
    vec3 ray_dir = (is_persp) ? (drw_view().viewinv[3].xyz - pos) : drw_view().viewinv[2].xyz;
    vec3 isect = ray_plane_intersection(ray_ori, ray_dir, gpDepthPlane);
    vec4 ndc = drw_point_world_to_homogenous(isect);
    gl_FragDepth = (ndc.z / ndc.w) * 0.5f + 0.5f;
  }
  else {
    gl_FragDepth = gl_FragCoord.z;
  }

  out_object_id = interp.ob_id;
}
