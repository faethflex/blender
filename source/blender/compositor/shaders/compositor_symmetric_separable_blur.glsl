/* SPDX-FileCopyrightText: 2022 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "gpu_shader_compositor_texture_utilities.glsl"

vec4 load_input(ivec2 texel)
{
  vec4 color;
  if (extend_bounds) {
    /* If bounds are extended, then we treat the input as padded by a radius amount of pixels. So
     * we load the input with an offset by the radius amount and fallback to a transparent color if
     * it is out of bounds. Notice that we subtract 1 because the weights texture have an extra
     * center weight, see the SymmetricSeparableBlurWeights for more information. */
    int blur_size = texture_size(weights_tx).x - 1;
    color = texture_load(input_tx, texel - ivec2(blur_size, 0), vec4(0.0f));
  }
  else {
    color = texture_load(input_tx, texel);
  }

  return color;
}

void main()
{
  ivec2 texel = ivec2(gl_GlobalInvocationID.xy);

  vec4 accumulated_color = vec4(0.0f);

  /* First, compute the contribution of the center pixel. */
  vec4 center_color = load_input(texel);
  accumulated_color += center_color * texture_load(weights_tx, ivec2(0)).x;

  /* Then, compute the contributions of the pixel to the right and left, noting that the
   * weights texture only stores the weights for the positive half, but since the filter is
   * symmetric, the same weight is used for the negative half and we add both of their
   * contributions. */
  for (int i = 1; i < texture_size(weights_tx).x; i++) {
    float weight = texture_load(weights_tx, ivec2(i, 0)).x;
    accumulated_color += load_input(texel + ivec2(i, 0)) * weight;
    accumulated_color += load_input(texel + ivec2(-i, 0)) * weight;
  }

  /* Write the color using the transposed texel. See the execute_separable_blur_horizontal_pass
   * method for more information on the rational behind this. */
  imageStore(output_img, texel.yx, accumulated_color);
}
