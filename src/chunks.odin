package main
import "algorithms"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:prof/spall"
import "core:simd"
import sdl "vendor:sdl3"


int3 :: [3]i32
int2 :: [2]i32


CHUNK_SIZE :: 16
RENDER_DISTANCE :: 5
MIN_Y :: -32
MAX_Y :: 31
CHUNK_HEIGHT :: MAX_Y - MIN_Y
DEFAULT_SURFACE_LEVEL :: -1

WIDTH_OF_CELL :: f32(1)
CUBES_PER_X_DIR: i64 : auto_cast (CHUNK_SIZE / WIDTH_OF_CELL)
CUBES_PER_Z_DIR: i64 : auto_cast (CHUNK_SIZE / WIDTH_OF_CELL)
CUBES_PER_Y_DIR: i64 : auto_cast ((MAX_Y - MIN_Y) / WIDTH_OF_CELL)

VERTS_PER_X_DIR: i64 : CUBES_PER_X_DIR + 1
VERTS_PER_Y_DIR: i64 : CUBES_PER_Y_DIR + 1
VERTS_PER_Z_DIR: i64 : CUBES_PER_Z_DIR + 1

Chunk :: struct {
	pos:          int2,
	points:       [CUBES_PER_X_DIR * CUBES_PER_Y_DIR * CUBES_PER_Z_DIR]Point,
	pointsSBO:    ^sdl.GPUBuffer,
	indices:      ^sdl.GPUBuffer,
	colors:       ^sdl.GPUBuffer,
	totalPoints:  u32,
	totalIndices: u32,
	arena:        virtual.Arena,
	alloc:        mem.Allocator,
}
chunk_point_get :: proc(c: ^Chunk, x, y, z: i64) -> Point {
	return c.points[x * CUBES_PER_Y_DIR * CUBES_PER_Z_DIR + y * CUBES_PER_Z_DIR + z]
}

CHUNKS_PER_DIRECTION :: 10

Chunks := [CHUNKS_PER_DIRECTION][CHUNKS_PER_DIRECTION]Chunk{}
CHUNK_MIDDLE_X_INDEX :: (CHUNKS_PER_DIRECTION / 2)
CHUNK_MIDDLE_Z_INDEX :: (CHUNKS_PER_DIRECTION / 2)

ChunkAtTheCenter := int2{}
JITTER_POOL := [max(u16)]float3{}
NEXT_JITTER: u16 = 0
chunks_init :: proc(c: ^Camera) {
	centerChunk := int2{i32(c.pos.x), i32(c.pos.z)} / CHUNK_SIZE
	half :: CHUNKS_PER_DIRECTION / 2
	for &jitter in JITTER_POOL do jitter = float3{rand.float32(), rand.float32(), rand.float32()}
	for x in 0 ..< CHUNKS_PER_DIRECTION {
		for z in 0 ..< CHUNKS_PER_DIRECTION {
			relX := i32(x - half)
			relZ := i32(z - half)
			worldChunkCoordX := centerChunk[0] + relX
			worldChunkCoordZ := centerChunk[1] + relZ
			pos := int2{worldChunkCoordX * CHUNK_SIZE, worldChunkCoordZ * CHUNK_SIZE}
			chunk_init(x, z, pos)
		}
	}
	ChunkAtTheCenter = Chunks[CHUNK_MIDDLE_X_INDEX][CHUNK_MIDDLE_Z_INDEX].pos
}

RANDOM_RED_OPTIONS := [?]float4 {
	{1, 0, 0, 1},
	{.8, 0, 0, 1},
	{.6, 0, 0, 1},
	{.4, 0, 0, 1},
	{.2, 0, 0, 1},
}

