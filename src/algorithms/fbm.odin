package algorithms
import "core:fmt"
import "core:math"
import "core:math/noise"
import "core:simd"
fbm_max_amplitude :: proc(octaves: int, gain: f64) -> f64 {
	if gain >= 1.0 {
		return f64(octaves) // shouldn't happen with sane gain
	}
	return (1.0 - math.pow(gain, f64(octaves))) / (1.0 - gain)
}
fbm_2d_simd :: proc(
	x, y: #simd[8]f64,
	seed: u64,
	octaves: int,
	lacunarity, gain: f64,
) -> (
	res: #simd[8]f64,
) {

	sum: #simd[8]f64 = {}
	amplitude: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	frequency: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	maxValPossible := amplitude
	seedTransmuted := transmute(i64)seed
	for i in 0 ..< octaves {
		xWithFreq := x * frequency
		yWithFreq := y * frequency

		noises := #simd[8]f64 {
			f64(
				noise.noise_2d(
					seedTransmuted,
					{simd.extract(xWithFreq, 0), simd.extract(yWithFreq, 0)},
				),
			),
			f64(
				noise.noise_2d(
					seedTransmuted,
					{simd.extract(xWithFreq, 1), simd.extract(yWithFreq, 1)},
				),
			),
			f64(
				noise.noise_2d(
					seedTransmuted,
					{simd.extract(xWithFreq, 2), simd.extract(yWithFreq, 2)},
				),
			),
			f64(
				noise.noise_2d(
					seedTransmuted,
					{simd.extract(xWithFreq, 3), simd.extract(yWithFreq, 3)},
				),
			),
			f64(
				noise.noise_2d(
					seedTransmuted,
					{simd.extract(xWithFreq, 4), simd.extract(yWithFreq, 4)},
				),
			),
			f64(
				noise.noise_2d(
					seedTransmuted,
					{simd.extract(xWithFreq, 5), simd.extract(yWithFreq, 5)},
				),
			),
			f64(
				noise.noise_2d(
					seedTransmuted,
					{simd.extract(xWithFreq, 6), simd.extract(yWithFreq, 6)},
				),
			),
			f64(
				noise.noise_2d(
					seedTransmuted,
					{simd.extract(xWithFreq, 7), simd.extract(yWithFreq, 7)},
				),
			),
		}
		sum += amplitude * noises
		maxValPossible += amplitude
		frequency *= lacunarity
		amplitude *= gain
	}
	// maxAmpl := fbm_max_amplitude(octaves, gain)
	sum /= maxValPossible
	sum = (sum + 1) / 2

	res = sum
	when ODIN_DEBUG == true {
		for i in 0 ..< 8 {
			val := simd.extract(res, i)
			assert(val >= 0 && val <= 1)
		}
	}


	return res


}
fbm_2d :: proc(x, y: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> (res: f64) {
	sum: f64 = 0.0
	amplitude: f64 = 1.0
	frequency: f64 = 1.0
	maxValPossible := 1.0
	for i in 0 ..< octaves {
		sum += amplitude * f64(noise.noise_2d(transmute(i64)seed, {x * frequency, y * frequency}))

		maxValPossible += amplitude
		frequency *= lacunarity
		amplitude *= gain
	}
	// maxAmpl := fbm_max_amplitude(octaves, gain)
	sum /= maxValPossible
	sum = (sum + 1) / 2

	res = sum
	assert(res >= 0 && res <= 1)

	return res
}

ridged_fbm_2d :: proc(x, y: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> (res: f64) {
	OFFSET :: 1.0

	sum: f64 = 0.0
	amplitude: f64 = 1.0
	frequency: f64 = 1.0
	weight: f64 = 1.0
	maxValPossible := 1.0

	for i in 0 ..< octaves {
		n := f64(noise.noise_2d(transmute(i64)seed, {x * frequency, y * frequency}))

		signal := OFFSET - math.abs(n)

		sum += signal * amplitude

		maxValPossible += 2.0 * amplitude
		frequency *= lacunarity
		amplitude *= gain
	}

	sum /= maxValPossible

	res = sum
	assert(res >= 0 && res <= 1)

	return res
}
ridged_fbm_2d_simd :: proc(
	x, y: #simd[8]f64,
	seed: u64,
	octaves: int,
	lacunarity, gain: f64,
) -> (
	res: #simd[8]f64,
) {
	OFFSET :: 1.0

	sum: #simd[8]f64 = {}
	amplitude: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	frequency: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	maxValPossible: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	seedTransmuted := transmute(i64)seed

	for i in 0 ..< octaves {
		xf := x * frequency
		yf := y * frequency

		noises := #simd[8]f64 {
			f64(noise.noise_2d(seedTransmuted, {simd.extract(xf, 0), simd.extract(yf, 0)})),
			f64(noise.noise_2d(seedTransmuted, {simd.extract(xf, 1), simd.extract(yf, 1)})),
			f64(noise.noise_2d(seedTransmuted, {simd.extract(xf, 2), simd.extract(yf, 2)})),
			f64(noise.noise_2d(seedTransmuted, {simd.extract(xf, 3), simd.extract(yf, 3)})),
			f64(noise.noise_2d(seedTransmuted, {simd.extract(xf, 4), simd.extract(yf, 4)})),
			f64(noise.noise_2d(seedTransmuted, {simd.extract(xf, 5), simd.extract(yf, 5)})),
			f64(noise.noise_2d(seedTransmuted, {simd.extract(xf, 6), simd.extract(yf, 6)})),
			f64(noise.noise_2d(seedTransmuted, {simd.extract(xf, 7), simd.extract(yf, 7)})),
		}

		offset_vec: #simd[8]f64 = {OFFSET, OFFSET, OFFSET, OFFSET, OFFSET, OFFSET, OFFSET, OFFSET}
		signal := offset_vec - simd.abs(noises)

		sum += signal * amplitude
		maxValPossible += {2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0} * amplitude
		frequency *= lacunarity
		amplitude *= gain
	}

	sum /= maxValPossible

	res = sum
	when ODIN_DEBUG == true {
		for i in 0 ..< 8 {
			val := simd.extract(res, i)
			assert(val >= 0 && val <= 1)
		}
	}
	return res
}

fbm_3d :: proc(x, y, z: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> (res: f64) {
	sum: f64 = 0.0
	amplitude: f64 = 1.0
	frequency: f64 = 1.0
	maxValPossible := 1.0

	for i in 0 ..< octaves {
		sum +=
			amplitude *
			f64(
				(noise.noise_3d_improve_xz(
						transmute(i64)seed,
						{x * frequency, y * frequency, z * frequency},
					) +
					1) /
				2,
			)
		maxValPossible += amplitude * 1.0

		frequency *= lacunarity
		amplitude *= gain
	}
	sum /= maxValPossible
	sum = (sum + 1) / 2


	res = sum
	assert(res >= 0 && res <= 1)
	return res
}

fbm_3d_simd :: proc(
	x, y, z: #simd[8]f64,
	seed: u64,
	octaves: int,
	lacunarity, gain: f64,
) -> (
	res: #simd[8]f64,
) {
	sum: #simd[8]f64 = {}
	amplitude: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	frequency: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	maxValPossible := amplitude
	seedTransmuted := transmute(i64)seed

	for i in 0 ..< octaves {
		xf := x * frequency
		yf := y * frequency
		zf := z * frequency

		noises := #simd[8]f64 {
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 0), simd.extract(yf, 0), simd.extract(zf, 0)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 1), simd.extract(yf, 1), simd.extract(zf, 1)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 2), simd.extract(yf, 2), simd.extract(zf, 2)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 3), simd.extract(yf, 3), simd.extract(zf, 3)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 4), simd.extract(yf, 4), simd.extract(zf, 4)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 5), simd.extract(yf, 5), simd.extract(zf, 5)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 6), simd.extract(yf, 6), simd.extract(zf, 6)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 7), simd.extract(yf, 7), simd.extract(zf, 7)},
				),
			),
		}

		sum += amplitude * noises
		maxValPossible += amplitude
		frequency *= lacunarity
		amplitude *= gain
	}

	sum /= maxValPossible
	sum = (sum + 1) / 2

	res = sum
	when ODIN_DEBUG == true {
		for i in 0 ..< 8 {
			val := simd.extract(res, i)
			assert(val >= 0 && val <= 1)
		}
	}
	return res
}

