package algorithms

import "core:math/noise"

fbm_3d :: proc(x, y, z: f64, seed: u64) -> f64 {
	octaves := 5
	lacunarity: f64 = 2.0
	gain: f64 = 0.5

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

	return sum

}
fbm_2d :: proc(x, y: f64, seed: u64) -> f64 {
	octaves := 5
	lacunarity: f64 = 2.0 // frequency multiplier
	gain: f64 = 0.5 // amplitude multiplier

	sum: f64 = 0.0
	amplitude: f64 = 1.0
	frequency: f64 = 1.0

	for i in 0 ..< octaves {
		sum += amplitude * f64(noise.noise_2d(transmute(i64)seed, {x * frequency, y * frequency}))
		frequency *= lacunarity
		amplitude *= gain
	}

	return sum

}
warped_fbm_2d :: proc(x, y: f64, seed: u64) -> f64 {
	qx := fbm_2d(x, y, seed)
	qy := fbm_2d(x + 5.2, y + 1.3, seed)

	rx := fbm_2d(x + 4.0 * qx + 1.7, y + 4.0 * qy + 9.2, seed)

	ry := fbm_2d(x + 4.0 * qx + 8.3, y + 4.0 * qy + 2.8, seed)

	return fbm_2d(x + 4.0 * rx, y + 4.0 * ry, seed)
}
warped_fbm_3d :: proc(x, y, z: f64, seed: u64) -> f64 {
	qx := fbm_3d(x, y, z, seed)
	qy := fbm_3d(x + 5.2, y + 1.3, z + 3.1, seed)

	rx := fbm_3d(x + 4.0 * qx + 1.7, y + 4.0 * qy + 9.2, z + .9, seed)

	ry := fbm_3d(x + 4.0 * qx + 8.3, y + 4.0 * qy + 2.8, z + 1.1, seed)

	return fbm_3d(x + 4.0 * rx, y + 4.0 * ry, z + 1.6, seed)
}
