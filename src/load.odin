package main
import "core:fmt"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"
// ShaderInfo :: struct {
// 	samplers, UBOs, SBOs, STOs: u32,
// }
// load_shader :: proc(code: []u8, stage: sdl.GPUShaderStage, info: ShaderInfo) -> ^sdl.GPUShader {
// 	assert(code != nil)

// 	format := sdl.GetGPUShaderFormats(device)
// 	entrypoint: cstring
// 	if format >= {.SPIRV} || format >= {.DXIL} {
// 		entrypoint = "main"
// 	} else {
// 		panic("unsupported backend shader format")
// 	}

// 	codeSize: uint = len(code)

// 	shader := sdl.CreateGPUShader(
// 		device,
// 		sdl.GPUShaderCreateInfo {
// 			code = raw_data(code),
// 			code_size = codeSize,
// 			entrypoint = entrypoint,
// 			format = format,
// 			stage = stage,
// 			num_samplers = info.samplers,
// 			num_uniform_buffers = info.UBOs,
// 			num_storage_buffers = info.SBOs,
// 			num_storage_textures = info.STOs,
// 		},
// 	)
// 	sdl_ensure(shader != nil)
// 	return shader

// }
// gpu_buffer_upload :: proc(buffer: ^^sdl.GPUBuffer, data: rawptr, size: uint) {
// 	transferBuffer := sdl.CreateGPUTransferBuffer(device, {usage = .UPLOAD, size = u32(size)})
// 	defer sdl.ReleaseGPUTransferBuffer(device, transferBuffer)

// 	transferData := sdl.MapGPUTransferBuffer(device, transferBuffer, true)
// 	sdl.memcpy(transferData, data, size)
// 	sdl.UnmapGPUTransferBuffer(device, transferBuffer)

// 	uploadCmdBuf := sdl.AcquireGPUCommandBuffer(device)
// 	copyPass := sdl.BeginGPUCopyPass(uploadCmdBuf)
// 	sdl.UploadToGPUBuffer(
// 		copyPass,
// 		{transfer_buffer = transferBuffer, offset = 0},
// 		{buffer = buffer^, offset = 0, size = u32(size)},
// 		false,
// 	)

// 	sdl.EndGPUCopyPass(copyPass)
// 	sdl_ensure(sdl.SubmitGPUCommandBuffer(uploadCmdBuf) != false)
// }
// gpu_buffer_upload_batch :: proc(buffers: []^^sdl.GPUBuffer, datas: []rawptr, sizes: []uint) {
// 	assert(len(buffers) == len(datas) && len(datas) == len(sizes))
// 	if (len(buffers) == 0) do return
// 	totalSize: uint = 0
// 	for s in sizes do totalSize += s

// 	assert(totalSize > 0)
// 	assert(totalSize < uint(max(u32)))
// 	transferBuffer := sdl.CreateGPUTransferBuffer(device, {usage = .UPLOAD, size = u32(totalSize)})
// 	defer sdl.ReleaseGPUTransferBuffer(device, transferBuffer)


// 	mapped := sdl.MapGPUTransferBuffer(device, transferBuffer, true)
// 	offset: uint = 0
// 	for i in 0 ..< len(datas) {
// 		assert(sizes[i] != 0)
// 		mem.copy(rawptr(uintptr(mapped) + uintptr(offset)), datas[i], int(sizes[i]))
// 		offset += sizes[i]
// 	}
// 	sdl.UnmapGPUTransferBuffer(device, transferBuffer)
// 	uploadCmdBuf := sdl.AcquireGPUCommandBuffer(device)
// 	copyPass := sdl.BeginGPUCopyPass(uploadCmdBuf)


// 	currOffset := uint(0)
// 	for i in 0 ..< len(buffers) {
// 		assert(sizes[i] != 0)
// 		sdl.UploadToGPUBuffer(
// 			copyPass,
// 			{transfer_buffer = transferBuffer, offset = u32(currOffset)},
// 			{buffer = buffers[i]^, offset = 0, size = u32(sizes[i])},
// 			true,
// 		)
// 		currOffset += sizes[i]
// 	}
// 	sdl.EndGPUCopyPass(copyPass)
// 	sdl_ensure(sdl.SubmitGPUCommandBuffer(uploadCmdBuf) != false)

// }
