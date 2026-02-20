package main
import "algorithms"
import "core:fmt"
import "core:math/noise"
import "core:simd"
Biome :: enum {
	Forest,
}
when VISUAL_REPRESENTATION_OF_NOISE_FN_RUN {
	PointType :: f32
} else {
	PointType :: enum {
		Air,
		YellowDirt,
		PurpleGround,
		LightPurpleGround,
		BlueDiamond,
		BlackCliff,
		PinkTrunk,
		WhiteTreeLeaf,
		Water,
	}
	Random_Colors_Per_Point_Type := [PointType][5][4]f32 {
		.Air               = {{}, {}, {}, {}, {}},
		.YellowDirt        = {
			{157, 110, 73, 1},
			{157, 110, 73, 1},
			{157, 110, 73, 1},
			{157, 110, 73, 1},
			{158, 111, 74, 1},
		},
		.PurpleGround      = {
			{33, 16, 94, 1},
			{33, 16, 94, 1},
			{31, 14, 92, 1},
			{31, 14, 92, 1},
			{31, 14, 92, 1},
		},
		.LightPurpleGround = {
			{141, 97, 237, 1},
			{141, 97, 237, 1},
			{142, 98, 238, 1},
			{141, 97, 237, 1},
			{142, 98, 238, 1},
		},
		.BlueDiamond       = {
			{1, 239, 234, 1},
			{0, 237, 232, 1},
			{0, 238, 233, 1},
			{0, 237, 232, 1},
			{0, 237, 232, 1},
		},
		.BlackCliff        = {
			{26, 17, 20, 1},
			{28, 19, 22, 1},
			{27, 18, 21, 1},
			{29, 20, 23, 1},
			{27, 18, 21, 1},
		},
		.PinkTrunk         = {
			{229, 108, 125, 1},
			{230, 109, 126, 1},
			{230, 109, 126, 1},
			{230, 109, 126, 1},
			{229, 108, 125, 1},
		},
		.WhiteTreeLeaf     = {
			{220, 191, 254, 1},
			{217, 188, 251, 1},
			{218, 189, 252, 1},
			{218, 189, 252, 1},
			{218, 189, 252, 1},
		},
		.Water             = {
			{66, 129, 127, 1},
			{68, 131, 129, 1},
			{65, 128, 126, 1},
			{68, 131, 129, 1},
			{66, 129, 127, 1},
		},
	}

}


procedural_point_type_noise_result :: proc(x, y, z: i32, seed: u64, w: Biome) -> f32 {
	HEIGHT_MAP_SCALE :: .02
	height :=
		noise.noise_2d(
			transmute(i64)seed,
			{f64(x) * HEIGHT_MAP_SCALE, f64(z) * HEIGHT_MAP_SCALE},
		) *
		10
	height = height * 2.0 + 1.0
	if f32(y) > height do return 0

	noise := noise.noise_3d_improve_xz(
		transmute(i64)seed,
		{f64(x) * 0.02, f64(y) * 0.02, f64(z) * 0.02},
	)
	noise += 1

	assert(noise >= 0 && noise <= 2)
	return noise
}
when !VISUAL_REPRESENTATION_OF_NOISE_FN_RUN {
	procedural_point_type :: proc(x, y, z: i32, seed: u64, w: Biome) -> PointType {
		// if y > 0 || y < 15 do return .Air
		// return .YellowDirt
		noise := procedural_point_type_noise_result(x, y, z, seed, w)
		if noise == 0 do return .Air

		// fmt.print("noise:", noise)
		// noise = (noise + 0.8) / 1.6

		FOREST_POINTS := [?]PointType {
			.YellowDirt,
			.PurpleGround,
			.LightPurpleGround,
			.BlueDiamond,
			.BlackCliff,
			.PinkTrunk,
			.WhiteTreeLeaf,
			.Water,
		}
		sliceSize: f32 = 2.0 / f32(len(FOREST_POINTS))
		for fp, i in FOREST_POINTS {
			rangeStart: f32 = sliceSize * f32(i)
			rangeEnd: f32 = rangeStart + sliceSize
			if noise >= rangeStart && noise <= rangeEnd {
				return fp
			}
		}
		assert(false)
		return .Air
	}
}


get_biome_weights :: proc(x, z: i32, seed: u64) -> Biome {
	scale: f64 : 0.002
	BIOME_OCTAVES :: 2
	BIOME_LACUNARITY :: .5
	BIOME_PERSISTENCE :: .2
	v := algorithms.warped_fbm_2d(
		f64(x) * scale,
		f64(z) * scale,
		seed,
		BIOME_OCTAVES,
		BIOME_LACUNARITY,
		BIOME_PERSISTENCE,
	)
	for b, i in Biome {
		lowRange := 1.0 / f64(len(Biome)) * f64(i)
		highRange := lowRange + 1.0 / f64(len(Biome))
		if v >= lowRange && v < highRange {
			return b
		}
	}
	return .Forest
	// v = (v + 1.0) * 0.5

	// forest := clamp(1.0 - abs(v - 0.2) * 4.0, 0.0, 1.0)
	// crystal := clamp(1.0 - abs(v - 0.5) * 4.0, 0.0, 1.0)
	// mountain := clamp(1.0 - abs(v - 0.8) * 4.0, 0.0, 1.0)

	// sum := forest + crystal + mountain
	// if sum == 0 {
	// 	return Biome{255, 0, 0}
	// }

	// forest /= sum
	// crystal /= sum
	// mountain /= sum

	// wf := u8(forest * 255.0)
	// wc := u8(crystal * 255.0)
	// wm := 255 - wf - wc

	// return Biome{wf, wc, wm}
}


randomColorIndex := 0

RANDOM_CYAN_OPTIONS := [?]float4 {
	{0, 1, 1, 1},
	{0.1, 0.9, 0.9, 1},
	{0.2, 0.8, 0.9, 1},
	{0.1, 0.7, 0.8, 1},
	{0.3, 1, 0.9, 1},
	{0.2, 0.85, 0.95, 1},
}

RANDOM_GREEN_OPTIONS := [?]float4 {
	{0, 1, 0, 1},
	{0.1, 0.9, 0.1, 1},
	{0.2, 0.8, 0.2, 1},
	{0.1, 0.7, 0.15, 1},
	{0.3, 1, 0.3, 1},
	{0.15, 0.85, 0.2, 1},
}
// color_for_point_type :: proc(p: PointType) -> [4]f32 {
// 	switch p {
// 	case .Air:
// 		unreachable()
// 	case .YellowDirt:
// 		return {.5, .5, .5, .5}
// 	}
// 	return {1, 1, 1, 1}
// }
