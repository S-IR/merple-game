package main
import "algorithms"
biome_point_type :: proc(biome: Biome, x, y, z: i32, seed: u64) -> PointType {
	switch biome {
	case .Crystalbloom:
		return crystalbloom_point_type(x, y, z, seed)

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
crystalbloom_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	// tunnel := algorithms.fbm_3d(f64(x) * .02, f64(y) * .005, f64(z) * .02, seed, 2, .5, .5)
	//todo
	return .YellowDirt
}

gorglai_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .PurpleGround
}
arakholm_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .LightPurpleGround
}
merplia_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .BlueDiamond
}
wintercrown_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .BlackCliff
}

scholathorn_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .PinkTrunk
}
adwaron_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .WhiteTreeLeaf
}

etherwind_point_type :: proc(x, y, z: i32, seed: u64) -> PointType {
	//todo
	return .Water
}
