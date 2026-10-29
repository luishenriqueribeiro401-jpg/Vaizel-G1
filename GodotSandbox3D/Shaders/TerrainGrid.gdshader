shader_type spatial;
render_mode specular_disabled;

// Uma única superfície: nenhuma segunda malha e nenhum z-fighting.
uniform vec4 ground_color : source_color = vec4(0.46, 0.48, 0.50, 1.0);
uniform vec4 grid_color : source_color = vec4(0.32, 0.35, 0.38, 1.0);
uniform float grid_spacing : hint_range(0.5, 4.0) = 1.0;
uniform float grid_line_width : hint_range(0.002, 0.10) = 0.018;

varying vec2 ground_world_xz;

void vertex() {
    ground_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    vec2 coords = ground_world_xz / grid_spacing;
    vec2 dist_to_line = abs(fract(coords + 0.5) - 0.5);
    vec2 pixel_width = max(fwidth(coords), vec2(0.0001));
    vec2 axis_lines = 1.0 - smoothstep(
        vec2(grid_line_width), vec2(grid_line_width) + pixel_width, dist_to_line
    );
    float grid = max(axis_lines.x, axis_lines.y);
    ALBEDO = mix(ground_color.rgb, grid_color.rgb, grid);
    ROUGHNESS = 1.0;
}
