package main
import "algorithms"
import "core:fmt"
import "core:math"
import "core:math/rand"
CHUNK_SIZE :: 16
RENDER_DISTANCE :: 5
MIN_Y :: -4
MAX_Y :: 4
CHUNK_HEIGHT :: MAX_Y - MIN_Y
DEFAULT_SURFACE_LEVEL :: -1

RANDOM_RED_OPTIONS := [?]float4 {
	{1, 0, 0, 1},
	{.8, 0, 0, 1},
	{.6, 0, 0, 1},
	{.4, 0, 0, 1},
	{.2, 0, 0, 1},
}
GRID_WIDTH :: f32(10)
GRID_HEIGHT :: f32(10)
WIDTH_OF_CELL :: f32(0.5)


cellsX: int : auto_cast (GRID_WIDTH / WIDTH_OF_CELL)
cellsY: int : auto_cast (GRID_HEIGHT / WIDTH_OF_CELL)

// Create point array
points := [cellsX][cellsY]Point{}
pointIndices := [cellsX - 1][cellsY - 1][len(BottomFacedIndices)]u16{}
triangleColors := [cellsX - 1][cellsY - 1][len(BottomFacedIndices) / 3]float4{}


load_chunk :: proc() {


	idx :: proc(x, y: int) -> u16 {
		return u16(y * cellsX + x)
	}

	for x in 0 ..< cellsX {
		for y in 0 ..< cellsY {
			cellCenterX := f32(x) * WIDTH_OF_CELL + WIDTH_OF_CELL * 0.5
			cellCenterZ := f32(y) * WIDTH_OF_CELL + WIDTH_OF_CELL * 0.5


			rx := (rand.float32() - 0.5) * WIDTH_OF_CELL * 0.8
			rz := (rand.float32() - 0.5) * WIDTH_OF_CELL * 0.8

			posX := cellCenterX + rx
			posZ := cellCenterZ + rz
			OCTAVES :: 3
			PERSISTENCE :: .5
			LACUNARITY :: 1.0
			AMPLITUDE :: 3.0

			SCALE :: 0.05

			surfaceLevelF :=
				DEFAULT_SURFACE_LEVEL +
				algorithms.simplex_octaves_2d(
					{posX * SCALE, posZ * SCALE},
					i64(seed),
					OCTAVES,
					PERSISTENCE,
					LACUNARITY,
				) *
					AMPLITUDE
			surface_y := i32(math.round(surfaceLevelF))
			surface_y = math.clamp(surface_y, MIN_Y + 1, MAX_Y)
			surface_ly := surface_y - MIN_Y
			points[x][y].pos = float3{posX, f32(surface_ly), posZ}

		}
	}

	for x in 0 ..< (cellsX - 1) {
		for y in 0 ..< (cellsY - 1) {
			pointIndices[x][y] = {
				idx(x, y),
				idx(x + 1, y),
				idx(x + 1, y + 1),
				idx(x, y),
				idx(x + 1, y + 1),
				idx(x, y + 1),
			}

			for i in 0 ..< len(triangleColors[x][y]) {
				triangleColors[x][y][i] = rand.choice(RANDOM_RED_OPTIONS[:])
			}
		}
	}
}
