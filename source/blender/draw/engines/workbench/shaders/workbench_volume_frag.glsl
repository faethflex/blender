/* SPDX-FileCopyrightText: 2018-2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "infos/workbench_volume_info.hh"

FRAGMENT_SHADER_CREATE_INFO(workbench_volume)
FRAGMENT_SHADER_CREATE_INFO(workbench_volume_slice)
FRAGMENT_SHADER_CREATE_INFO(workbench_volume_coba)
FRAGMENT_SHADER_CREATE_INFO(workbench_volume_cubic)
FRAGMENT_SHADER_CREATE_INFO(workbench_volume_smoke)

#include "draw_model_lib.glsl"
#include "draw_object_infos_lib.glsl"
#include "draw_view_lib.glsl"
#include "gpu_shader_math_vector_lib.glsl"
#include "workbench_common_lib.glsl"

float phase_function_isotropic()
{
  return 1.0f / (4.0f * M_PI);
}

float line_unit_box_intersect_dist(vec3 lineorigin, vec3 linedirection)
{
  /* https://seblagarde.wordpress.com/2012/09/29/image-based-lighting-approaches-and-parallax-corrected-cubemap/
   */
  vec3 firstplane = (vec3(1.0f) - lineorigin) * safe_rcp(linedirection);
  vec3 secondplane = (vec3(-1.0f) - lineorigin) * safe_rcp(linedirection);
  vec3 furthestplane = min(firstplane, secondplane);
  return reduce_max(furthestplane);
}

#define sample_trilinear(ima, co) texture(ima, co)

vec4 sample_tricubic(sampler3D ima, vec3 co)
{
  vec3 tex_size = vec3(textureSize(ima, 0).xyz);

  co *= tex_size;
  /* texel center */
  vec3 tc = floor(co - 0.5f) + 0.5f;
  vec3 f = co - tc;
  vec3 f2 = f * f;
  vec3 f3 = f2 * f;
  /* Bspline coefficients (optimized). */
  vec3 w3 = f3 / 6.0f;
  vec3 w0 = -w3 + f2 * 0.5f - f * 0.5f + 1.0f / 6.0f;
  vec3 w1 = f3 * 0.5f - f2 + 2.0f / 3.0f;
  vec3 w2 = 1.0f - w0 - w1 - w3;

  vec3 s0 = w0 + w1;
  vec3 s1 = w2 + w3;

  vec3 f0 = w1 / (w0 + w1);
  vec3 f1 = w3 / (w2 + w3);

  vec2 final_z;
  vec4 final_co;
  final_co.xy = tc.xy - 1.0f + f0.xy;
  final_co.zw = tc.xy + 1.0f + f1.xy;
  final_z = tc.zz + vec2(-1.0f, 1.0f) + vec2(f0.z, f1.z);

  final_co /= tex_size.xyxy;
  final_z /= tex_size.zz;

  vec4 color;
  color = texture(ima, vec3(final_co.xy, final_z.x)) * s0.x * s0.y * s0.z;
  color += texture(ima, vec3(final_co.zy, final_z.x)) * s1.x * s0.y * s0.z;
  color += texture(ima, vec3(final_co.xw, final_z.x)) * s0.x * s1.y * s0.z;
  color += texture(ima, vec3(final_co.zw, final_z.x)) * s1.x * s1.y * s0.z;

  color += texture(ima, vec3(final_co.xy, final_z.y)) * s0.x * s0.y * s1.z;
  color += texture(ima, vec3(final_co.zy, final_z.y)) * s1.x * s0.y * s1.z;
  color += texture(ima, vec3(final_co.xw, final_z.y)) * s0.x * s1.y * s1.z;
  color += texture(ima, vec3(final_co.zw, final_z.y)) * s1.x * s1.y * s1.z;

  return color;
}

/* Nearest-neighbor interpolation */
vec4 sample_closest(sampler3D ima, vec3 co)
{
  /* Unnormalize coordinates */
  ivec3 cell_co = ivec3(co * vec3(textureSize(ima, 0).xyz));

  return texelFetch(ima, cell_co, 0);
}

vec4 flag_to_color(uint flag)
{
  /* Color mapping for flags */
  vec4 color = vec4(0.0f, 0.0f, 0.0f, 0.06f);
  /* Cell types: 1 is Fluid, 2 is Obstacle, 4 is Empty, 8 is Inflow, 16 is Outflow */
  if (bool(flag & uint(1))) {
    color.rgb += vec3(0.0f, 0.0f, 0.75f); /* blue */
  }
  if (bool(flag & uint(2))) {
    color.rgb += vec3(0.2f, 0.2f, 0.2f); /* dark gray */
  }
  if (bool(flag & uint(4))) {
    color.rgb += vec3(0.25f, 0.0f, 0.2f); /* dark purple */
  }
  if (bool(flag & uint(8))) {
    color.rgb += vec3(0.0f, 0.5f, 0.0f); /* dark green */
  }
  if (bool(flag & uint(16))) {
    color.rgb += vec3(0.9f, 0.3f, 0.0f); /* orange */
  }
  if (is_zero(color.rgb)) {
    color.rgb += vec3(0.5f, 0.0f, 0.0f); /* medium red */
  }
  return color;
}

