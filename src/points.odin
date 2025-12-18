package main
import "core:fmt"
import "core:math/linalg"
import "core:mem"
import "core:path/filepath"
import "core:time"
import sdl "vendor:sdl3"

PointType :: enum u8 {
	TODO,
}
TOTAL_POINTS :: 4
PointSBO :: struct {
	pos:   float3,
	type:  u8,
	color: float4,
}
Points := [TOTAL_POINTS]PointSBO {
	{
		{-0.5, -0.5, 0.5},
		0,
		{1, 0, 0, 1},
	},
	{
		{-0.5, -0.5, -0.5},
		0,
		{0, 1, 0, 1},
	},
	{
		{0.5, -0.5, -0.5},
		0,
		{0, 0, 1, 1},
	},
	{
		{0.5, -0.5, 0.5},
		0,
		{1, 1, 0, 1},
	},
}
PointIndices := [?]u16{0, 1, 2, 0, 2, 3}


Point_r: struct {
	pipeline:                   ^sdl.GPUGraphicsPipeline,
	sbo, indices: ^sdl.GPUBuffer,
} = {}
POINT_VERTEX_SHADER_SPV :: #load("../build/shader-binaries/point.vertex.spv")
POINT_FRAGMENT_SHADER_SPV :: #load("../build/shader-binaries/point.fragment.spv")


Vertices_pipeline_init :: proc() {
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
			num_storage_buffers = 0,
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

	Point_r.sbo = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.GRAPHICS_STORAGE_READ}, size = size_of(Points)},
	)
	sdl_ensure(Point_r.sbo != nil)
	sdl.SetGPUBufferName(device, Point_r.sbo, "sbo")
	gpu_buffer_upload(&Point_r.sbo, raw_data(Points[:]), size_of(Points))


	Point_r.indices = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = size_of(PointIndices)},
	)
	sdl_ensure(Point_r.indices != nil)
	sdl.SetGPUBufferName(device, Point_r.indices, "indices")
	gpu_buffer_upload(&Point_r.indices, raw_data(PointIndices[:]), size_of(PointIndices))

	assert(Point_r.pipeline != nil)
	assert(Point_r.sbo != nil)
	assert(Point_r.indices != nil)

}

points_draw :: proc(render_pass: ^^sdl.GPURenderPass, view_proj: matrix[4, 4]f32) {
	assert(render_pass != nil && render_pass^ != nil)
	assert(Point_r.sbo != nil)


	sdl.BindGPUGraphicsPipeline(render_pass^, Point_r.pipeline)

	sdl.BindGPUIndexBuffer(render_pass^, {buffer = Point_r.indices, offset = 0}, ._16BIT)

	storageBuffers := [?]^sdl.GPUBuffer{Point_r.sbo}
	sdl.BindGPUVertexStorageBuffers(
		render_pass^,
		0,
		raw_data(storageBuffers[:]),
		len(storageBuffers),
	)
	sdl.DrawGPUIndexedPrimitives(
		render_pass^,
		u32(len(PointIndices)),
		len(Points),
		0,
		0,
		0,
	)

}

Vertices_pipeline_release :: proc() {
	sdl.ReleaseGPUGraphicsPipeline(device, Point_r.pipeline); Point_r.pipeline = nil
	sdl.ReleaseGPUBuffer(device, Point_r.sbo); Point_r.sbo = nil
	sdl.ReleaseGPUBuffer(device, Point_r.indices); Point_r.indices = nil
}
