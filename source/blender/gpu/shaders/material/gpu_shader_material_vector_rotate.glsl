/* SPDX-FileCopyrightText: 2020-2022 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "gpu_shader_math_matrix_lib.glsl"
#include "gpu_shader_math_rotation_lib.glsl"

vec3 rotate_around_axis(vec3 p, vec3 axis, float angle)
{
  float costheta = cos(angle);
  float sintheta = sin(angle);
  vec3 r;

  r.x = ((costheta + (1.0f - costheta) * axis.x * axis.x) * p.x) +
        (((1.0f - costheta) * axis.x * axis.y - axis.z * sintheta) * p.y) +
        (((1.0f - costheta) * axis.x * axis.z + axis.y * sintheta) * p.z);

  r.y = (((1.0f - costheta) * axis.x * axis.y + axis.z * sintheta) * p.x) +
        ((costheta + (1.0f - costheta) * axis.y * axis.y) * p.y) +
        (((1.0f - costheta) * axis.y * axis.z - axis.x * sintheta) * p.z);

  r.z = (((1.0f - costheta) * axis.x * axis.z - axis.y * sintheta) * p.x) +
        (((1.0f - costheta) * axis.y * axis.z + axis.x * sintheta) * p.y) +
        ((costheta + (1.0f - costheta) * axis.z * axis.z) * p.z);

  return r;
}

void node_vector_rotate_axis_angle(
    vec3 vector_in, vec3 center, vec3 axis, float angle, vec3 rotation, float invert, out vec3 vec)
{
  vec = (length(axis) != 0.0f) ?
            rotate_around_axis(vector_in - center, normalize(axis), angle * invert) + center :
            vector_in;
}

void node_vector_rotate_axis_x(
    vec3 vector_in, vec3 center, vec3 axis, float angle, vec3 rotation, float invert, out vec3 vec)
{
  vec = rotate_around_axis(vector_in - center, vec3(1.0f, 0.0f, 0.0f), angle * invert) + center;
}

void node_vector_rotate_axis_y(
    vec3 vector_in, vec3 center, vec3 axis, float angle, vec3 rotation, float invert, out vec3 vec)
{
  vec = rotate_around_axis(vector_in - center, vec3(0.0f, 1.0f, 0.0f), angle * invert) + center;
}

void node_vector_rotate_axis_z(
    vec3 vector_in, vec3 center, vec3 axis, float angle, vec3 rotation, float invert, out vec3 vec)
{
  vec = rotate_around_axis(vector_in - center, vec3(0.0f, 0.0f, 1.0f), angle * invert) + center;
}

void node_vector_rotate_euler_xyz(
    vec3 vector_in, vec3 center, vec3 axis, float angle, vec3 rotation, float invert, out vec3 vec)
{
  mat3 rmat = (invert < 0.0f) ? transpose(from_rotation(as_EulerXYZ(rotation))) :
                                from_rotation(as_EulerXYZ(rotation));
  vec = rmat * (vector_in - center) + center;
}
