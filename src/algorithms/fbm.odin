package algorithms

import "core:math"
import "core:math/noise"

fbm_max_amplitude :: proc(octaves: int, gain: f64) -> f64 {
	if gain >= 1.0 {
		return f64(octaves) // shouldn't happen with sane gain
	}
	return (1.0 - math.pow(gain, f64(octaves))) / (1.0 - gain)
}

fbm_2d :: proc(x, y: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> f64 {
	sum: f64 = 0.0
	amplitude: f64 = 1.0
	frequency: f64 = 1.0
	for i in 0 ..< octaves {
		sum += amplitude * f64(noise.noise_2d(transmute(i64)seed, {x * frequency, y * frequency}))
		frequency *= lacunarity
		amplitude *= gain
	}

	maxAmpl := fbm_max_amplitude(octaves, gain)
	return math.clamp((sum + maxAmpl) / (2.0 * maxAmpl), 0.0, 1.0)
}

fbm_3d :: proc(x, y, z: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> f64 {
	sum: f64 = 0.0
	amplitude: f64 = 1.0
	frequency: f64 = 1.0
	for i in 0 ..< octaves {
		sum +=
			amplitude *
			f64(
				noise.noise_3d_improve_xz(
					transmute(i64)seed,
					{x * frequency, y * frequency, z * frequency},
				),
			)
		frequency *= lacunarity
		amplitude *= gain
	}
	maxAmpl := fbm_max_amplitude(octaves, gain)
	return math.clamp((sum + maxAmpl) / (2.0 * maxAmpl), 0.0, 1.0)

}

warped_fbm_2d :: proc(x, y: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> f64 {
	// Lower warp strength → much more predictable range

	qx := fbm_2d(x, y, seed, octaves, lacunarity, gain)
	qy := fbm_2d(x + 5.2, y + 1.3, seed, octaves, lacunarity, gain)

	rx := fbm_2d(x * qx + 1.7, y * qy + 9.2, seed, octaves, lacunarity, gain)
	ry := fbm_2d(x * qx + 8.3, y * qy + 2.8, seed, octaves, lacunarity, gain)


	return fbm_2d(x * rx, y * ry, seed, octaves, lacunarity, gain)
}

warped_fbm_3d :: proc(x, y, z: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> f64 {
	WARP_SCALE :: 1.8

	qx := fbm_3d(x, y, z, seed, octaves, lacunarity, gain)
	qy := fbm_3d(x + 5.2, y + 1.3, z + 3.1, seed, octaves, lacunarity, gain)

	rx := fbm_3d(x * qx + 1.7, y * qy + 9.2, z + 0.9, seed, octaves, lacunarity, gain)
	ry := fbm_3d(x * qx + 8.3, y * qy + 2.8, z + 1.1, seed, octaves, lacunarity, gain)

	return fbm_3d(x * rx, y * ry, z + 1.6, seed, octaves, lacunarity, gain)

}