ridged_fbm_3d_simd :: proc(
	x, y, z: #simd[8]f64,
	seed: u64,
	octaves: int,
	lacunarity, gain: f64,
) -> (
	res: #simd[8]f64,
) {
	OFFSET :: 1.0

	sum: #simd[8]f64 = {}
	amplitude: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	frequency: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	maxValPossible: #simd[8]f64 = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	seedTransmuted := transmute(i64)seed

	for i in 0 ..< octaves {
		xf := x * frequency
		yf := y * frequency
		zf := z * frequency

		noises := #simd[8]f64 {
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 0), simd.extract(yf, 0), simd.extract(zf, 0)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 1), simd.extract(yf, 1), simd.extract(zf, 1)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 2), simd.extract(yf, 2), simd.extract(zf, 2)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 3), simd.extract(yf, 3), simd.extract(zf, 3)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 4), simd.extract(yf, 4), simd.extract(zf, 4)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 5), simd.extract(yf, 5), simd.extract(zf, 5)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 6), simd.extract(yf, 6), simd.extract(zf, 6)},
				),
			),
			f64(
				noise.noise_3d_improve_xz(
					seedTransmuted,
					{simd.extract(xf, 7), simd.extract(yf, 7), simd.extract(zf, 7)},
				),
			),
		}

		// OFFSET - abs(n), matching scalar ridged_fbm_3d exactly
		offset_vec: #simd[8]f64 = {OFFSET, OFFSET, OFFSET, OFFSET, OFFSET, OFFSET, OFFSET, OFFSET}
		signal := offset_vec - simd.abs(noises)

		sum += signal * amplitude
		maxValPossible += {2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0} * amplitude
		frequency *= lacunarity
		amplitude *= gain
	}

	sum /= maxValPossible

	res = sum
	when ODIN_DEBUG == true {
		for i in 0 ..< 8 {
			val := simd.extract(res, i)
			assert(val >= 0 && val <= 1)
		}
	}
	return res
}
// ridged_fbm_3d :: proc(x, y, z: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> (res: f64) {
// 	OFFSET :: 1.0
// 	RIDGE_GAIN :: 2.0

