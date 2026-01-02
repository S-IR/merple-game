package algorithms

import "core:math/noise"
simplex_octaves_2d :: proc(
	pos: float2,
	seed: i64,
	octaves: int,
	persistence: f32,
	lacunarity: f32,
) -> f32 {
	result: f32 = 0
	amplitude: f32 = 1
	frequency: f32 = 1
	max_amplitude: f32 = 0

	for i in 0 ..< octaves {
		coordF32 := pos * frequency
		coordF64 := [2]f64{f64(coordF32.x), f64(coordF32.y)}
		result += noise.noise_2d(seed, coordF64) * amplitude
		max_amplitude += amplitude
		amplitude *= persistence
		frequency *= lacunarity
	}

	return result / max_amplitude
}
