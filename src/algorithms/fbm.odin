package algorithms
import "core:math"
import "core:math/rand"
random :: proc(x, y: f64) -> f64 {
	dot := x * 12.9898 + y * 78.233
	whole := math.sin(dot) * 43758.5453123
	return whole - math.floor(whole)
}

noise :: proc(x, y: f64) -> f64 {
	ix := math.floor(x)
	iy := math.floor(y)
	fx := x - ix
	fy := y - iy

	a := random(ix, iy)
	b := random(ix + 1.0, iy)
	c := random(ix, iy + 1.0)
	d := random(ix + 1.0, iy + 1.0)

	ux := fx * fx * (3.0 - 2.0 * fx)
	uy := fy * fy * (3.0 - 2.0 * fy)

	return a * (1.0 - ux) * (1.0 - uy) + b * ux * (1.0 - uy) + c * (1.0 - ux) * uy + d * ux * uy
}

fbm_2d :: proc(x, y: f64, octaves: int) -> f64 {
	value: f64 = 0.0
	amplitude: f64 = 0.5
	px := x
	py := y
	for i in 0 ..< octaves {
		value += amplitude * noise(px, py)
		px *= 2.0
		py *= 2.0
		amplitude *= 0.5
	}
	return value
}
