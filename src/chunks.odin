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
CELLS_PER_X_DIR: int : auto_cast (CHUNK_SIZE / WIDTH_OF_CELL)
CELLS_PER_Z_DIR: int : auto_cast (CHUNK_SIZE / WIDTH_OF_CELL)
CELLS_PER_Y_DIR: int : auto_cast ((MAX_Y - MIN_Y) / WIDTH_OF_CELL)

Chunk :: struct {
	pos:          int2,
	points:       [CELLS_PER_X_DIR][CELLS_PER_Y_DIR][CELLS_PER_Z_DIR]Point,
	pointsSBO:    ^sdl.GPUBuffer,
	indices:      ^sdl.GPUBuffer,
	colors:       ^sdl.GPUBuffer,
	totalPoints:  u32,
	totalIndices: u32,
	arena:        virtual.Arena,
	alloc:        mem.Allocator,
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
visibilityMask := [CELLS_PER_X_DIR][CELLS_PER_Y_DIR][CELLS_PER_Z_DIR]bool{}
visibleIndexMap := [CELLS_PER_X_DIR][CELLS_PER_Y_DIR][CELLS_PER_Z_DIR]u16{}

chunk_init :: proc(x, y: int, pos: int2) {
	chunk := &Chunks[x][y]
	defer visibilityMask = {}
	defer visibleIndexMap = {}

	chunk.pos = pos
	chunk.alloc = virtual.arena_allocator(&chunk.arena)

	visiblePointCoords := make([dynamic]float3, context.temp_allocator)

	indices := make([dynamic]u16, context.temp_allocator)
	colors := make([dynamic]float4, context.temp_allocator)

	{
		for x: int = 0; x < int(CELLS_PER_X_DIR); x += 1 {
			for y: int = 0; y < int(CELLS_PER_Y_DIR); y += 1 {
				for z: int = 0; z < int(CELLS_PER_Z_DIR); z += 1 {
					res := noise.noise_3d_improve_xy(transmute(i64)seed, {f64(x), f64(y), f64(z)})
					res += 1
					res /= 2
					THRESHOLD :: .9
					if res < THRESHOLD {
						chunk.points[x][y][z] = Point {
							type = .Ground,
							pos  = float3{f32(x), f32(y), f32(z)},
						}
					}
				}
			}
		}
		idx: u16 = 0
		for x in 0 ..< CELLS_PER_X_DIR {
			for y in 0 ..< CELLS_PER_Y_DIR {
				for z in 0 ..< CELLS_PER_Z_DIR {
					isVisible := is_point_visible(chunk, x, y, z)
					visibilityMask[x][y][z] = isVisible
					if isVisible {
						append(&visiblePointCoords, chunk.points[x][y][z].pos)
						append(&colors, float4{rand.float32(), rand.float32(), rand.float32(), 1})
						visibleIndexMap[x][y][z] = idx
						idx += 1

					} else {
						visibleIndexMap[x][y][z] = max(u16)

					}
				}
			}
		}


		for x in 0 ..< CELLS_PER_X_DIR {
			for y in 0 ..< CELLS_PER_Y_DIR {
				for z in 0 ..< CELLS_PER_Z_DIR {
					if !visibilityMask[x][y][z] do continue

					indexInTheTable := uint(0)
					// indexInTheTable |= 1 << 0

					DIRECTIONS := [8][3]int {
						{0, 0, 0},
						{1, 0, 0},
						{1, 0, 1},
						{0, 0, 1}, // bottom 4
						{0, 1, 0},
						{1, 1, 0},
						{1, 1, 1},
						{0, 1, 1}, // top 4
					}
					TRIANGULATION_TABLE := [256][]u16 {
						{},
						{0, 3, 8},
						{0, 9, 1},
						{3, 8, 1, 1, 8, 9},
						{2, 11, 3},
						{8, 0, 11, 11, 0, 2},
						{3, 2, 11, 1, 0, 9},
						{11, 1, 2, 11, 9, 1, 11, 8, 9},
						{1, 10, 2},
						{0, 3, 8, 2, 1, 10},
						{10, 2, 9, 9, 2, 0},
						{8, 2, 3, 8, 10, 2, 8, 9, 10},
						{11, 3, 10, 10, 3, 1},
						{10, 0, 1, 10, 8, 0, 10, 11, 8},
						{9, 3, 0, 9, 11, 3, 9, 10, 11},
						{8, 9, 11, 11, 9, 10},
						{4, 8, 7},
						{7, 4, 3, 3, 4, 0},
						{4, 8, 7, 0, 9, 1},
						{1, 4, 9, 1, 7, 4, 1, 3, 7},
						{8, 7, 4, 11, 3, 2},
						{4, 11, 7, 4, 2, 11, 4, 0, 2},
						{0, 9, 1, 8, 7, 4, 11, 3, 2},
						{7, 4, 11, 11, 4, 2, 2, 4, 9, 2, 9, 1},
						{4, 8, 7, 2, 1, 10},
						{7, 4, 3, 3, 4, 0, 10, 2, 1},
						{10, 2, 9, 9, 2, 0, 7, 4, 8},
						{10, 2, 3, 10, 3, 4, 3, 7, 4, 9, 10, 4},
						{1, 10, 3, 3, 10, 11, 4, 8, 7},
						{10, 11, 1, 11, 7, 4, 1, 11, 4, 1, 4, 0},
						{7, 4, 8, 9, 3, 0, 9, 11, 3, 9, 10, 11},
						{7, 4, 11, 4, 9, 11, 9, 10, 11},
						{9, 4, 5},
						{9, 4, 5, 8, 0, 3},
						{4, 5, 0, 0, 5, 1},
						{5, 8, 4, 5, 3, 8, 5, 1, 3},
						{9, 4, 5, 11, 3, 2},
						{2, 11, 0, 0, 11, 8, 5, 9, 4},
						{4, 5, 0, 0, 5, 1, 11, 3, 2},
						{5, 1, 4, 1, 2, 11, 4, 1, 11, 4, 11, 8},
						{1, 10, 2, 5, 9, 4},
						{9, 4, 5, 0, 3, 8, 2, 1, 10},
						{2, 5, 10, 2, 4, 5, 2, 0, 4},
						{10, 2, 5, 5, 2, 4, 4, 2, 3, 4, 3, 8},
						{11, 3, 10, 10, 3, 1, 4, 5, 9},
						{4, 5, 9, 10, 0, 1, 10, 8, 0, 10, 11, 8},
						{11, 3, 0, 11, 0, 5, 0, 4, 5, 10, 11, 5},
						{4, 5, 8, 5, 10, 8, 10, 11, 8},
						{8, 7, 9, 9, 7, 5},
						{3, 9, 0, 3, 5, 9, 3, 7, 5},
						{7, 0, 8, 7, 1, 0, 7, 5, 1},
						{7, 5, 3, 3, 5, 1},
						{5, 9, 7, 7, 9, 8, 2, 11, 3},
						{2, 11, 7, 2, 7, 9, 7, 5, 9, 0, 2, 9},
						{2, 11, 3, 7, 0, 8, 7, 1, 0, 7, 5, 1},
						{2, 11, 1, 11, 7, 1, 7, 5, 1},
						{8, 7, 9, 9, 7, 5, 2, 1, 10},
						{10, 2, 1, 3, 9, 0, 3, 5, 9, 3, 7, 5},
						{7, 5, 8, 5, 10, 2, 8, 5, 2, 8, 2, 0},
						{10, 2, 5, 2, 3, 5, 3, 7, 5},
						{8, 7, 5, 8, 5, 9, 11, 3, 10, 3, 1, 10},
						{5, 11, 7, 10, 11, 5, 1, 9, 0},
						{11, 5, 10, 7, 5, 11, 8, 3, 0},
						{5, 11, 7, 10, 11, 5},
						{6, 7, 11},
						{7, 11, 6, 3, 8, 0},
						{6, 7, 11, 0, 9, 1},
						{9, 1, 8, 8, 1, 3, 6, 7, 11},
						{3, 2, 7, 7, 2, 6},
						{0, 7, 8, 0, 6, 7, 0, 2, 6},
						{6, 7, 2, 2, 7, 3, 9, 1, 0},
						{6, 7, 8, 6, 8, 1, 8, 9, 1, 2, 6, 1},
						{11, 6, 7, 10, 2, 1},
						{3, 8, 0, 11, 6, 7, 10, 2, 1},
						{0, 9, 2, 2, 9, 10, 7, 11, 6},
						{6, 7, 11, 8, 2, 3, 8, 10, 2, 8, 9, 10},
						{7, 10, 6, 7, 1, 10, 7, 3, 1},
						{8, 0, 7, 7, 0, 6, 6, 0, 1, 6, 1, 10},
						{7, 3, 6, 3, 0, 9, 6, 3, 9, 6, 9, 10},
						{6, 7, 10, 7, 8, 10, 8, 9, 10},
						{11, 6, 8, 8, 6, 4},
						{6, 3, 11, 6, 0, 3, 6, 4, 0},
						{11, 6, 8, 8, 6, 4, 1, 0, 9},
						{1, 3, 9, 3, 11, 6, 9, 3, 6, 9, 6, 4},
						{2, 8, 3, 2, 4, 8, 2, 6, 4},
						{4, 0, 6, 6, 0, 2},
						{9, 1, 0, 2, 8, 3, 2, 4, 8, 2, 6, 4},
						{9, 1, 4, 1, 2, 4, 2, 6, 4},
						{4, 8, 6, 6, 8, 11, 1, 10, 2},
						{1, 10, 2, 6, 3, 11, 6, 0, 3, 6, 4, 0},
						{11, 6, 4, 11, 4, 8, 10, 2, 9, 2, 0, 9},
						{10, 4, 9, 6, 4, 10, 11, 2, 3},
						{4, 8, 3, 4, 3, 10, 3, 1, 10, 6, 4, 10},
						{1, 10, 0, 10, 6, 0, 6, 4, 0},
						{4, 10, 6, 9, 10, 4, 0, 8, 3},
						{4, 10, 6, 9, 10, 4},
						{6, 7, 11, 4, 5, 9},
						{4, 5, 9, 7, 11, 6, 3, 8, 0},
						{1, 0, 5, 5, 0, 4, 11, 6, 7},
						{11, 6, 7, 5, 8, 4, 5, 3, 8, 5, 1, 3},
						{3, 2, 7, 7, 2, 6, 9, 4, 5},
						{5, 9, 4, 0, 7, 8, 0, 6, 7, 0, 2, 6},
						{3, 2, 6, 3, 6, 7, 1, 0, 5, 0, 4, 5},
						{6, 1, 2, 5, 1, 6, 4, 7, 8},
						{10, 2, 1, 6, 7, 11, 4, 5, 9},
						{0, 3, 8, 4, 5, 9, 11, 6, 7, 10, 2, 1},
						{7, 11, 6, 2, 5, 10, 2, 4, 5, 2, 0, 4},
						{8, 4, 7, 5, 10, 6, 3, 11, 2},
						{9, 4, 5, 7, 10, 6, 7, 1, 10, 7, 3, 1},
						{10, 6, 5, 7, 8, 4, 1, 9, 0},
						{4, 3, 0, 7, 3, 4, 6, 5, 10},
						{10, 6, 5, 8, 4, 7},
						{9, 6, 5, 9, 11, 6, 9, 8, 11},
						{11, 6, 3, 3, 6, 0, 0, 6, 5, 0, 5, 9},
						{11, 6, 5, 11, 5, 0, 5, 1, 0, 8, 11, 0},
						{11, 6, 3, 6, 5, 3, 5, 1, 3},
						{9, 8, 5, 8, 3, 2, 5, 8, 2, 5, 2, 6},
						{5, 9, 6, 9, 0, 6, 0, 2, 6},
						{1, 6, 5, 2, 6, 1, 3, 0, 8},
						{1, 6, 5, 2, 6, 1},
						{2, 1, 10, 9, 6, 5, 9, 11, 6, 9, 8, 11},
						{9, 0, 1, 3, 11, 2, 5, 10, 6},
						{11, 0, 8, 2, 0, 11, 10, 6, 5},
						{3, 11, 2, 5, 10, 6},
						{1, 8, 3, 9, 8, 1, 5, 10, 6},
						{6, 5, 10, 0, 1, 9},
						{8, 3, 0, 5, 10, 6},
						{6, 5, 10},
						{10, 5, 6},
						{0, 3, 8, 6, 10, 5},
						{10, 5, 6, 9, 1, 0},
						{3, 8, 1, 1, 8, 9, 6, 10, 5},
						{2, 11, 3, 6, 10, 5},
						{8, 0, 11, 11, 0, 2, 5, 6, 10},
						{1, 0, 9, 2, 11, 3, 6, 10, 5},
						{5, 6, 10, 11, 1, 2, 11, 9, 1, 11, 8, 9},
						{5, 6, 1, 1, 6, 2},
						{5, 6, 1, 1, 6, 2, 8, 0, 3},
						{6, 9, 5, 6, 0, 9, 6, 2, 0},
						{6, 2, 5, 2, 3, 8, 5, 2, 8, 5, 8, 9},
						{3, 6, 11, 3, 5, 6, 3, 1, 5},
						{8, 0, 1, 8, 1, 6, 1, 5, 6, 11, 8, 6},
						{11, 3, 6, 6, 3, 5, 5, 3, 0, 5, 0, 9},
						{5, 6, 9, 6, 11, 9, 11, 8, 9},
						{5, 6, 10, 7, 4, 8},
						{0, 3, 4, 4, 3, 7, 10, 5, 6},
						{5, 6, 10, 4, 8, 7, 0, 9, 1},
						{6, 10, 5, 1, 4, 9, 1, 7, 4, 1, 3, 7},
						{7, 4, 8, 6, 10, 5, 2, 11, 3},
						{10, 5, 6, 4, 11, 7, 4, 2, 11, 4, 0, 2},
						{4, 8, 7, 6, 10, 5, 3, 2, 11, 1, 0, 9},
						{1, 2, 10, 11, 7, 6, 9, 5, 4},
						{2, 1, 6, 6, 1, 5, 8, 7, 4},
						{0, 3, 7, 0, 7, 4, 2, 1, 6, 1, 5, 6},
						{8, 7, 4, 6, 9, 5, 6, 0, 9, 6, 2, 0},
						{7, 2, 3, 6, 2, 7, 5, 4, 9},
						{4, 8, 7, 3, 6, 11, 3, 5, 6, 3, 1, 5},
						{5, 0, 1, 4, 0, 5, 7, 6, 11},
						{9, 5, 4, 6, 11, 7, 0, 8, 3},
						{11, 7, 6, 9, 5, 4},
						{6, 10, 4, 4, 10, 9},
						{6, 10, 4, 4, 10, 9, 3, 8, 0},
						{0, 10, 1, 0, 6, 10, 0, 4, 6},
						{6, 10, 1, 6, 1, 8, 1, 3, 8, 4, 6, 8},
						{9, 4, 10, 10, 4, 6, 3, 2, 11},
						{2, 11, 8, 2, 8, 0, 6, 10, 4, 10, 9, 4},
						{11, 3, 2, 0, 10, 1, 0, 6, 10, 0, 4, 6},
						{6, 8, 4, 11, 8, 6, 2, 10, 1},
						{4, 1, 9, 4, 2, 1, 4, 6, 2},
						{3, 8, 0, 4, 1, 9, 4, 2, 1, 4, 6, 2},
						{6, 2, 4, 4, 2, 0},
						{3, 8, 2, 8, 4, 2, 4, 6, 2},
						{4, 6, 9, 6, 11, 3, 9, 6, 3, 9, 3, 1},
						{8, 6, 11, 4, 6, 8, 9, 0, 1},
						{11, 3, 6, 3, 0, 6, 0, 4, 6},
						{8, 6, 11, 4, 6, 8},
						{10, 7, 6, 10, 8, 7, 10, 9, 8},
						{3, 7, 0, 7, 6, 10, 0, 7, 10, 0, 10, 9},
						{6, 10, 7, 7, 10, 8, 8, 10, 1, 8, 1, 0},
						{6, 10, 7, 10, 1, 7, 1, 3, 7},
						{3, 2, 11, 10, 7, 6, 10, 8, 7, 10, 9, 8},
						{2, 9, 0, 10, 9, 2, 6, 11, 7},
						{0, 8, 3, 7, 6, 11, 1, 2, 10},
						{7, 6, 11, 1, 2, 10},
						{2, 1, 9, 2, 9, 7, 9, 8, 7, 6, 2, 7},
						{2, 7, 6, 3, 7, 2, 0, 1, 9},
						{8, 7, 0, 7, 6, 0, 6, 2, 0},
						{7, 2, 3, 6, 2, 7},
						{8, 1, 9, 3, 1, 8, 11, 7, 6},
						{11, 7, 6, 1, 9, 0},
						{6, 11, 7, 0, 8, 3},
						{11, 7, 6},
						{7, 11, 5, 5, 11, 10},
						{10, 5, 11, 11, 5, 7, 0, 3, 8},
						{7, 11, 5, 5, 11, 10, 0, 9, 1},
						{7, 11, 10, 7, 10, 5, 3, 8, 1, 8, 9, 1},
						{5, 2, 10, 5, 3, 2, 5, 7, 3},
						{5, 7, 10, 7, 8, 0, 10, 7, 0, 10, 0, 2},
						{0, 9, 1, 5, 2, 10, 5, 3, 2, 5, 7, 3},
						{9, 7, 8, 5, 7, 9, 10, 1, 2},
						{1, 11, 2, 1, 7, 11, 1, 5, 7},
						{8, 0, 3, 1, 11, 2, 1, 7, 11, 1, 5, 7},
						{7, 11, 2, 7, 2, 9, 2, 0, 9, 5, 7, 9},
						{7, 9, 5, 8, 9, 7, 3, 11, 2},
						{3, 1, 7, 7, 1, 5},
						{8, 0, 7, 0, 1, 7, 1, 5, 7},
						{0, 9, 3, 9, 5, 3, 5, 7, 3},
						{9, 7, 8, 5, 7, 9},
						{8, 5, 4, 8, 10, 5, 8, 11, 10},
						{0, 3, 11, 0, 11, 5, 11, 10, 5, 4, 0, 5},
						{1, 0, 9, 8, 5, 4, 8, 10, 5, 8, 11, 10},
						{10, 3, 11, 1, 3, 10, 9, 5, 4},
						{3, 2, 8, 8, 2, 4, 4, 2, 10, 4, 10, 5},
						{10, 5, 2, 5, 4, 2, 4, 0, 2},
						{5, 4, 9, 8, 3, 0, 10, 1, 2},
						{2, 10, 1, 4, 9, 5},
						{8, 11, 4, 11, 2, 1, 4, 11, 1, 4, 1, 5},
						{0, 5, 4, 1, 5, 0, 2, 3, 11},
						{0, 11, 2, 8, 11, 0, 4, 9, 5},
						{5, 4, 9, 2, 3, 11},
						{4, 8, 5, 8, 3, 5, 3, 1, 5},
						{0, 5, 4, 1, 5, 0},
						{5, 4, 9, 3, 0, 8},
						{5, 4, 9},
						{11, 4, 7, 11, 9, 4, 11, 10, 9},
						{0, 3, 8, 11, 4, 7, 11, 9, 4, 11, 10, 9},
						{11, 10, 7, 10, 1, 0, 7, 10, 0, 7, 0, 4},
						{3, 10, 1, 11, 10, 3, 7, 8, 4},
						{3, 2, 10, 3, 10, 4, 10, 9, 4, 7, 3, 4},
						{9, 2, 10, 0, 2, 9, 8, 4, 7},
						{3, 4, 7, 0, 4, 3, 1, 2, 10},
						{7, 8, 4, 10, 1, 2},
						{7, 11, 4, 4, 11, 9, 9, 11, 2, 9, 2, 1},
						{1, 9, 0, 4, 7, 8, 2, 3, 11},
						{7, 11, 4, 11, 2, 4, 2, 0, 4},
						{4, 7, 8, 2, 3, 11},
						{9, 4, 1, 4, 7, 1, 7, 3, 1},
						{7, 8, 4, 1, 9, 0},
						{3, 4, 7, 0, 4, 3},
						{7, 8, 4},
						{11, 10, 8, 8, 10, 9},
						{0, 3, 9, 3, 11, 9, 11, 10, 9},
						{1, 0, 10, 0, 8, 10, 8, 11, 10},
						{10, 3, 11, 1, 3, 10},
						{3, 2, 8, 2, 10, 8, 10, 9, 8},
						{9, 2, 10, 0, 2, 9},
						{8, 3, 0, 10, 1, 2},
						{2, 10, 1},
						{2, 1, 11, 1, 9, 11, 9, 8, 11},
						{11, 2, 3, 9, 0, 1},
						{11, 0, 8, 2, 0, 11},
						{3, 11, 2},
						{1, 8, 3, 9, 8, 1},
						{1, 9, 0},
						{8, 3, 0},
						{},
					}


					for dir, i in DIRECTIONS {
						p := [3]int{x, y, z} + dir
						if p.x >= CELLS_PER_X_DIR do continue
						if p.y >= CELLS_PER_Y_DIR do continue
						if p.z >= CELLS_PER_Z_DIR do continue

						if visibilityMask[p.x][p.y][p.z] {
							indexInTheTable |= 1 << (uint(i))
						}
					}
					assert(indexInTheTable < len(TRIANGULATION_TABLE))
					triangleIndices := TRIANGULATION_TABLE[int(indexInTheTable)]
					if len(triangleIndices) == 0 do continue


					for localCorner in triangleIndices {
						o := DIRECTIONS[localCorner]
						gx := x + o[0]
						gy := y + o[1]
						gz := z + o[2]

						globalIndex := visibleIndexMap[gx][gy][gz]
						append(&indices, globalIndex)
					}

					RANDOM_COLORS := [?]float4{{1, 0, 0, 1}, {.8, 0, 0, 1}, {.6, 0, 0, 1}}

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
