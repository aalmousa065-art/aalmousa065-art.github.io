shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform sampler2D surface_map : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_scale = 0.5;
uniform float surface_roughness = 0.9;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 face = abs(world_normal);
	vec2 uv = world_position.xy;
	if (face.x > face.y && face.x > face.z) uv = world_position.zy;
	if (face.y > face.x && face.y > face.z) uv = world_position.xz;
	vec3 detail = texture(surface_map, uv * tile_scale).rgb;
	ALBEDO = base_color.rgb * detail;
	ROUGHNESS = surface_roughness;
	// Slightly darker at street level: damp and accumulated road dust.
	ALBEDO *= mix(0.78, 1.0, smoothstep(0.0, 2.8, world_position.y));
}
