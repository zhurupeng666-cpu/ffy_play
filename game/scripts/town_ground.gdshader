// 城镇地表：单张网格遮罩生成草地、连续浅滩、深水和缓慢移动的波纹。
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain_mask : filter_nearest, repeat_disable;
uniform sampler2D depth_mask : filter_linear, repeat_disable;
uniform vec2 world_origin;
uniform vec2 world_extent;
uniform vec2 map_extent;
uniform vec2 half_cell;
uniform float zoom = 0.5;

// 格点采样：地图外侧保留为背景，不参与水岸过渡。
vec4 sample_tile(vec2 cell) {
	return texture(terrain_mask, (cell + 0.5) / map_extent);
}

// 像素扰动：获得稳定的草纹和随流动漂移的稀疏反光。
float grain(vec2 p) {
	return fract(sin(dot(p, vec2(27.13, 73.27))) * 15337.83);
}

void fragment() {
	vec2 world = world_origin + UV * world_extent;
	vec2 iso = world / half_cell;
	vec2 grid = vec2(iso.x + iso.y, iso.y - iso.x) * 0.5 + 0.5;
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	vec3 ink = vec3(0.094, 0.153, 0.125);
	if (all(greaterThanEqual(cell, vec2(0.0))) && all(lessThan(cell, map_extent))) {
		vec4 tile = sample_tile(cell);
		float variation = grain(cell);
		if (tile.r > 0.5) {
			vec3 shallow = vec3(0.245, 0.534, 0.525);
			vec3 deep = vec3(0.092, 0.283, 0.361);
			float depth = texture(depth_mask, grid / map_extent).g;
			depth = clamp(depth * 0.94 + 0.06 * sin(grid.x * 0.23 + grid.y * 0.37), 0.0, 1.0);
			ink = mix(shallow, deep, depth);
			vec2 water_pixel = floor(world * 0.5) * 2.0;
			float flow = water_pixel.y * 0.13 - water_pixel.x * 0.048 - TIME * 1.6;
			float wave = sin(flow + sin(world.x * 0.024 + world.y * 0.083) * 0.58);
			float gaps = sin(world.x * 0.073 + world.y * 0.024 + TIME * 0.66);
			float glint = smoothstep(0.93, 0.995, wave) * smoothstep(0.48, 1.0, gaps);
			float undertow = sin(world.y * 0.035 - world.x * 0.061 - TIME * 0.79);
			ink += (vec3(0.14, 0.19, 0.17) * glint + undertow * 0.026) * smoothstep(0.06, 0.35, zoom);
			if (tile.g < 0.22 && zoom > 0.08) {
				float bank = 1.0;
				if (sample_tile(cell + vec2(-1.0, 0.0)).r < 0.5) { bank = min(bank, local.x); }
				if (sample_tile(cell + vec2(1.0, 0.0)).r < 0.5) { bank = min(bank, 1.0 - local.x); }
				if (sample_tile(cell + vec2(0.0, -1.0)).r < 0.5) { bank = min(bank, local.y); }
				if (sample_tile(cell + vec2(0.0, 1.0)).r < 0.5) { bank = min(bank, 1.0 - local.y); }
				float foam = 1.0 - smoothstep(0.05, 0.16, bank);
				ink = mix(ink, vec3(0.65, 0.75, 0.63), foam * (0.43 + 0.22 * sin(flow)));
			}
		} else {
			float broad = sin(grid.x * 0.12 + grid.y * 0.07) * 0.043;
			ink = vec3(0.32, 0.42, 0.25) + broad + (variation - 0.5) * 0.048;
			if (tile.b > 0.8) {
				ink = mix(ink, vec3(0.40, 0.41, 0.35) + variation * 0.12, 0.82);
			} else if (tile.b > 0.3) {
				vec2 canopy = local - vec2(0.4 + 0.24 * variation, 0.49);
				float shade = 1.0 - smoothstep(0.18, 0.54, length(canopy));
				ink = mix(ink, vec3(0.13, 0.26, 0.155) + variation * 0.09 + shade * 0.055, 0.9);
			}
			if (tile.a > 0.5) {
				ink = mix(ink, vec3(0.61, 0.56, 0.36) + variation * 0.07, 0.69);
			}
			float fleck = step(0.96, grain(floor(world / vec2(5.0, 3.0)))) * smoothstep(0.35, 0.65, zoom);
			ink += vec3(0.12, 0.13, 0.055) * fleck;
			float edge = min(min(local.x, local.y), min(1.0 - local.x, 1.0 - local.y));
			ink *= 1.0 - 0.28 * (1.0 - smoothstep(0.02, 0.07, edge)) * smoothstep(0.22, 0.52, zoom);
		}
	}
	COLOR = vec4(ink, 1.0);
}
