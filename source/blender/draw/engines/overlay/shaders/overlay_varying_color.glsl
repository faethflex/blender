/* SPDX-FileCopyrightText: 2022 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "infos/overlay_volume_info.hh"

VERTEX_SHADER_CREATE_INFO(overlay_volume_velocity_mac)

#include "select_lib.glsl"

void main()
{
  fragColor = finalColor;
#ifdef LINE_OUTPUT
  lineOutput = vec4(0.0f);
#endif
  select_id_output(select_id);
}