// 	sum: f64 = 0.0
// 	amplitude: f64 = 1.0
// 	frequency: f64 = 1.0
// 	weight: f64 = 1.0

// 	for i in 0 ..< octaves {
// 		n := f64(
// 			noise.noise_3d_improve_xz(
// 				transmute(i64)seed,
// 				{x * frequency, y * frequency, z * frequency},
// 			),
// 		)

// 		signal := OFFSET - math.abs(n)
// 		weight = math.clamp(signal * RIDGE_GAIN, 0.0, 1.0)
// 		signal *= signal
// 		signal *= weight

// 		sum += signal * amplitude

// 		frequency *= lacunarity
// 		amplitude *= gain
// 	}

// 	max_ampl := fbm_max_amplitude(octaves, gain)
// 	res = math.clamp(sum / max_ampl, 0.0, 1.0)
// 	assert(res >= 0 && res <= 1)
// 	return res
// }
// warped_fbm_2d :: proc(x, y: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> (res: f64) {
// 	// Lower warp strength → much more predictable range

// 	qx := fbm_2d(x, y, seed, octaves, lacunarity, gain)
// 	qy := fbm_2d(x + 5.2, y + 1.3, seed, octaves, lacunarity, gain)

// 	rx := fbm_2d(x * qx + 1.7, y * qy + 9.2, seed, octaves, lacunarity, gain)
// 	ry := fbm_2d(x * qx + 8.3, y * qy + 2.8, seed, octaves, lacunarity, gain)


// 	res = fbm_2d(x * rx, y * ry, seed, octaves, lacunarity, gain)

// 	assert(res >= 0 && res <= 1)
// 	return res
// }

// warped_fbm_3d :: proc(x, y, z: f64, seed: u64, octaves: int, lacunarity, gain: f64) -> (res: f64) {
// 	WARP_SCALE :: 1.8

// 	qx := fbm_3d(x, y, z, seed, octaves, lacunarity, gain)
// 	qy := fbm_3d(x + 5.2, y + 1.3, z + 3.1, seed, octaves, lacunarity, gain)

// 	rx := fbm_3d(x * qx + 1.7, y * qy + 9.2, z + 0.9, seed, octaves, lacunarity, gain)
// 	ry := fbm_3d(x * qx + 8.3, y * qy + 2.8, z + 1.1, seed, octaves, lacunarity, gain)


// 	res = fbm_3d(x * rx, y * ry, z + 1.6, seed, octaves, lacunarity, gain)
// 	assert(res >= 0 && res <= 1)
// 	return res
// }
lerp_scalar :: proc(a, b, t: f32) -> f32 {
	return a + (b - a) * t
}
lerp_simd :: proc(a, b, t: #simd[8]f32) -> #simd[8]f32 {
	return a + (b - a) * t
}
lerp :: proc {
	lerp_scalar,
	lerp_simd,
}
lerp_i32 :: proc(a, b: i32, t: f32) -> i32 {
	return i32(f32(a) + (f32(b) - f32(a)) * t)
}
