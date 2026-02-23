package algorithms
import "core:math"
import "core:math/noise"

hash2d :: proc(x, y: i64, seed: u64) -> u64 {
	h := u64(x) * 0x9E3779B185EBCA87 ~ u64(y) * 0xC2B2AE3D27D4EB4F ~ seed * 0x165667B19E3779F9
	h ~= h >> 30
	h *= 0xBF58476D1CE4E5B9
	h ~= h >> 27
	h *= 0x94D049BB133111EB
	h ~= h >> 31
	return h
}
rand_from_u64 :: proc(h: u64) -> f64 {
	return f64(h & 0xFFFFFFFF) / f64(0xFFFFFFFF)
}
worley_2d :: proc(x, y: f64, seed: u64) -> f64 {
	cellX := i64(math.floor(x))
	cellY := i64(math.floor(y))
	minDist := f64(1e9)

	for oy: i64 = -1; oy <= 1; oy += 1 {
		for ox: i64 = -1; ox <= 1; ox += 1 {
			cx := cellX + ox
			cy := cellY + oy


			h := hash2d(cx, cy, seed)

			fx := f64(cx) + rand_from_u64(h)
			fy := f64(cy) + rand_from_u64(h >> 32)

			dx := fx - x
			dy := fy - y
			dist := math.sqrt(dx * dx + dy * dy)

			if dist < minDist {
				minDist = dist
			}

		}
	}
	return math.clamp(minDist / 1.41421356237, 0.0, 1.0)
}
