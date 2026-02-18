package main
import "../modules/vma"
import "algorithms"
import "core:container/small_array"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:prof/spall"
import "core:simd"
import vk "vendor:vulkan"

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
	buffers:      struct {
		pointsBuffer: [MAX_FRAMES_IN_FLIGHT]VkBufferPoolElem,
		indices:      [MAX_FRAMES_IN_FLIGHT]VkBufferPoolElem,
		colors:       [MAX_FRAMES_IN_FLIGHT]VkBufferPoolElem,
	},
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
	INDEX_TYPE :: u16
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		if chunk.buffers.pointsBuffer[i].alloc != {} do continue
		assert(chunk.buffers.indices[i].buffer == {})
		assert(chunk.buffers.colors[i].buffer == {})

		vk_chk(
			vma.create_buffer(
				vkAllocator,
				{
					sType = .BUFFER_CREATE_INFO,
					size = vk.DeviceSize(MAX_POINTS * size_of([3]f32)),
					usage = {.VERTEX_BUFFER},
				},
				{flags = {.Host_Access_Sequential_Write, .Mapped}, usage = .Auto},
				&chunk.buffers.pointsBuffer[i].buffer,
				&chunk.buffers.pointsBuffer[i].alloc,
				nil,
			),
		)
		vk_chk(
			vma.create_buffer(
				vkAllocator,
				{
					sType = .BUFFER_CREATE_INFO,
					size = vk.DeviceSize(MAX_INDICES * size_of(INDEX_TYPE)),
					usage = {.INDEX_BUFFER},
				},
				{flags = {.Host_Access_Sequential_Write, .Mapped}, usage = .Auto},
				&chunk.buffers.indices[i].buffer,
				&chunk.buffers.indices[i].alloc,
				nil,
			),
		)

		vk_chk(
			vma.create_buffer(
				vkAllocator,
				{
					sType = .BUFFER_CREATE_INFO,
					size = vk.DeviceSize(MAX_COLORS * size_of([4]f32)),
					usage = {.STORAGE_BUFFER},
				},
				{flags = {.Host_Access_Sequential_Write, .Mapped}, usage = .Auto},
				&chunk.buffers.colors[i].buffer,
				&chunk.buffers.colors[i].alloc,
				nil,
			),
		)
	}


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
	chunk.totalPoints = u32(staticVisiblePointsLen)
	chunk.totalIndices = u32(staticIndicesLen)

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		assert(chunk.buffers.pointsBuffer[i].alloc != {})
		assert(chunk.buffers.indices[i].alloc != {})
		assert(chunk.buffers.colors[i].alloc != {})


		vertBufferPtr: rawptr
		vk_chk(vma.map_memory(vkAllocator, chunk.buffers.pointsBuffer[i].alloc, &vertBufferPtr))
		mem.copy(
			vertBufferPtr,
			raw_data(staticVisiblePoints[0:staticVisiblePointsLen]),
			staticVisiblePointsLen * size_of(staticVisiblePoints[0]),
		)
		vma.unmap_memory(vkAllocator, chunk.buffers.pointsBuffer[i].alloc)

		index := chunk.buffers.indices[i]


		indexBufferPtr: rawptr
		vk_chk(vma.map_memory(vkAllocator, chunk.buffers.indices[i].alloc, &indexBufferPtr))
		mem.copy(
			indexBufferPtr,
			raw_data(staticIndices[0:staticIndicesLen]),
			staticIndicesLen * size_of(staticIndices[0]),
		)
		vma.unmap_memory(vkAllocator, chunk.buffers.indices[i].alloc)


		colorBuferPtr: rawptr
		vk_chk(vma.map_memory(vkAllocator, chunk.buffers.colors[i].alloc, &colorBuferPtr))
		mem.copy(
			colorBuferPtr,
			raw_data(staticColors[0:staticColorsLen]),
			staticColorsLen * size_of(staticColors[0]),
		)
		vma.unmap_memory(vkAllocator, chunk.buffers.colors[i].alloc)
	}


}
calculate_jitter_idx :: #force_inline proc(x, y, z: i64) -> u16 {
	return u16((x + y + z) % i64(max(u16)))
}
chunks_shift_per_player_movement :: proc(c: ^Camera) {
	xzOfCurrentCenterChunk := int2{i32(c.pos.x), i32(c.pos.z)} / CHUNK_SIZE
	xzOfPrevCenterChunk := Chunks[CHUNK_MIDDLE_X_INDEX][CHUNK_MIDDLE_Z_INDEX].pos / CHUNK_SIZE
	if xzOfCurrentCenterChunk == xzOfPrevCenterChunk do return
	delta := xzOfCurrentCenterChunk - xzOfPrevCenterChunk
	half := CHUNKS_PER_DIRECTION / 2

	if delta.x != 0 {
		count := abs(delta.x)
		for i in 0 ..< count {
			if delta.x > 0 {
				for x in 0 ..< CHUNKS_PER_DIRECTION - 1 {
					for z in 0 ..< CHUNKS_PER_DIRECTION {
						firstBuffers := Chunks[x][z].buffers
						secondBuffers := Chunks[x + 1][z].buffers
						Chunks[x][z] = Chunks[x + 1][z]
						Chunks[x][z].buffers, Chunks[x + 1][z].buffers =
							secondBuffers, firstBuffers
						Chunks[x + 1][z].points = {}
						Chunks[x + 1][z].arena = {}
						Chunks[x + 1][z].alloc = {}
					}
				}
				for z in 0 ..< CHUNKS_PER_DIRECTION {
					relX := i32(CHUNKS_PER_DIRECTION - 1 - half) + i32(i)
					relZ := i32(z - half)
					pos := int2 {
						(xzOfCurrentCenterChunk[0] + relX) * CHUNK_SIZE,
						(xzOfCurrentCenterChunk[1] + relZ) * CHUNK_SIZE,
					}
					chunk_init(CHUNKS_PER_DIRECTION - 1, z, pos)
				}
			} else {
				for x := CHUNKS_PER_DIRECTION - 1; x > 0; x -= 1 {
					for z in 0 ..< CHUNKS_PER_DIRECTION {
						firstBuffers := Chunks[x][z].buffers
						secondBuffers := Chunks[x - 1][z].buffers
						Chunks[x][z] = Chunks[x - 1][z]
						Chunks[x][z].buffers, Chunks[x - 1][z].buffers =
							secondBuffers, firstBuffers

						Chunks[x - 1][z].points = {}
						Chunks[x - 1][z].arena = {}
						Chunks[x - 1][z].alloc = {}
					}
				}
				for z in 0 ..< CHUNKS_PER_DIRECTION {
					relX := i32(0 - half) - i32(i)
					relZ := i32(z - half)
					pos := int2 {
						(xzOfCurrentCenterChunk[0] + relX) * CHUNK_SIZE,
						(xzOfCurrentCenterChunk[1] + relZ) * CHUNK_SIZE,
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
				for z in 0 ..< CHUNKS_PER_DIRECTION - 1 {
					for x in 0 ..< CHUNKS_PER_DIRECTION {
						firstBuffers := Chunks[x][z].buffers
						secondBuffers := Chunks[x][z + 1].buffers
						Chunks[x][z] = Chunks[x][z + 1]
						Chunks[x][z].buffers, Chunks[x][z + 1].buffers =
							secondBuffers, firstBuffers

						Chunks[x][z + 1].points = {}
						Chunks[x][z + 1].arena = {}
						Chunks[x][z + 1].alloc = {}
					}
				}
				for x in 0 ..< CHUNKS_PER_DIRECTION {
					relX := i32(x - half)
					relZ := i32(CHUNKS_PER_DIRECTION - 1 - half) + i32(i)
					pos := int2 {
						(xzOfCurrentCenterChunk[0] + relX) * CHUNK_SIZE,
						(xzOfCurrentCenterChunk[1] + relZ) * CHUNK_SIZE,
					}
					chunk_init(x, CHUNKS_PER_DIRECTION - 1, pos)
				}
			} else {
				for z := CHUNKS_PER_DIRECTION - 1; z > 0; z -= 1 {
					for x in 0 ..< CHUNKS_PER_DIRECTION {
						firstBuffers := Chunks[x][z].buffers
						secondBuffers := Chunks[x][z - 1].buffers
						Chunks[x][z] = Chunks[x][z - 1]
						Chunks[x][z].buffers, Chunks[x][z - 1].buffers =
							secondBuffers, firstBuffers

						Chunks[x][z - 1].points = {}
						Chunks[x][z - 1].arena = {}
						Chunks[x][z - 1].alloc = {}
					}
				}
				for x in 0 ..< CHUNKS_PER_DIRECTION {
					relX := i32(x - half)
					relZ := i32(0 - half) - i32(i)
					pos := int2 {
						(xzOfCurrentCenterChunk[0] + relX) * CHUNK_SIZE,
						(xzOfCurrentCenterChunk[1] + relZ) * CHUNK_SIZE,
					}
					chunk_init(x, 0, pos)
				}
			}
		}
	}
}
chunks_draw :: proc(
	cb: vk.CommandBuffer,
	p: ^PipelineData,
	cameraUbo: vk.Buffer,
	cameraUboSize: vk.DeviceSize,
) {
	vk.CmdBindPipeline(cb, .GRAPHICS, p.graphicsPipeline)

	for x in 0 ..< len(Chunks) {
		for y in 0 ..< len(Chunks[0]) {

			chunk := &Chunks[x][y]

			// if !is_chunk_in_camera_frustrum(chunk.pos, &camera) do continue
			if chunk.totalIndices == 0 do continue

			// ----------------------------
			// Bind vertex + index buffers
			// ----------------------------
			assert(chunk.buffers.pointsBuffer[vkFrameIndex].alloc != {})
			vertexBuffer := chunk.buffers.pointsBuffer[vkFrameIndex].buffer
			vertexOffset := vk.DeviceSize(0)

			vk.CmdBindVertexBuffers(
				cb,
				0,
				1, // <-- ONLY ONE BINDING
				&vertexBuffer,
				&vertexOffset,
			)

			vk.CmdBindIndexBuffer(cb, chunk.buffers.indices[vkFrameIndex].buffer, 0, .UINT16)

			// ----------------------------
			// Push descriptors
			// ----------------------------

			cameraInfo := vk.DescriptorBufferInfo {
				buffer = cameraUbo,
				offset = 0,
				range  = cameraUboSize,
			}

			colorInfo := vk.DescriptorBufferInfo {
				buffer = chunk.buffers.colors[vkFrameIndex].buffer,
				offset = 0,
				range  = vk.DeviceSize(vk.WHOLE_SIZE),
			}

			writes := [?]vk.WriteDescriptorSet {
				{
					sType = .WRITE_DESCRIPTOR_SET,
					dstBinding = 0,
					descriptorCount = 1,
					descriptorType = .UNIFORM_BUFFER,
					pBufferInfo = &cameraInfo,
				},
				{
					sType = .WRITE_DESCRIPTOR_SET,
					dstBinding = 1,
					descriptorCount = 1,
					descriptorType = .STORAGE_BUFFER,
					pBufferInfo = &colorInfo,
				},
			}

			vk.CmdPushDescriptorSetKHR(
				cb,
				.GRAPHICS,
				p.layout,
				0,
				len(writes),
				raw_data(writes[:]),
			)

			// ----------------------------
			// Draw
			// ----------------------------

			vk.CmdDrawIndexed(cb, chunk.totalIndices, 1, 0, 0, 0)
		}
	}
}

chunks_release :: proc() {
	for &chunkX in Chunks {
		for &chunk in chunkX {
			chunk_discard(&chunk)
		}
	}
}
chunk_discard :: proc(chunk: ^Chunk) {
	assert(chunk != nil)

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		if chunk.buffers.pointsBuffer[i].alloc != {} {
			vma.destroy_buffer(
				vkAllocator,
				chunk.buffers.pointsBuffer[i].buffer,
				chunk.buffers.pointsBuffer[i].alloc,
			)
			chunk.buffers.pointsBuffer[i] = {}
		}
		if chunk.buffers.indices[i].alloc != {} {
			vma.destroy_buffer(
				vkAllocator,
				chunk.buffers.indices[i].buffer,
				chunk.buffers.indices[i].alloc,
			)
			chunk.buffers.indices[i] = {}
		}
		if chunk.buffers.colors[i].alloc != {} {
			vma.destroy_buffer(
				vkAllocator,
				chunk.buffers.colors[i].buffer,
				chunk.buffers.colors[i].alloc,
			)
			chunk.buffers.colors[i] = {}
		}
	}
	chunk.buffers = {}

	free_all(chunk.alloc)
	chunk.pos = {0, 0}
	chunk.totalPoints = 0
	chunk.totalIndices = 0
}
