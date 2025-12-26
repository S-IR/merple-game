package main
import "algorithms"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:path/filepath"
import "core:time"
import sdl "vendor:sdl3"


Point :: struct {
	pos:  float3,
	_pad: u32,
}


Point_r: struct {
	pipeline:                                 ^sdl.GPUGraphicsPipeline,
	positionsSBO, triangleColorsSBO, indices: ^sdl.GPUBuffer,
	totalPoints:                              u32,
	totalIndices:                             u32,
} = {}
POINT_VERTEX_SHADER_SPV :: #load("../build/shader-binaries/point.vertex.spv")
POINT_FRAGMENT_SHADER_SPV :: #load("../build/shader-binaries/point.fragment.spv")


// BottomFacedVertices := [4]float3 {
// 	{-0.5, -0.5, 0.5},
// 	{-0.5, -0.5, -0.5},
// 	{0.5, -0.5, -0.5},
// 	{0.5, -0.5, 0.5},
// }

BottomFacedIndices := [?]u16{0, 1, 2, 0, 2, 3}

RANDOM_RED_OPTIONS := [?]float4 {
	{1, 0, 0, 1},
	{.8, 0, 0, 1},
	{.6, 0, 0, 1},
	{.4, 0, 0, 1},
	{.2, 0, 0, 1},
}

Vertices_pipeline_init :: proc() {

	GRID_WIDTH :: f32(10)
	GRID_HEIGHT :: f32(10)
	WIDTH_OF_CELL :: f32(0.5)

	cellsX :: int(GRID_WIDTH / WIDTH_OF_CELL)
	cellsY :: int(GRID_HEIGHT / WIDTH_OF_CELL)

	// Create point array
	Points := [cellsX][cellsY]Point{}
	PointIndices := [cellsX - 1][cellsY - 1][len(BottomFacedIndices)]u16{}
	TriangleColors := [cellsX - 1][cellsY - 1][len(BottomFacedIndices) / 3]float4{}

	// Helper index function
	idx :: proc(x, y: int) -> u16 {
		return u16(y * cellsX + x)
	}

	// Populate points with random positions inside each cell
	for x in 0 ..< cellsX {
		for y in 0 ..< cellsY {
			cell_center_x := f32(x) * WIDTH_OF_CELL + WIDTH_OF_CELL * 0.5
			cell_center_z := f32(y) * WIDTH_OF_CELL + WIDTH_OF_CELL * 0.5

			rx := (rand.float32() - 0.5) * WIDTH_OF_CELL * 0.8
			rz := (rand.float32() - 0.5) * WIDTH_OF_CELL * 0.8

			Points[x][y].pos = float3{cell_center_x + rx, -1, cell_center_z + rz}

		}
	}

	// Create triangles using neighbors
	for x in 0 ..< (cellsX - 1) {
		for y in 0 ..< (cellsY - 1) {
			PointIndices[x][y] = {
				idx(x, y),
				idx(x + 1, y),
				idx(x + 1, y + 1),
				idx(x, y),
				idx(x + 1, y + 1),
				idx(x, y + 1),
			}

			for i in 0 ..< len(TriangleColors[x][y]) {
				TriangleColors[x][y][i] = rand.choice(RANDOM_RED_OPTIONS[:])
			}
		}
	}
	format := sdl.GetGPUShaderFormats(device)

	vertexShader := sdl.CreateGPUShader(
		device,
		sdl.GPUShaderCreateInfo {
			code = raw_data(POINT_VERTEX_SHADER_SPV),
			code_size = len(POINT_VERTEX_SHADER_SPV),
			entrypoint = "main",
			format = format,
			stage = .VERTEX,
			num_samplers = 0,
			num_uniform_buffers = 1,
			num_storage_buffers = 1,
			num_storage_textures = 0,
		},
	)
	sdl_ensure(vertexShader != nil)
	fragmentShader := sdl.CreateGPUShader(
		device,
		sdl.GPUShaderCreateInfo {
			code = raw_data(POINT_FRAGMENT_SHADER_SPV),
			code_size = len(POINT_FRAGMENT_SHADER_SPV),
			entrypoint = "main",
			format = format,
			stage = .FRAGMENT,
			num_samplers = 0,
			num_uniform_buffers = 0,
			num_storage_buffers = 1,
			num_storage_textures = 0,
		},
	)
	color_target_descriptions := [?]sdl.GPUColorTargetDescription {
		{format = sdl.GetGPUSwapchainTextureFormat(device, window)},
	}
	Point_r.pipeline = sdl.CreateGPUGraphicsPipeline(
		device,
		sdl.GPUGraphicsPipelineCreateInfo {
			target_info = {
				num_color_targets = len(color_target_descriptions),
				color_target_descriptions = raw_data(color_target_descriptions[:]),
				has_depth_stencil_target = true,
				depth_stencil_format = .D24_UNORM,
			},
			depth_stencil_state = sdl.GPUDepthStencilState {
				enable_depth_test = true,
				enable_depth_write = true,
				enable_stencil_test = false,
				compare_op = .LESS,
				write_mask = 0xFF,
			},
			primitive_type = .TRIANGLELIST,
			vertex_shader = vertexShader,
			fragment_shader = fragmentShader,
		},
	)

	Point_r.positionsSBO = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.GRAPHICS_STORAGE_READ}, size = size_of(Points)},
	)

	sdl_ensure(Point_r.positionsSBO != nil)
	sdl.SetGPUBufferName(device, Point_r.positionsSBO, "point positions")
	gpu_buffer_upload(&Point_r.positionsSBO, raw_data(Points[:]), size_of(Points))
	Point_r.totalPoints = size_of(Points) / size_of(Point)

	Point_r.indices = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = size_of(PointIndices)},
	)
	sdl_ensure(Point_r.indices != nil)
	sdl.SetGPUBufferName(device, Point_r.indices, "indices")
	gpu_buffer_upload(&Point_r.indices, raw_data(PointIndices[:]), size_of(PointIndices))
	Point_r.totalIndices = size_of(PointIndices) / size_of(u16)


	Point_r.triangleColorsSBO = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.GRAPHICS_STORAGE_READ}, size = size_of(TriangleColors)},
	)

	sdl_ensure(Point_r.triangleColorsSBO != nil)
	sdl.SetGPUBufferName(device, Point_r.triangleColorsSBO, "triangle colors")
	gpu_buffer_upload(
		&Point_r.triangleColorsSBO,
		raw_data(TriangleColors[:]),
		size_of(TriangleColors),
	)


	assert(Point_r.pipeline != nil)
	assert(Point_r.positionsSBO != nil)
	assert(Point_r.triangleColorsSBO != nil)
	assert(Point_r.indices != nil)


}

