package main
import "algorithms"
import "core:math"
procedural_point_type_max_height :: proc(x, z: i32, seed: u64, b: Biome) -> f32 {
	X := f64(x)
	Z := f64(z)

	switch b {

	case .Forest:
		return flat_height(X, Z, seed)

	case .Crater:
		return crater_height(X, Z, seed)

	case .Mountain:
		return mountain_height(X, Z, seed)

	case .Wavy:
		return wavy_height(X, Z, seed)
	}

	return 0
}
flat_height :: proc(x, z: f64, seed: u64) -> f32 {
	SCALING_FACTOR :: 0.02
	return f32(algorithms.fbm_2d(x * SCALING_FACTOR, z * SCALING_FACTOR, seed, 2, .75, 2))

}
crater_height :: proc(x, z: f64, seed: u64) -> f32 {
	base: f32 = 25.0

	w := algorithms.worley_2d(x * 0.02, z * 0.02, seed)

	depth := math.clamp((0.3 - w) * 40.0, 0.0, 20.0)
	return base - f32(depth)
}
mountain_height :: proc(x, z: f64, seed: u64) -> f32 {
	SCALING_FACTOR :: 0.005
	n := algorithms.fbm_2d(x * SCALING_FACTOR, z * SCALING_FACTOR, 2, 5, 2.0, 0.5)

	n = 1.0 - math.abs(n)
	n *= n
	n = math.pow(n, 1.5)

	return f32(n * 80 + 10)


}
wavy_height :: proc(x, z: f64, seed: u64) -> f32 {
	SCALING_FACTOR :: 0.005

	n := algorithms.fbm_2d(x * SCALING_FACTOR, z * SCALING_FACTOR, seed, 4, 2.5, 0.6)
	n = (n + 1) * 0.5
	return 20 + f32(n * 10)
}
