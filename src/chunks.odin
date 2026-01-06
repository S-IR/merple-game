package main
import "algorithms"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import sdl "vendor:sdl3"


int3 :: [3]i32
int2 :: [2]i32


CHUNK_SIZE :: 16
RENDER_DISTANCE :: 5
MIN_Y :: -16
MAX_Y :: 0
CHUNK_HEIGHT :: MAX_Y - MIN_Y
DEFAULT_SURFACE_LEVEL :: -1

WIDTH_OF_CELL :: f32(1)
CUBES_PER_X_DIR: int : auto_cast (CHUNK_SIZE / WIDTH_OF_CELL)
CUBES_PER_Z_DIR: int : auto_cast (CHUNK_SIZE / WIDTH_OF_CELL)
CUBES_PER_Y_DIR: int : auto_cast ((MAX_Y - MIN_Y) / WIDTH_OF_CELL)

VERTS_PER_X_DIR: int : CUBES_PER_X_DIR + 1
VERTS_PER_Y_DIR: int : CUBES_PER_Y_DIR + 1
VERTS_PER_Z_DIR: int : CUBES_PER_Z_DIR + 1

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
chunk_point_get :: proc(c: ^Chunk, x, y, z: int) -> Point {
	return c.points[x * CUBES_PER_Y_DIR * CUBES_PER_Z_DIR + y * CUBES_PER_Z_DIR + z]
}

CHUNKS_PER_DIRECTION :: 5

Chunks := [CHUNKS_PER_DIRECTION][CHUNKS_PER_DIRECTION]Chunk{}
CHUNK_MIDDLE_X_INDEX :: (CHUNKS_PER_DIRECTION / 2)
CHUNK_MIDDLE_Z_INDEX :: (CHUNKS_PER_DIRECTION / 2)

ChunkAtTheCenter := int2{}
chunks_init :: proc(c: ^Camera) {
	centerChunk := int2{i32(c.pos.x), i32(c.pos.z)} / CHUNK_SIZE
	half :: CHUNKS_PER_DIRECTION / 2
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

EXISTING_VERTICES_MAPPER := [VERTS_PER_X_DIR * VERTS_PER_Y_DIR * VERTS_PER_Z_DIR]int{}
// CUBE_NOISE_FIELD := [(CUBES_PER_X_DIR) * (CUBES_PER_Y_DIR) * (CUBES_PER_Z_DIR)]f32{}
index_into_point_arrays :: proc(x, y, z: int) -> int {
	return x * CUBES_PER_Y_DIR * CUBES_PER_Z_DIR + y * CUBES_PER_Z_DIR + z
}
chunk_init :: proc(xIdx, zIdx: int, pos: int2) {
	chunk := &Chunks[xIdx][zIdx]
	chunk.pos = pos
	chunk.alloc = virtual.arena_allocator(&chunk.arena)

	visiblePointCoords := make([dynamic]float3, context.temp_allocator)
	indices := make([dynamic]u16, context.temp_allocator)
	colorIndices := make([dynamic]u32, context.temp_allocator)
	colors := make([dynamic]float4, context.temp_allocator)

	for &v in EXISTING_VERTICES_MAPPER do v = -1
	defer EXISTING_VERTICES_MAPPER = {}
	THRESHOLD: f64 : 0.0
	chunkXYZ := float3{f32(pos[0]), 0, f32(pos[1])}
	for x in 0 ..< CUBES_PER_X_DIR {
		for y in 0 ..< CUBES_PER_Y_DIR {
			for z in 0 ..< CUBES_PER_Z_DIR {
				SCALE :: .05
				OCTAVES :: 6
				PERSISTENCE :: .25
				LACUNARITY :: 3.0
				res := algorithms.simplex_octaves_3d(
					chunkXYZ + {f32(x), f32(y + MIN_Y), f32(z)} * SCALE,
					transmute(i64)seed,
					OCTAVES,
					PERSISTENCE,
					LACUNARITY,
				)
				// CUBE_NOISE_FIELD[index_into_point_arrays(x, y, z)] = res
				if res < THRESHOLD do continue
				coordInChunk := float3{f32(x), f32(y), f32(z)}
				startingVisiblePointLen := u16(len(visiblePointCoords))
				calculate_existinv_vert_index := proc(xyzCoord: float3, vert: float3) -> int {
					vertIndex := xyzCoord + (vert + .5)
					return(
						int(vertIndex.x) * VERTS_PER_Y_DIR * VERTS_PER_Z_DIR +
						int(vertIndex.y) * VERTS_PER_Z_DIR +
						int(vertIndex.z) \
					)

				}
				for vert, i in cubeVertices {
					existingVertIdx := calculate_existinv_vert_index(coordInChunk, vert)
					assert(existingVertIdx < len(EXISTING_VERTICES_MAPPER))

					if EXISTING_VERTICES_MAPPER[existingVertIdx] == -1 {
						EXISTING_VERTICES_MAPPER[existingVertIdx] = len(visiblePointCoords)
						jitterX := rand.float32()
						jitterY := rand.float32()
						jitterZ := rand.float32()
						append(
							&visiblePointCoords,
							chunkXYZ +
							coordInChunk +
							vert +
							float3{jitterX, jitterY, jitterZ} +
							float3{0, +MIN_Y, 0},
						)
					}
				}

				for index, i in cubeIndices {
					vert := cubeVertices[index]
					existingIdx := calculate_existinv_vert_index(coordInChunk, vert)
					assert(existingIdx != -1)
					assert(existingIdx < len(EXISTING_VERTICES_MAPPER))
					append(&indices, u16(EXISTING_VERTICES_MAPPER[existingIdx]))

					if ((i + 1) % 3) == 0 {
						append(&colors, rand.choice(RANDOM_RED_OPTIONS[:]))
					}

				}
			}
		}
	}


	assert(len(visiblePointCoords) > 0)
	assert(len(indices) > 0)
	assert(len(colors) > 0)

	{
		chunk.pointsSBO = sdl.CreateGPUBuffer(
			device,
			{
				usage = {.VERTEX},
				size = u32(len(visiblePointCoords) * size_of(visiblePointCoords[0])),
			},
		)
		gpu_buffer_upload(
			&chunk.pointsSBO,
			raw_data(visiblePointCoords),
			len(visiblePointCoords) * size_of(visiblePointCoords[0]),
		)
		chunk.totalPoints = u32(len(visiblePointCoords))

		chunk.indices = sdl.CreateGPUBuffer(
			device,
			{usage = {.INDEX}, size = u32(len(indices) * size_of(indices[0]))},
		)
		gpu_buffer_upload(&chunk.indices, raw_data(indices), len(indices) * size_of(indices[0]))
		chunk.totalIndices = u32(len(indices))

		chunk.colors = sdl.CreateGPUBuffer(
			device,
			{usage = {.GRAPHICS_STORAGE_READ}, size = u32(len(colors) * size_of(colors[0]))},
		)
		gpu_buffer_upload(&chunk.colors, raw_data(colors[:]), len(colors) * size_of(colors[0]))
	}

	assert(chunk.pointsSBO != nil)
	assert(chunk.indices != nil)
	assert(chunk.colors != nil)
	assert(chunk.totalPoints > 0)
	assert(chunk.totalIndices > 0)
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
