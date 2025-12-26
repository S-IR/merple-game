package algorithms
import "core:math"
import "core:math/rand"
import "core:slice"

float3 :: [3]f32
float2 :: [2]f32

poisson_2d :: proc(
	startPos: float2,
	width, height, minDist: f32,
	maxAttempts: int = 30,
) -> [dynamic]float2 {
	assert(width > 0)
	assert(height > 0)
	assert(height > 0)
	assert(maxAttempts > 0)


	cellSize := minDist / math.sqrt(f32(2))
	gridW := int(math.ceil(width / cellSize))
	gridH := int(math.ceil(height / cellSize))

	grid := make([]int, gridW * gridH, context.temp_allocator)
	for i in 0 ..< len(grid) do grid[i] = -1

	points := make([dynamic]float2)
	active := make([dynamic]int, context.temp_allocator)

	// Add initial point
	append(&points, startPos)
	append(&active, 0)
	grid[grid_index(startPos, startPos, cellSize, gridW)] = 0

	for len(active) > 0 {
		idx := rand.int_max(len(active))
		activeIdx := active[idx]
		point := points[activeIdx]
		found := false

		for attempt in 0 ..< maxAttempts {
			angle := rand.float32() * 2 * math.PI
			radius := minDist * (1 + rand.float32())
			newPoint := float2 {
				point.x + radius * math.cos(angle),
				point.y + radius * math.sin(angle),
			}

			if newPoint.x < startPos.x ||
			   newPoint.x >= startPos.x + width ||
			   newPoint.y < startPos.y ||
			   newPoint.y >= startPos.y + height {
				continue
			}

			if is_valid(newPoint, points, grid, startPos, minDist, cellSize, gridW, gridH) {
				newIdx := len(points)
				append(&points, newPoint)
				append(&active, newIdx)
				grid[grid_index(newPoint, startPos, cellSize, gridW)] = newIdx
				found = true
				break
			}
		}

		if !found {
			ordered_remove(&active, idx)
		}
	}

	return points
}

grid_index :: proc(point, startPos: float2, cellSize: f32, gridW: int) -> int {
	x := int((point.x - startPos.x) / cellSize)
	y := int((point.y - startPos.y) / cellSize)
	return y * gridW + x
}

is_valid :: proc(
	point: float2,
	points: [dynamic]float2,
	grid: []int,
	startPos: float2,
	minDist, cellSize: f32,
	gridW, gridH: int,
) -> bool {
	gx := int((point.x - startPos.x) / cellSize)
	gy := int((point.y - startPos.y) / cellSize)

	// Check neighboring cells
	for dy in -2 ..= 2 {
		for dx in -2 ..= 2 {
			nx := gx + dx
			ny := gy + dy
			if nx < 0 || nx >= gridW || ny < 0 || ny >= gridH do continue

			neighborIdx := grid[ny * gridW + nx]
			if neighborIdx != -1 {
				neighbor := points[neighborIdx]
				dist := math.sqrt(
					(point.x - neighbor.x) * (point.x - neighbor.x) +
					(point.y - neighbor.y) * (point.y - neighbor.y),
				)
				if dist < minDist do return false
			}
		}
	}
	return true
}
