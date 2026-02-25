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
import vk "vendor:vulkan"

Point_r: struct {
	pipeline: ^sdl.GPUGraphicsPipeline,
} = {}


// BottomFacedVertices := [4]float3 {
//     {-0.5, -0.5, 0.5},
//     {-0.5, -0.5, -0.5},
//     {0.5, -0.5, -0.5},
//     {0.5, -0.5, 0.5},
// }
when VISUAL_REPRESENTATION_OF_NOISE_FN_RUN {
	PointType :: f32
} else {
	PointType :: enum {
		Air,
		YellowDirt,
		PurpleGround,
		LightPurpleGround,
		BlueDiamond,
		BlackCliff,
		PinkTrunk,
		WhiteTreeLeaf,
		Water,
	}
	Random_Colors_Per_Point_Type := [PointType][5][4]f32 {
		.Air               = {{}, {}, {}, {}, {}},
		.YellowDirt        = {
			{159, 112, 75, 1},
			{154, 107, 70, 1},
			{157, 110, 73, 1},
			{153, 106, 69, 1},
			{155, 108, 71, 1},
		},
		.PurpleGround      = {
			{36, 19, 97, 1},
			{33, 16, 94, 1},
			{31, 14, 92, 1},
			{28, 11, 89, 1},
			{34, 17, 95, 1},
		},
		.LightPurpleGround = {
			{141, 97, 237, 1},
			{144, 100, 240, 1},
			{138, 94, 234, 1},
			{142, 98, 238, 1},
			{143, 99, 239, 1},
		},
		.BlueDiamond       = {
			{0, 236, 231, 1},
			{3, 241, 236, 1},
			{2, 240, 235, 1},
			{0, 234, 229, 1},
			{2, 240, 235, 1},
		},
		.BlackCliff        = {
			{31, 22, 25, 1},
			{26, 17, 20, 1},
			{24, 15, 18, 1},
			{25, 16, 19, 1},
			{25, 16, 19, 1},
		},
		.PinkTrunk         = {
			{229, 108, 125, 1},
			{227, 106, 123, 1},
			{226, 105, 122, 1},
			{229, 108, 125, 1},
			{232, 111, 128, 1},
		},
		.WhiteTreeLeaf     = {
			{218, 189, 252, 1},
			{216, 187, 250, 1},
			{214, 185, 248, 1},
			{221, 192, 255, 1},
			{222, 193, 255, 1},
		},
		.Water             = {
			{68, 131, 129, 1},
			{68, 131, 129, 1},
			{63, 126, 124, 1},
			{69, 132, 130, 1},
			{68, 131, 129, 1},
		},
	}
}
BottomFacedIndices := [?]u16{0, 1, 2, 0, 2, 3}
PipelineData :: struct {
	descriptorSetLayout: vk.DescriptorSetLayout,
	layout:              vk.PipelineLayout,
	graphicsPipeline:    vk.Pipeline,
}

