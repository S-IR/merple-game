package algorithms
import "core:math"
import "core:math/noise"
import "core:math/rand"
import "core:simd"

fbm_noise :: proc(xy: [2]f64, amplitude: f64 = 1.0, octaves: f64 = 1.0) -> f64 {
	amplitudeLocal := amplitude
	fbmNoise: f64 = 0
	for i in 0 ..< octaves {
		fbmNoise += perlin_noise(xy) * amplitude
		amplitudeLocal *= .5
	}
	return fbmNoise

}

// perlin_noise :: proc(xy: #simd[2]f64) -> f64 {
// 	gridId := simd.floor(xy)
// 	gridUv := xy - gridId

// 	bl := gridId
// 	br := gridId + {1.0, 0.0}
// 	tl := gridId + {0.0, 1.0}
// 	tr := gridId + {1.0, 1.0}

// 	g1 := rando
// }
