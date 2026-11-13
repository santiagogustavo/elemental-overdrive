shader_type spatial;
render_mode unshaded, depth_prepass_alpha;

uniform float proximity_fade_distance : hint_range(0.0, 10.0, 0.01) = 1.0;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

uniform vec3 primary_color : source_color;
uniform vec3 secondary_color : source_color;

uniform float emission = 2.0;
uniform float exponent = 4.0;

void fragment() {
	float fresnel = clamp(pow(dot(VIEW, NORMAL), exponent), 0.0, 1.0);
	
	vec3 color = mix(secondary_color, primary_color, fresnel);
	
	ALBEDO = color * emission;
	
	ALPHA = fresnel * COLOR.a;
	
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    
    // Compara a profundidade do vértice/fragmento com a profundidade da cena
    float depth_blend = -view.z - (-VERTEX.z);
    depth_blend = clamp(depth_blend / proximity_fade_distance, 0.0, 1.0);
    
    ALPHA = ALPHA * depth_blend;
}