points_draw :: proc(render_pass: ^^sdl.GPURenderPass, view_proj: matrix[4, 4]f32) {
	assert(render_pass != nil && render_pass^ != nil)
	assert(Point_r.positionsSBO != nil)
	assert(Point_r.triangleColorsSBO != nil)

	assert(Point_r.totalIndices > 0)
	assert(Point_r.totalPoints > 0)


	sdl.BindGPUGraphicsPipeline(render_pass^, Point_r.pipeline)

	sdl.BindGPUIndexBuffer(render_pass^, {buffer = Point_r.indices, offset = 0}, ._16BIT)

	sbosVertex := [?]^sdl.GPUBuffer{Point_r.positionsSBO}
	sdl.BindGPUVertexStorageBuffers(render_pass^, 0, raw_data(sbosVertex[:]), len(sbosVertex))
	sbosFragment := [?]^sdl.GPUBuffer{Point_r.triangleColorsSBO}
	sdl.BindGPUFragmentStorageBuffers(
		render_pass^,
		0,
		raw_data(sbosFragment[:]),
		len(sbosFragment),
	)

	sdl.DrawGPUIndexedPrimitives(render_pass^, Point_r.totalIndices, Point_r.totalPoints, 0, 0, 0)

}

Vertices_pipeline_release :: proc() {
	sdl.ReleaseGPUGraphicsPipeline(device, Point_r.pipeline);Point_r.pipeline = nil
	sdl.ReleaseGPUBuffer(device, Point_r.positionsSBO);Point_r.positionsSBO = nil
	sdl.ReleaseGPUBuffer(device, Point_r.triangleColorsSBO);Point_r.triangleColorsSBO = nil
	sdl.ReleaseGPUBuffer(device, Point_r.indices);Point_r.indices = nil
}