#ifdef USE_TRICUBIC
#  define sample_volume_texture sample_tricubic
#elif defined(USE_TRILINEAR)
#  define sample_volume_texture sample_trilinear
#elif defined(USE_CLOSEST)
#  define sample_volume_texture sample_closest
#endif

void volume_properties(vec3 ls_pos, out vec3 scattering, out float extinction)
{
  vec3 co = ls_pos * 0.5f + 0.5f;
#ifdef USE_COBA
  vec4 tval;
  if (showPhi) {
    /* Color mapping for level-set representation */
    float val = sample_volume_texture(densityTexture, co).r * gridScale;

    val = max(min(val * 0.2f, 1.0f), -1.0f);

    if (val >= 0.0f) {
      tval = vec4(val, 0.0f, 0.5f, 0.06f);
    }
    else {
      tval = vec4(0.5f, 1.0f + val, 0.0f, 0.06f);
    }
  }
  else if (showFlags) {
    /* Color mapping for flags */
    uint flag = texture(flagTexture, co).r;
    tval = flag_to_color(flag);
  }
  else if (showPressure) {
    /* Color mapping for pressure */
    float val = sample_volume_texture(densityTexture, co).r * gridScale;

    if (val > 0) {
      tval = vec4(val, val, val, 0.06f);
    }
    else {
      tval = vec4(-val, 0.0f, 0.0f, 0.06f);
    }
  }
  else {
    float val = sample_volume_texture(densityTexture, co).r * gridScale;
    tval = texture(transferTexture, val);
  }
  tval *= densityScale;
  tval.rgb = pow(tval.rgb, vec3(2.2f));
  scattering = tval.rgb * 1500.0f;
  extinction = max(1e-4f, tval.a * 50.0f);
#else
#  ifdef VOLUME_SMOKE
  float flame = sample_volume_texture(flameTexture, co).r;
  vec4 emission = texture(flameColorTexture, flame);
#  endif
  vec3 density = sample_volume_texture(densityTexture, co).rgb;
  float shadows = sample_volume_texture(shadowTexture, co).r;

  scattering = density * densityScale;
  extinction = max(1e-4f, dot(scattering, vec3(0.33333f)));
  scattering *= activeColor;

  /* Scale shadows in log space and clamp them to avoid completely black shadows. */
  scattering *= exp(clamp(log(shadows) * densityScale * 0.1f, -2.5f, 0.0f)) * M_PI;

#  ifdef VOLUME_SMOKE
  /* 800 is arbitrary and here to mimic old viewport. TODO: make it a parameter. */
  scattering += emission.rgb * emission.a * 800.0f;
#  endif
#endif
}

void eval_volume_step(inout vec3 Lscat, float extinction, float step_len, out float Tr)
{
  Lscat *= phase_function_isotropic();
  /* Evaluate Scattering */
  Tr = exp(-extinction * step_len);
  /* integrate along the current step segment */
  Lscat = (Lscat - Lscat * Tr) / extinction;
}

#define P(x) ((x + 0.5f) * (1.0f / 16.0f))

vec4 volume_integration(vec3 ray_ori, vec3 ray_dir, float ray_inc, float ray_max, float step_len)
{
  /* NOTE: Constant array declared inside function scope to reduce shader core thread memory
   * pressure on Apple Silicon. */
  const vec4 dither_mat[4] = float4_array(vec4(P(0.0f), P(8.0f), P(2.0f), P(10.0f)),
                                          vec4(P(12.0f), P(4.0f), P(14.0f), P(6.0f)),
                                          vec4(P(3.0f), P(11.0f), P(1.0f), P(9.0f)),
                                          vec4(P(15.0f), P(7.0f), P(13.0f), P(5.0f)));
  /* Start with full transmittance and no scattered light. */
  vec3 final_scattering = vec3(0.0f);
  float final_transmittance = 1.0f;

  ivec2 tx = ivec2(gl_FragCoord.xy) % 4;
  float noise = fract(dither_mat[tx.x][tx.y] + noiseOfs);

  float ray_len = noise * ray_inc;
  for (int i = 0; i < samplesLen && ray_len < ray_max; i++, ray_len += ray_inc) {
    vec3 ls_pos = ray_ori + ray_dir * ray_len;

    vec3 Lscat;
    float s_extinction, Tr;
    volume_properties(ls_pos, Lscat, s_extinction);
    eval_volume_step(Lscat, s_extinction, step_len, Tr);
    /* accumulate and also take into account the transmittance from previous steps */
    final_scattering += final_transmittance * Lscat;
    final_transmittance *= Tr;

    if (final_transmittance <= 0.01f) {
      /* Early out */
      final_transmittance = 0.0f;
      break;
    }
  }

  return vec4(final_scattering, final_transmittance);
}

