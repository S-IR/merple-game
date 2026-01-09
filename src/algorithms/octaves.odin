package algorithms

import "core:math/noise"
simplex_octaves_2d :: proc(
	pos: [2]f32,
	seed: i64,
	octaves: int,
	persistence: f32,
	lacunarity: f64,
) -> (
	result: f32,
) {
	amplitude: f32 = 1
	frequency: f64 = 1
	maxAmplitude: f32 = 0
	posF64 := [2]f64{f64(pos.x), f64(pos.y)}
	for i in 0 ..< octaves {
		result += noise.noise_2d_improve_x(seed, posF64 * frequency) * amplitude
		maxAmplitude += amplitude
		amplitude *= persistence
		frequency *= lacunarity
	}
	assert(maxAmplitude != 0)
	return result / maxAmplitude
}


simplex_octaves_3d :: proc(
	pos: [3]f32,
	seed: i64,
	octaves: int,
	persistence: f32,
	lacunarity: f64,
) -> (
	result: f32,
) {
	amplitude: f32 = 1
	frequency: f64 = 1
	maxAmplitude: f32 = 0
	posF64 := [3]f64{f64(pos.x), f64(pos.y), f64(pos.z)}

	for i in 0 ..< octaves {
		result += noise.noise_3d_improve_xz(seed, posF64 * frequency) * amplitude
		maxAmplitude += amplitude
		amplitude *= persistence
		frequency *= lacunarity
	}

	return result / maxAmplitude
}
