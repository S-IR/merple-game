package algorithms
import "core:math"
import "core:math/rand"


hash2 :: proc(x, y: i64, seed: u64) -> f64 {
	h := x * 374761393 + y * 668265263 + transmute(i64)seed * 144665
	h = (h ~ (h >> 13)) * 1274126177
	return f64(h & 0x00FFFFFF) / f64(0x00FFFFFF)
}

lerp :: #force_inline proc(a, b, t: f64) -> f64 {
	return a + t * (b - a)
}

smoothstep :: #force_inline proc(t: f64) -> f64 {
	return t * t * (3.0 - 2.0 * t)
}
value_noise_2d :: proc(x, y: f64, seed: u64) -> f64 {
	x0 := i64(math.floor(x))
	y0 := i64(math.floor(y))
	x1 := x0 + 1
	y1 := y0 + 1

	sx := smoothstep(x - f64(x0))
	sy := smoothstep(y - f64(y0))

	n00 := hash2(x0, y0, seed)
	n10 := hash2(x1, y0, seed)
	n01 := hash2(x0, y1, seed)
	n11 := hash2(x1, y1, seed)

	ix0 := lerp(n00, n10, sx)
	ix1 := lerp(n01, n11, sx)

	return lerp(ix0, ix1, sy)
}

fbm_2d :: proc(x, y: f64, seed: u64, octaves: u64, lacunarity: f64, persistence: f64) -> f64 {
	sum: f64 = 0
	amp: f64 = 1
	freq: f64 = 1

	for i in 0 ..< octaves {
		sum += value_noise_2d(x * freq, y * freq, seed + i * 17) * amp
		freq *= lacunarity
		amp *= persistence
	}

	return sum
}
fbm_warped_2d :: proc(x, y: f64, seed: u64) -> f64 {
	warp_x := fbm_2d(x + 13, y + 7, seed + 1, 2, 2.0, 0.5)
	warp_y := fbm_2d(x - 5, y + 11, seed + 2, 2, 2.0, 0.5)

	return fbm_2d(x + warp_x * 10, y + warp_y * 10, seed, 4, 2.0, 0.5)
}

noise_gen_2d :: proc(x: #simd[4]f64, y: #simd[4]f64, seed: u64) -> #simd[4]f64 {
	return {1, 1, 1, 1}
}
