shader_type spatial;
render_mode blend_add, cull_back, diffuse_burley, specular_schlick_ggx;

void fragment() {
	ALBEDO = vec3(0);
	ALPHA = 1.;
	METALLIC = 0.;
	SPECULAR = 1.;
	ROUGHNESS = 0.6;
}