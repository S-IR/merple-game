package main
import "algorithms"
import "core:fmt"
import "core:math"
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
MAX_Y :: 16
CHUNK_HEIGHT :: MAX_Y - MIN_Y
DEFAULT_SURFACE_LEVEL :: -1

WIDTH_OF_CELL :: f32(1)
POINTS_PER_X_DIR: int : auto_cast (CHUNK_SIZE / WIDTH_OF_CELL)
POINTS_PER_Z_DIR: int : auto_cast (CHUNK_SIZE / WIDTH_OF_CELL)
POINTS_PER_Y_DIR: int : auto_cast ((MAX_Y - MIN_Y) / WIDTH_OF_CELL)

Chunk :: struct {
	pos:          int2,
	points:       [POINTS_PER_X_DIR * POINTS_PER_Y_DIR * POINTS_PER_Z_DIR]Point,
	pointsSBO:    ^sdl.GPUBuffer,
	indices:      ^sdl.GPUBuffer,
	colors:       ^sdl.GPUBuffer,
	totalPoints:  u32,
	totalIndices: u32,
	arena:        virtual.Arena,
	alloc:        mem.Allocator,
}
chunk_point_get :: proc(c: ^Chunk, x, y, z: int) -> Point {
	return c.points[x * POINTS_PER_Y_DIR * POINTS_PER_Z_DIR + y * POINTS_PER_Z_DIR + z]
}

CHUNKS_PER_DIRECTION :: 1
Chunks := [CHUNKS_PER_DIRECTION][CHUNKS_PER_DIRECTION]Chunk{}
chunks_init :: proc() {
	for &xChunk, x in Chunks {
		for &chunk, y in xChunk {
			chunk_init(
				x,
				y,
				int2 {
					i32(x - CHUNKS_PER_DIRECTION / 2) * CHUNK_SIZE,
					i32(y - CHUNKS_PER_DIRECTION / 2) * CHUNK_SIZE,
				},
			)
		}
	}
}

RANDOM_RED_OPTIONS := [?]float4 {
	{1, 0, 0, 1},
	{.8, 0, 0, 1},
	{.6, 0, 0, 1},
	{.4, 0, 0, 1},
	{.2, 0, 0, 1},
}