void main()
{
  uint stencil = texelFetch(stencil_tx, ivec2(gl_FragCoord.xy), 0).r;
  const uint in_front_stencil_bits = 1u << 1;
  if (do_depth_test && (stencil & in_front_stencil_bits) != 0) {
    /* Don't draw on top of "in front" objects. */
    discard;
    return;
  }

#ifdef VOLUME_SLICE
  /* Manual depth test. TODO: remove. */
  float depth = texelFetch(depthBuffer, ivec2(gl_FragCoord.xy), 0).r;
  if (do_depth_test && gl_FragCoord.z >= depth) {
    /* NOTE: In the Metal API, prior to Metal 2.3, Discard is not an explicit return and can
     * produce undefined behavior. This is especially prominent with derivatives if control-flow
     * divergence is present.
     *
     * Adding a return call eliminates undefined behavior and a later out-of-bounds read causing
     * a crash on AMD platforms.
     * This behavior can also affect OpenGL on certain devices. */
    discard;
    return;
  }

  vec3 Lscat;
  float s_extinction, Tr;
  volume_properties(localPos, Lscat, s_extinction);
  eval_volume_step(Lscat, s_extinction, stepLength, Tr);

  fragColor = vec4(Lscat, Tr);
#else
  vec2 screen_uv = gl_FragCoord.xy / vec2(textureSize(depthBuffer, 0).xy);
  bool is_persp = drw_view().winmat[3][3] == 0.0f;

  vec3 volume_center = drw_modelmat()[3].xyz;

  float depth = do_depth_test ? texelFetch(depthBuffer, ivec2(gl_FragCoord.xy), 0).r : 1.0f;
  float depth_end = min(depth, gl_FragCoord.z);
  vec3 vs_ray_end = drw_point_screen_to_view(vec3(screen_uv, depth_end));
  vec3 vs_ray_ori = drw_point_screen_to_view(vec3(screen_uv, 0.0f));
  vec3 vs_ray_dir = (is_persp) ? (vs_ray_end - vs_ray_ori) : vec3(0.0f, 0.0f, -1.0f);
  vs_ray_dir /= abs(vs_ray_dir.z);

  vec3 ls_ray_dir = drw_point_view_to_object(vs_ray_ori + vs_ray_dir);
  vec3 ls_ray_ori = drw_point_view_to_object(vs_ray_ori);
  vec3 ls_ray_end = drw_point_view_to_object(vs_ray_end);

#  ifdef VOLUME_SMOKE
  ls_ray_dir = (drw_object_orco(ls_ray_dir)) * 2.0f - 1.0f;
  ls_ray_ori = (drw_object_orco(ls_ray_ori)) * 2.0f - 1.0f;
  ls_ray_end = (drw_object_orco(ls_ray_end)) * 2.0f - 1.0f;
#  else
  ls_ray_dir = (volumeObjectToTexture * vec4(ls_ray_dir, 1.0f)).xyz * 2.0f - 1.0f;
  ls_ray_ori = (volumeObjectToTexture * vec4(ls_ray_ori, 1.0f)).xyz * 2.0f - 1.0f;
  ls_ray_end = (volumeObjectToTexture * vec4(ls_ray_end, 1.0f)).xyz * 2.0f - 1.0f;
#  endif

  ls_ray_dir -= ls_ray_ori;

  /* TODO: Align rays to volume center so that it mimics old behavior of slicing the volume. */

  float dist = line_unit_box_intersect_dist(ls_ray_ori, ls_ray_dir);
  if (dist > 0.0f) {
    ls_ray_ori = ls_ray_dir * dist + ls_ray_ori;
  }

  vec3 ls_vol_isect = ls_ray_end - ls_ray_ori;
  if (dot(ls_ray_dir, ls_vol_isect) < 0.0f) {
    /* Start is further away than the end.
     * That means no volume is intersected. */
    discard;
    return;
  }

  fragColor = volume_integration(ls_ray_ori,
                                 ls_ray_dir,
                                 stepLength,
                                 length(ls_vol_isect) / length(ls_ray_dir),
                                 length(vs_ray_dir) * stepLength);
#endif

  /* Convert transmittance to alpha so we can use pre-multiply blending. */
  fragColor.a = 1.0f - fragColor.a;
}
