package main
import "algorithms"
import "core:simd"
Biome :: enum (u8) {
	Forest,
	Crystal,
	Mountain,
}
// biome-specific surface level functions
// Biome FBM parameters
FOREST_OCTAVES :: 2
FOREST_LACUNARITY :: 2.0
FOREST_PERSISTENCE :: 0.5
FOREST_SCALE :: 0.1
FOREST_HEIGHT_MULT :: 3.0
FOREST_BASE_HEIGHT :: -1.0

CRYSTAL_OCTAVES :: 3
CRYSTAL_LACUNARITY :: 2.0
CRYSTAL_PERSISTENCE :: 0.4
CRYSTAL_SCALE :: 0.03
CRYSTAL_HEIGHT_MULT :: -5.0
CRYSTAL_BASE_HEIGHT :: 0.0

MOUNTAIN_OCTAVES :: 5
MOUNTAIN_LACUNARITY :: 2.0
MOUNTAIN_PERSISTENCE :: 0.5
MOUNTAIN_SCALE :: 0.02
MOUNTAIN_HEIGHT_MULT :: 15.0
MOUNTAIN_BASE_HEIGHT :: 0


// Biome-specific surface level functions
surface_level_forest :: proc(x, z: f64, seed: u64) -> f64 {
	return(
		FOREST_BASE_HEIGHT +
		algorithms.fbm_2d(
			x * FOREST_SCALE,
			z * FOREST_SCALE,
			seed,
			FOREST_OCTAVES,
			FOREST_LACUNARITY,
			FOREST_PERSISTENCE,
		) *
			FOREST_HEIGHT_MULT \
	)
}

surface_level_crystal :: proc(x, z: f64, seed: u64) -> f64 {
	return(
		CRYSTAL_BASE_HEIGHT +
		algorithms.fbm_2d(
			x * CRYSTAL_SCALE,
			z * CRYSTAL_SCALE,
			seed,
			CRYSTAL_OCTAVES,
			CRYSTAL_LACUNARITY,
			CRYSTAL_PERSISTENCE,
		) *
			CRYSTAL_HEIGHT_MULT \
	)
}

surface_level_mountain :: proc(x, z: f64, seed: u64) -> f64 {
	return(
		MOUNTAIN_BASE_HEIGHT +
		algorithms.fbm_2d(
			x * MOUNTAIN_SCALE,
			z * MOUNTAIN_SCALE,
			seed,
			MOUNTAIN_OCTAVES,
			MOUNTAIN_LACUNARITY,
			MOUNTAIN_PERSISTENCE,
		) *
			MOUNTAIN_HEIGHT_MULT \
	)
}

get_biome_weights :: proc(xes, zes: #simd[4]f64, seed: u64, scale: f64) -> [4]Biome {
	noises := algorithms.noise_gen_2d(xes * scale, zes * scale, seed)
	ns := transmute([4]f64)noises
	return [4]Biome {
		get_biome_from_noise(ns[0]),
		get_biome_from_noise(ns[1]),
		get_biome_from_noise(ns[2]),
		get_biome_from_noise(ns[3]),
	}
}
get_biome_from_noise :: proc(v: f64) -> Biome {
	if v < 0.9 do return .Forest
	if v < 1.1 do return .Crystal
	return .Mountain
}

// get_biome_weights :: proc(x, z: i64, seed: u64, scale: f64) -> Biome {
// 	v := algorithms.fbm_warped_2d(f64(x) * scale, f64(z) * scale, seed)

// 	if v < 0.9 do return .Forest
// 	if v < 1.1 do return .Crystal
// 	return .Mountain
// }
randomColorIndex := 0

RANDOM_CYAN_OPTIONS := [?]float4 {
	{0, 1, 1, 1},
	{0.1, 0.9, 0.9, 1},
	{0.2, 0.8, 0.9, 1},
	{0.1, 0.7, 0.8, 1},
	{0.3, 1, 0.9, 1},
	{0.2, 0.85, 0.95, 1},
}

RANDOM_GREEN_OPTIONS := [?]float4 {
	{0, 1, 0, 1},
	{0.1, 0.9, 0.1, 1},
	{0.2, 0.8, 0.2, 1},
	{0.1, 0.7, 0.15, 1},
	{0.3, 1, 0.3, 1},
	{0.15, 0.85, 0.2, 1},
}
random_color_for_biome :: proc(b: Biome) -> (chosenColor: float4) {
	#no_bounds_check {
		switch b {
		case .Forest:
			chosenColor = RANDOM_GREEN_OPTIONS[randomColorIndex % len(RANDOM_GREEN_OPTIONS)]
		case .Crystal:
			chosenColor = RANDOM_CYAN_OPTIONS[randomColorIndex % len(RANDOM_CYAN_OPTIONS)]
		case .Mountain:
			chosenColor = RANDOM_RED_OPTIONS[randomColorIndex % len(RANDOM_RED_OPTIONS)]
		}
	}

	randomColorIndex += 1
	return chosenColor
}
