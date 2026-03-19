package main
import "algorithms"
import "core:fmt"
biome_point_type :: #force_inline proc(
	biome: Biome,
	x, y, z: i32,
	topY: i32,
	seed: u64,
) -> PointType {
	switch biome {
	case .Crystalbloom:
		return crystalbloom_point_type(x, y, z, topY, seed)

	case .Gorglai:
		return gorglai_point_type(x, y, z, seed)


	case .Arakholm:
		return arakholm_point_type(x, y, z, seed)


	case .Merplia:
		return merplia_point_type(x, y, z, seed)


	case .Wintercrown:
		return wintercrown_point_type(x, y, z, seed)


	case .Scholathorn:
		return scholathorn_point_type(x, y, z, seed)


	case .Adwaron:
		return adwaron_point_type(x, y, z, seed)


	case .Etherwind:
		return etherwind_point_type(x, y, z, seed)

	}
	unreachable()
}
CRYSTALBLOOM_TOP_COVER_LAYER_SIZE :: 6
crystalbloom_point_type :: proc(x, y, z: i32, topY: i32, seed: u64) -> PointType {
	// tunnel := algorithms.fbm_3d(f64(x) * .02, f64(y) * .005, f64(z) * .02, seed, 2, .5, .5)
	diffY := topY - y

	// if diffY < CRYSTALBLOOM_TOP_COVER_LAYER_SIZE {
	// return .LightPurpleGround
	SCALE :: 0.002
	noise := algorithms.ridged_fbm_2d(f64(x) * SCALE, f64(z) * SCALE, seed, 3, 4, 1.1)
	if noise < 0.1 do return .LightPurpleGround
	if noise < 0.3 do return .PurpleGround
	if noise < 0.35 do return .BlackCliff
	// return .YellowDirt
	// }
	return .YellowDirt
}

gorglai_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .Water
}
arakholm_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .Water
}
merplia_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .Water
}
wintercrown_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .Water
}

scholathorn_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .Water
}
adwaron_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .Water
}

etherwind_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .Water
}
