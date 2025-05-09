/* SPDX-FileCopyrightText: 2016-2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "infos/overlay_extra_info.hh"

FRAGMENT_SHADER_CREATE_INFO(overlay_extra_grid_base)

#include "select_lib.glsl"

void main()
{
  vec2 centered = gl_PointCoord - vec2(0.5f);
  float dist_squared = dot(centered, centered);
  const float rad_squared = 0.25f;

  /* Round point with jagged edges. */
  if (dist_squared > rad_squared) {
    discard;
    return;
  }

#if defined(VERT)
  fragColor = finalColor;

  float midStroke = 0.5f * rad_squared;
  if (vertexCrease > 0.0f && dist_squared > midStroke) {
    fragColor.rgb = mix(finalColor.rgb, colorEdgeCrease.rgb, vertexCrease);
  }
#else
  fragColor = finalColor;
#endif

#ifdef LINE_OUTPUT
  lineOutput = vec4(0.0f);
#endif
  select_id_output(select_id);
}
