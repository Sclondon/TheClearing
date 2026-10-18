// What moves a low plant (Undergrowth): a little sway in the wind, and anyone
// going through it (the shader's `pushers`, x y z and a radius, `pusher_count`
// of them) pushing it aside and down. `tall` is how far up the plant the vertex
// is (the higher, the further it goes). The answer is in the model's own space.
vec3 bent(mat4 model, vec3 vertex, float tall, float sway_by, float time) {
	vec3 here = (model * vec4(vertex, 1.0)).xyz;
	float t = time * 1.3 + dot(here.xz, vec2(0.21, 0.17));
	vec3 move = vec3(sin(t), 0.0, cos(t * 0.8)) * sway_by * tall * tall;
	for (int i = 0; i < 8; i++) {
		if (i >= pusher_count) {
			break;
		}
		vec4 p = pushers[i];
		vec2 away = here.xz - p.xz;
		float far = length(away);
		float reach = p.w * 1.5 + 0.35;
		if (far < reach && abs(here.y - p.y) < 2.5) {
			float k = 1.0 - far / reach;
			k *= k;
			move.xz += away / max(far, 0.001) * k * tall * 0.9;
			move.y -= k * tall * 0.4;
		}
	}
	return inverse(mat3(model)) * move;
}