// CUBE_NOISE_FIELD := [(CUBES_PER_X_DIR) * (CUBES_PER_Y_DIR) * (CUBES_PER_Z_DIR)]f32{}
index_into_point_arrays :: #force_inline proc(x, y, z: i64) -> i64 {
	return x * CUBES_PER_Y_DIR * CUBES_PER_Z_DIR + y * CUBES_PER_Z_DIR + z
}
MAX_POINTS :: CUBES_PER_X_DIR * CUBES_PER_Y_DIR * CUBES_PER_Z_DIR * 8
MAX_INDICES :: CUBES_PER_X_DIR * CUBES_PER_Y_DIR * CUBES_PER_Z_DIR * 36
MAX_COLORS :: MAX_INDICES
BIOME_SCALE :: 0.001
chunk_init :: proc(xIdx, zIdx: int, pos: int2) {
	chunk := &Chunks[xIdx][zIdx]
	if chunk.pointsSBO != nil {sdl.ReleaseGPUBuffer(device, chunk.pointsSBO);chunk.pointsSBO = nil}
	if chunk.indices != nil {sdl.ReleaseGPUBuffer(device, chunk.indices);chunk.indices = nil}
	if chunk.colors != nil {sdl.ReleaseGPUBuffer(device, chunk.colors);chunk.colors = nil}

	if chunk.alloc == {} {
		chunk.alloc = virtual.arena_allocator(&chunk.arena)
	} else {
		free_all(chunk.alloc)
	}

	staticVisiblePoints := make(
		[dynamic]float3,
		len = MAX_POINTS,
		allocator = context.temp_allocator,
	)
	staticVisiblePointsLen: int = 0

	staticIndices := make([dynamic]u16, len = MAX_INDICES, allocator = context.temp_allocator)
	staticIndicesLen: int = 0

	staticColors := make([dynamic]float4, len = MAX_COLORS, allocator = context.temp_allocator)
	staticColorsLen: int = 0

	EXISTING_VERTICES_MAPPER := make(
		[dynamic]int,
		len = VERTS_PER_X_DIR * VERTS_PER_Y_DIR * VERTS_PER_Z_DIR,
		allocator = context.temp_allocator,
	)
	for &v in EXISTING_VERTICES_MAPPER do v = -1

	chunk.pos = pos

	posXF64 := f64(pos[0])
	posZF64 := f64(pos[1])
	chunkXYZ := float3{f32(pos[0]), 0, f32(pos[1])}
	chunkXSimd := #simd[4]f64{posXF64, posXF64, posXF64, posXF64}
	chunkZSimd := #simd[4]f64{posZF64, posZF64, posZF64, posZF64}

	for x: f64 = 0.0; x < f64(CUBES_PER_X_DIR); x += 4 {
		for z: f64 = 0.0; z < f64(CUBES_PER_Z_DIR); z += 1 {
			worldXPosSimd := chunkXSimd + #simd[4]f64{x, x + 1, x + 2, x + 3}
			worldZPosSimd := chunkZSimd + #simd[4]f64{z, z, z, z}

			biomes := get_biome_weights(worldXPosSimd, worldZPosSimd, seed, BIOME_SCALE)

			surfaceLevelFs: [4]f64
			surfaceLevelFs[0] = -4
			surfaceLevelFs[1] = -4
			surfaceLevelFs[2] = -4
			surfaceLevelFs[3] = -4

			for i: i64 = 0; i < len(biomes); i += 1 {
				surfaceLevelF := i64(surfaceLevelFs[i])
				for yCoord: i64 = MIN_Y; yCoord < surfaceLevelF; yCoord += 1 {
					y := i64(yCoord) - MIN_Y
					currX := i64(x) + i
					currZ := i64(z)

					chunk.points[index_into_point_arrays(currX, y, currZ)] = u16(PointType.Ground)

					coordInChunk := float3{f32(x + f64(i)), f32(y), f32(z)}
					coordInChunkInt := [3]i64{i64(x) + i, i64(y), i64(z)}

					vertsX := coordInChunkInt.x + cubeVerticesX
					vertsY := coordInChunkInt.y + cubeVerticesY
					vertsZ := coordInChunkInt.z + cubeVerticesZ

					existingVertIndicesSimd :=
						vertsX * VERTS_PER_Y_DIR * VERTS_PER_Z_DIR +
						vertsY * VERTS_PER_Z_DIR +
						vertsZ

					existingVertIndices := simd.to_array(existingVertIndicesSimd)

					for existingVertIdx, i in existingVertIndices {
						#no_bounds_check {
							existingVertex := EXISTING_VERTICES_MAPPER[existingVertIdx]
							if existingVertex == -1 {
								jitteringVector :=
									JITTER_POOL[calculate_jitter_idx(currX, y, currZ)]
								EXISTING_VERTICES_MAPPER[existingVertIdx] = staticVisiblePointsLen

								vertex_offset_x := simd.extract(cubeVerticesX, i)
								vertex_offset_y := simd.extract(cubeVerticesY, i)
								vertex_offset_z := simd.extract(cubeVerticesZ, i)

								finalPointCoord := chunkXYZ
								finalPointCoord.x += f32(coordInChunkInt.x) + f32(vertex_offset_x)
								finalPointCoord.y +=
									f32(coordInChunkInt.y) + f32(vertex_offset_y) + f32(MIN_Y)
								finalPointCoord.z += f32(coordInChunkInt.z) + f32(vertex_offset_z)
								finalPointCoord += jitteringVector

								staticVisiblePoints[staticVisiblePointsLen] = finalPointCoord
								staticVisiblePointsLen += 1
							}
						}
					}

					#no_bounds_check {
						colorForThisCube := random_color_for_biome(biomes[i])
						#assert(len(cubeIndices) % 4 == 0)

						for index, idx in cubeIndices {
							vertIndex := coordInChunkInt + cubeVertices[index]
							existingIdx :=
								vertIndex.x * VERTS_PER_Y_DIR * VERTS_PER_Z_DIR +
								vertIndex.y * VERTS_PER_Z_DIR +
								vertIndex.z

							staticIndices[staticIndicesLen] = u16(
								EXISTING_VERTICES_MAPPER[existingIdx],
							)
							staticIndicesLen += 1

							staticColors[staticColorsLen] = colorForThisCube
							staticColorsLen += 1

						}
					}

				}
			}
		}
	}

	assert(staticVisiblePointsLen > 0)
	chunk.pointsSBO = sdl.CreateGPUBuffer(
		device,
		{usage = {.VERTEX}, size = u32(staticVisiblePointsLen * size_of(float3))},
	)
	chunk.totalPoints = u32(staticVisiblePointsLen)

	assert(staticIndicesLen > 0)
	chunk.indices = sdl.CreateGPUBuffer(
		device,
		{usage = {.INDEX}, size = u32(staticIndicesLen * size_of(u16))},
	)
	chunk.totalIndices = u32(staticIndicesLen)

	assert(staticColorsLen > 0)
	chunk.colors = sdl.CreateGPUBuffer(
		device,
		{usage = {.GRAPHICS_STORAGE_READ}, size = u32(staticColorsLen * size_of(float4))},
	)

	TOTAL_COUNT_OF_BUFFERS_TO_UPLOAD_TO :: 3

	buffers := [TOTAL_COUNT_OF_BUFFERS_TO_UPLOAD_TO]^^sdl.GPUBuffer {
		&chunk.pointsSBO,
		&chunk.indices,
		&chunk.colors,
	}
	datas := [TOTAL_COUNT_OF_BUFFERS_TO_UPLOAD_TO]rawptr {
		raw_data(staticVisiblePoints[0:staticVisiblePointsLen]),
		raw_data(staticIndices[0:staticIndicesLen]),
		raw_data(staticColors[0:staticColorsLen]),
	}
	sizes := [TOTAL_COUNT_OF_BUFFERS_TO_UPLOAD_TO]uint {
		uint(staticVisiblePointsLen * size_of(float3)),
		uint(staticIndicesLen * size_of(u16)),
		uint(staticColorsLen * size_of(float4)),
	}
	gpu_buffer_upload_batch(buffers[:], datas[:], sizes[:])
}
calculate_jitter_idx :: #force_inline proc(x, y, z: i64) -> u16 {
	return u16((x + y + z) % i64(max(u16)))
}
chunks_shift_per_player_movement :: proc(c: ^Camera) {

	xzOfCurrentCenterChunk := int2{i32(c.pos.x), i32(c.pos.z)} / CHUNK_SIZE
	xzOfPrevCenterChunk := Chunks[CHUNK_MIDDLE_X_INDEX][CHUNK_MIDDLE_Z_INDEX].pos / CHUNK_SIZE


	if xzOfCurrentCenterChunk == xzOfPrevCenterChunk do return


	delta := xzOfCurrentCenterChunk - xzOfPrevCenterChunk
	CHUNKS_PER_DIRECTION_HALF := CHUNKS_PER_DIRECTION / 2

	if delta.x != 0 {
		count := abs(delta.x)
		for i in 0 ..< count {
			if delta.x > 0 {
				for z in 0 ..< CHUNKS_PER_DIRECTION {
					chunk_release(&Chunks[0][z])
				}
				for x in 0 ..< CHUNKS_PER_DIRECTION - 1 {
					for z in 0 ..< CHUNKS_PER_DIRECTION {
						Chunks[x][z] = Chunks[x + 1][z]
						Chunks[x + 1][z].pointsSBO = nil
						Chunks[x + 1][z].indices = nil
						Chunks[x + 1][z].colors = nil
						Chunks[x + 1][z].arena = {}
						Chunks[x + 1][z].alloc = {}
					}
				}
				for z in 0 ..< CHUNKS_PER_DIRECTION {
					rel_x := i32(CHUNKS_PER_DIRECTION - 1 - CHUNKS_PER_DIRECTION_HALF)
					rel_z := i32(z - CHUNKS_PER_DIRECTION_HALF)
					pos := int2 {
						(xzOfCurrentCenterChunk[0] + rel_x) * CHUNK_SIZE,
						(xzOfCurrentCenterChunk[1] + rel_z) * CHUNK_SIZE,
					}
					chunk_init(CHUNKS_PER_DIRECTION - 1, z, pos)
				}
			} else {

				for z in 0 ..< CHUNKS_PER_DIRECTION {
					chunk_release(&Chunks[CHUNKS_PER_DIRECTION - 1][z])
				}
				for x := CHUNKS_PER_DIRECTION - 1; x > 0; x -= 1 {
					for z in 0 ..< CHUNKS_PER_DIRECTION {
						Chunks[x][z] = Chunks[x - 1][z]
						Chunks[x - 1][z].pointsSBO = nil
						Chunks[x - 1][z].indices = nil
						Chunks[x - 1][z].colors = nil
						Chunks[x - 1][z].arena = {}
						Chunks[x - 1][z].alloc = {}
					}
				}
				for z in 0 ..< CHUNKS_PER_DIRECTION {
					rel_x := i32(0 - CHUNKS_PER_DIRECTION_HALF)
					rel_z := i32(z - CHUNKS_PER_DIRECTION_HALF)
					pos := int2 {
						(xzOfCurrentCenterChunk[0] + rel_x) * CHUNK_SIZE,
						(xzOfCurrentCenterChunk[1] + rel_z) * CHUNK_SIZE,
					}
					chunk_init(0, z, pos)
				}
			}
		}
	}

	if delta[1] != 0 {
		count := abs(delta[1])
		for i in 0 ..< count {
			if delta[1] > 0 {
				for x in 0 ..< CHUNKS_PER_DIRECTION {
					chunk_release(&Chunks[x][0])
				}
				for z in 0 ..< CHUNKS_PER_DIRECTION - 1 {
					for x in 0 ..< CHUNKS_PER_DIRECTION {
						Chunks[x][z] = Chunks[x][z + 1]
						Chunks[x][z + 1].pointsSBO = nil
						Chunks[x][z + 1].indices = nil
						Chunks[x][z + 1].colors = nil
						Chunks[x][z + 1].arena = {}
						Chunks[x][z + 1].alloc = {}
					}
				}
				for x in 0 ..< CHUNKS_PER_DIRECTION {
					rel_x := i32(x - CHUNKS_PER_DIRECTION_HALF)
					rel_z := i32(CHUNKS_PER_DIRECTION - 1 - CHUNKS_PER_DIRECTION_HALF)
					pos := int2 {
						(xzOfCurrentCenterChunk[0] + rel_x) * CHUNK_SIZE,
						(xzOfCurrentCenterChunk[1] + rel_z) * CHUNK_SIZE,
					}
					chunk_init(x, CHUNKS_PER_DIRECTION - 1, pos)
				}
			} else {
				for x in 0 ..< CHUNKS_PER_DIRECTION {
					chunk_release(&Chunks[x][CHUNKS_PER_DIRECTION - 1])
				}
				for z := CHUNKS_PER_DIRECTION - 1; z > 0; z -= 1 {
					for x in 0 ..< CHUNKS_PER_DIRECTION {
						Chunks[x][z] = Chunks[x][z - 1]
						Chunks[x][z - 1].pointsSBO = nil
						Chunks[x][z - 1].indices = nil
						Chunks[x][z - 1].colors = nil
						Chunks[x][z - 1].arena = {}
						Chunks[x][z - 1].alloc = {}
					}
				}
				for x in 0 ..< CHUNKS_PER_DIRECTION {
					rel_x := i32(x - CHUNKS_PER_DIRECTION_HALF)
					rel_z := i32(0 - CHUNKS_PER_DIRECTION_HALF)
					pos := int2 {
						(xzOfCurrentCenterChunk[0] + rel_x) * CHUNK_SIZE,
						(xzOfCurrentCenterChunk[1] + rel_z) * CHUNK_SIZE,
					}
					chunk_init(x, 0, pos)
				}
			}
		}
	}


}
chunks_draw :: proc(render_pass: ^^sdl.GPURenderPass, view_proj: matrix[4, 4]f32) {
	assert(render_pass != nil && render_pass^ != nil)
	for x in 0 ..< len(Chunks) {
		for y in 0 ..< len(Chunks[0]) {
			chunk := &Chunks[x][y]
			if !is_chunk_in_camera_frustrum(chunk.pos, &camera) {
				continue
			}
			assert(chunk.pointsSBO != nil)
			assert(chunk.indices != nil)
			assert(chunk.colors != nil)
			assert(chunk.totalIndices > 0)
			assert(chunk.totalPoints > 0)


			sdl.BindGPUGraphicsPipeline(render_pass^, Point_r.pipeline)
			sdl.BindGPUIndexBuffer(render_pass^, {buffer = chunk.indices, offset = 0}, ._16BIT)

			vertexBufferBindings := [?]sdl.GPUBufferBinding{{buffer = chunk.pointsSBO}}
			sdl.BindGPUVertexBuffers(
				render_pass^,
				0,
				raw_data(vertexBufferBindings[:]),
				len(vertexBufferBindings),
			)

			sbosFragment := [?]^sdl.GPUBuffer{chunk.colors}
			sdl.BindGPUFragmentStorageBuffers(
				render_pass^,
				0,
				raw_data(sbosFragment[:]),
				len(sbosFragment),
			)

			sdl.DrawGPUIndexedPrimitives(render_pass^, chunk.totalIndices, 1, 0, 0, 0)
		}

	}
}
chunks_release :: proc() {
	for &chunkX in Chunks {
		for &chunk in chunkX {
			chunk_release(&chunk)
		}
	}
}
chunk_release :: proc(c: ^Chunk) {
	sdl.ReleaseGPUBuffer(device, c.pointsSBO);c.pointsSBO = nil
	sdl.ReleaseGPUBuffer(device, c.colors);c.colors = nil
	sdl.ReleaseGPUBuffer(device, c.indices);c.indices = nil

	free_all(c.alloc)
}
