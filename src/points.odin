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

PointType :: enum (u16) {
	Air,
	Ground,
}
//last 6 bytes represents the corruption state
Point :: u16


Point_r: struct {
	pipeline: ^sdl.GPUGraphicsPipeline,
} = {}
POINT_VERTEX_SHADER_SPV :: #load("../build/shader-binaries/point.vertex.spv")
POINT_FRAGMENT_SHADER_SPV :: #load("../build/shader-binaries/point.fragment.spv")


// BottomFacedVertices := [4]float3 {
//     {-0.5, -0.5, 0.5},
//     {-0.5, -0.5, -0.5},
//     {0.5, -0.5, -0.5},
//     {0.5, -0.5, 0.5},
// }

BottomFacedIndices := [?]u16{0, 1, 2, 0, 2, 3}


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
			num_storage_buffers = 0,
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

	vertexAttributes := [?]sdl.GPUVertexAttribute {
		{location = 0, format = .FLOAT3, offset = 0, buffer_slot = 0},
	}

	vertexBufferDescriptions := [?]sdl.GPUVertexBufferDescription {
		{slot = 0, pitch = size_of(float3), input_rate = .VERTEX},
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
			vertex_input_state = sdl.GPUVertexInputState {
				num_vertex_buffers = len(vertexBufferDescriptions),
				vertex_buffer_descriptions = raw_data(vertexBufferDescriptions[:]),
				num_vertex_attributes = len(vertexAttributes),
				vertex_attributes = raw_data(vertexAttributes[:]),
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


}


Vertices_pipeline_release :: proc() {
	sdl.ReleaseGPUGraphicsPipeline(device, Point_r.pipeline); Point_r.pipeline = nil

}

// is_point_visible :: proc(chunk: ^Chunk, x, y, z: int) -> bool {
// 	p := chunk.points[x][y][z]
// 	if p.type == .Air {
// 		return false
// 	}

// 	dirs := [][3]int{{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}

// 	for d in dirs {
// 		nx := x + d[0]
// 		ny := y + d[1]
// 		nz := z + d[2]

// 		if nx < 0 ||
// 		   nx >= POINTS_PER_X_DIR ||
// 		   ny < 0 ||
// 		   ny >= POINTS_PER_Y_DIR ||
// 		   nz < 0 ||
// 		   nz >= POINTS_PER_Z_DIR {
// 			return true
// 		}

// 		if chunk.points[nx][ny][nz].type == .Air {
// 			return true
// 		}
// 	}

// 	return false
// }

// get_visible_points :: proc(chunk: ^Chunk, alloc := context.temp_allocator) -> [dynamic]int3 {
// 	visibles := make([dynamic]int3, 0, alloc)

// 	for x in 0 ..< POINTS_PER_X_DIR {
// 		for y in 0 ..< POINTS_PER_Y_DIR {
// 			for z in 0 ..< POINTS_PER_Z_DIR {
// 				if is_point_visible(chunk, x, y, z) {
// 					append(&visibles, int3{i32(x), i32(y), i32(z)})
// 				}
// 			}
// 		}
// 	}

// 	return visibles
// }