SCALAR_FIELD := [POINTS_PER_X_DIR * POINTS_PER_Y_DIR * POINTS_PER_Z_DIR]f32{}
VERTEX_CREATED := [POINTS_PER_X_DIR * POINTS_PER_Y_DIR * POINTS_PER_Z_DIR]bool{}
chunk_init :: proc(x_idx, y_idx: int, pos: int2) {
	chunk := &Chunks[x_idx][y_idx]
	chunk.pos = pos
	chunk.alloc = virtual.arena_allocator(&chunk.arena)

	visiblePointCoords := make([dynamic]float3, context.temp_allocator)
	indices := make([dynamic]u16, context.temp_allocator)
	colors := make([dynamic]float4, context.temp_allocator)


	defer SCALAR_FIELD = {}
	defer VERTEX_CREATED = {}
	for x in 0 ..< POINTS_PER_X_DIR {
		for y in 0 ..< POINTS_PER_Y_DIR {
			for z in 0 ..< POINTS_PER_Z_DIR {
				res := noise.noise_3d_improve_xz(
					transmute(i64)seed,
					{f64(x) * .05, f64(y) * .05, f64(z) * .05},
				)
				SCALAR_FIELD[x * POINTS_PER_Y_DIR * POINTS_PER_Z_DIR + y * POINTS_PER_Z_DIR + z] =
					res
			}
		}
	}
	THRESHOLD: f32 : 0
	currentPointCount := 0

	for x in 0 ..< POINTS_PER_X_DIR - 1 {
		for y in 0 ..< POINTS_PER_Y_DIR - 1 {
			for z in 0 ..< POINTS_PER_Z_DIR - 1 {
				configIdx: uint = 0
				for pointOffset, i in POINT_OFFSETS {
					xI := int(pointOffset.x) + x
					yI := int(pointOffset.y) + y
					zI := int(pointOffset.z) + z
					noiseVal :=
						SCALAR_FIELD[xI * POINTS_PER_Y_DIR * POINTS_PER_Z_DIR + yI * POINTS_PER_Z_DIR + zI]
					if noiseVal > THRESHOLD do configIdx += 1 << uint(i)
				}
				assert(configIdx < 256)
				triangulation := TRIANGULATION_TABLE[configIdx]
				cubePos := float3{f32(x), f32(y), f32(z)}

				for i := 0; i < len(triangulation) && triangulation[i] != -1; i += 3 {
					edge1 := int(triangulation[i])
					edge2 := int(triangulation[i + 1])
					edge3 := int(triangulation[i + 2])

					p1a := POINT_OFFSETS[EDGES[edge1][0]]
					p1b := POINT_OFFSETS[EDGES[edge1][1]]
					p2a := POINT_OFFSETS[EDGES[edge2][0]]
					p2b := POINT_OFFSETS[EDGES[edge2][1]]
					p3a := POINT_OFFSETS[EDGES[edge3][0]]
					p3b := POINT_OFFSETS[EDGES[edge3][1]]

					vert1 :=
						cubePos +
						(float3{f32(p1a.x), f32(p1a.y), f32(p1a.z)} +
								float3{f32(p1b.x), f32(p1b.y), f32(p1b.z)}) *
							0.5
					vert2 :=
						cubePos +
						(float3{f32(p2a.x), f32(p2a.y), f32(p2a.z)} +
								float3{f32(p2b.x), f32(p2b.y), f32(p2b.z)}) *
							0.5
					vert3 :=
						cubePos +
						(float3{f32(p3a.x), f32(p3a.y), f32(p3a.z)} +
								float3{f32(p3b.x), f32(p3b.y), f32(p3b.z)}) *
							0.5

					append(&visiblePointCoords, vert1)
					append(&visiblePointCoords, vert2)
					append(&visiblePointCoords, vert3)
					append(&colors, float4{rand.float32(), rand.float32(), rand.float32(), 1})
					append(&colors, float4{rand.float32(), rand.float32(), rand.float32(), 1})
					append(&colors, float4{rand.float32(), rand.float32(), rand.float32(), 1})
					append(&indices, u16(currentPointCount + 0))
					append(&indices, u16(currentPointCount + 1))
					append(&indices, u16(currentPointCount + 2))
					currentPointCount += 3

				}


				// for edgeIndex in triangulation {
				// 	if edgeIndex < 0 do break
				// 	pointIndices := EDGES[edgeIndex]
				// 	pointA := POINT_OFFSETS[pointIndices[0]]
				// 	pointB := POINT_OFFSETS[pointIndices[1]]

				// 	posA := float3{f32(x) + pointA.x, f32(y) + pointA.y, f32(z) + pointA.z}
				// 	posB := float3{f32(x) + pointB.x, f32(y) + pointB.y, f32(z) + pointB.z}
				// 	position := (posA + posB) * .5

				// 	baseVertexIndex := u32(len(visiblePointCoords))


				// 	append(&visiblePointCoords, position)
				// }
			}
		}
	}


	ISO_LEVEL :: 0.0

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
			{usage = {.VERTEX}, size = u32(len(colors) * size_of(colors[0]))},
		)
		gpu_buffer_upload(&chunk.colors, raw_data(colors), len(colors) * size_of(colors[0]))
	}

	assert(chunk.pointsSBO != nil)
	assert(chunk.indices != nil)
	assert(chunk.colors != nil)
	assert(chunk.totalPoints > 0)
	assert(chunk.totalIndices > 0)
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

			vertexBufferBindings := [?]sdl.GPUBufferBinding {
				{buffer = chunk.pointsSBO},
				{buffer = chunk.colors},
			}
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
			sdl.ReleaseGPUBuffer(device, chunk.pointsSBO);chunk.pointsSBO = nil
			sdl.ReleaseGPUBuffer(device, chunk.colors);chunk.colors = nil
			sdl.ReleaseGPUBuffer(device, chunk.indices);chunk.indices = nil
			free_all(chunk.alloc)
		}
	}
}

is_chunk_in_camera_frustrum :: proc(pos: [2]i32, c: ^Camera) -> bool {
	min := float3{f32(pos[0]), f32(MIN_Y), f32(pos[1])}
	max := float3{f32((pos[0] + CHUNK_SIZE)), f32(MAX_Y), f32((pos[1] + CHUNK_SIZE))}

	planes := frustum_from_camera(c)

	for plane in planes {
		if !aabb_vs_plane(min, max, plane.point_on_plane, plane.normal) {
			return false
		}
	}
	return true
}