point_pipeline_init :: proc() -> (p: PipelineData) {

	// --- Descriptor layout (matches SDL shader usage) ---
	descLayoutBindings := [?]vk.DescriptorSetLayoutBinding {
		// binding 0 → vertex uniform buffer
		{
			binding = 0,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			stageFlags = {.VERTEX},
		},
		// binding 1 → fragment storage buffer
		{
			binding = 1,
			descriptorType = .STORAGE_BUFFER,
			descriptorCount = 1,
			stageFlags = {.FRAGMENT},
		},
	}

	vk_chk(
		vk.CreateDescriptorSetLayout(
			vkDevice,
			&vk.DescriptorSetLayoutCreateInfo {
				sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
				flags = {.PUSH_DESCRIPTOR_KHR},
				bindingCount = len(descLayoutBindings),
				pBindings = raw_data(descLayoutBindings[:]),
			},
			nil,
			&p.descriptorSetLayout,
		),
	)

	// --- Load shaders ---
	VERT_SPV :: #load("../build/shader-binaries/point.vertex.spv")
	FRAG_SPV :: #load("../build/shader-binaries/point.fragment.spv")

	vertModule := create_shader_module(vkDevice, VERT_SPV)
	fragModule := create_shader_module(vkDevice, FRAG_SPV)

	defer vk.DestroyShaderModule(vkDevice, vertModule, nil)
	defer vk.DestroyShaderModule(vkDevice, fragModule, nil)
	// --- Pipeline layout ---
	vk_chk(
		vk.CreatePipelineLayout(
			vkDevice,
			&vk.PipelineLayoutCreateInfo {
				sType = .PIPELINE_LAYOUT_CREATE_INFO,
				setLayoutCount = 1,
				pSetLayouts = &p.descriptorSetLayout,
			},
			nil,
			&p.layout,
		),
	)

	// --- Vertex input (float3 at location 0) ---
	viBindings := [?]vk.VertexInputBindingDescription {
		{binding = 0, stride = size_of([3]f32), inputRate = .VERTEX},
	}

	vaDescriptors := [?]vk.VertexInputAttributeDescription {
		{location = 0, binding = 0, format = .R32G32B32_SFLOAT, offset = 0},
	}

	dynamicStates := [?]vk.DynamicState{.VIEWPORT, .SCISSOR}

	pipelineStages := [?]vk.PipelineShaderStageCreateInfo {
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.VERTEX},
			module = vertModule,
			pName = "main",
		},
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.FRAGMENT},
			module = fragModule,
			pName = "main",
		},
	}

	// --- Graphics pipeline ---
	vk_chk(
		vk.CreateGraphicsPipelines(
			vkDevice,
			{},
			1,
			&vk.GraphicsPipelineCreateInfo {
				sType = .GRAPHICS_PIPELINE_CREATE_INFO,
				pNext = &vk.PipelineRenderingCreateInfo {
					sType = .PIPELINE_RENDERING_CREATE_INFO,
					colorAttachmentCount = 1,
					pColorAttachmentFormats = &vkSwapchainImageFormat,
					depthAttachmentFormat = vkDepthFormat,
				},
				stageCount = len(pipelineStages),
				pStages = raw_data(pipelineStages[:]),
				pVertexInputState = &vk.PipelineVertexInputStateCreateInfo {
					sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
					vertexBindingDescriptionCount = len(viBindings),
					pVertexBindingDescriptions = raw_data(viBindings[:]),
					vertexAttributeDescriptionCount = len(vaDescriptors),
					pVertexAttributeDescriptions = raw_data(vaDescriptors[:]),
				},
				pInputAssemblyState = &vk.PipelineInputAssemblyStateCreateInfo {
					sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
					topology = .TRIANGLE_LIST,
				},
				pViewportState = &vk.PipelineViewportStateCreateInfo {
					sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
					viewportCount = 1,
					scissorCount = 1,
				},
				pRasterizationState = &vk.PipelineRasterizationStateCreateInfo {
					sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
					lineWidth = 1.0,
					cullMode = {.BACK},
					frontFace = .COUNTER_CLOCKWISE,
				},
				pMultisampleState = &vk.PipelineMultisampleStateCreateInfo {
					sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
					rasterizationSamples = {._1},
				},
				pDepthStencilState = &vk.PipelineDepthStencilStateCreateInfo {
					sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
					depthTestEnable = true,
					depthWriteEnable = true,
					depthCompareOp = .LESS,
				},
				pColorBlendState = &vk.PipelineColorBlendStateCreateInfo {
					sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
					attachmentCount = 1,
					pAttachments = &vk.PipelineColorBlendAttachmentState {
						colorWriteMask = {.R, .G, .B, .A},
					},
				},
				pDynamicState = &vk.PipelineDynamicStateCreateInfo {
					sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
					dynamicStateCount = len(dynamicStates),
					pDynamicStates = raw_data(dynamicStates[:]),
				},
				layout = p.layout,
			},
			nil,
			&p.graphicsPipeline,
		),
	)


	return p
}


pipeline_data_delete :: proc(p: PipelineData) {
	if p.descriptorSetLayout != {} do vk.DestroyDescriptorSetLayout(vkDevice, p.descriptorSetLayout, nil)

	if p.layout != {} do vk.DestroyPipelineLayout(vkDevice, p.layout, nil)

	if p.graphicsPipeline != {} do vk.DestroyPipeline(vkDevice, p.graphicsPipeline, nil)

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
