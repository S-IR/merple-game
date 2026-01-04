package main
import "core:fmt"
import "core:math/rand"
import "core:path/filepath"
import "core:time"
import sdl "vendor:sdl3"

sdl_ensure :: proc(cond: bool, message: string = "") {
	msg := fmt.tprintf("%s:%s\n", message, sdl.GetError())
	ensure(cond, msg)
}

float2 :: [2]f32
float3 :: [3]f32
float4 :: [4]f32


main :: proc() {

	width := 1280
	height := 720
	sdl_ensure(sdl.Init({.VIDEO}))
	window = sdl.CreateWindow("Learn SDL Gpu", i32(width), i32(height), {.RESIZABLE})
	sdl_ensure(window != nil)
	defer sdl.DestroyWindow(window)
	sdl.SetLogPriorities(.WARN)

	device = sdl.CreateGPUDevice({.SPIRV}, true, nil)
	sdl_ensure(device != nil)
	defer sdl.DestroyGPUDevice(device)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(device, window) != false)

	chunks_init()
	defer chunks_release()
	Vertices_pipeline_init()
	defer Vertices_pipeline_release()
	depthTexture := sdl.CreateGPUTexture(
		device,
		sdl.GPUTextureCreateInfo {
			type = .D2,
			width = u32(screenWidth),
			height = u32(screenHeight),
			layer_count_or_depth = 1,
			num_levels = 1,
			sample_count = ._1,
			format = .D24_UNORM,
			usage = {.DEPTH_STENCIL_TARGET},
		},
	)
	defer sdl.ReleaseGPUTexture(device, depthTexture)
	e: sdl.Event
	quit := false

	free_all(context.temp_allocator)
	lastFrameTime := time.now()
	FPS :: 144
	frameTime := time.Duration(time.Second / FPS)

	currRotationAngle: f32 = 0
	ROTATION_SPEED :: 90

	prevScreenWidth := screenWidth
	prevScreenHeight := screenHeight
	rand.reset(seed)
	camera = Camera_new()
	for !quit {

		defer free_all(context.temp_allocator)
		defer {
			frameEnd := time.now()
			frameDuration := time.diff(frameEnd, lastFrameTime)


			if frameDuration < frameTime {
				sleepTime := frameTime - frameDuration
				time.sleep(sleepTime)
			}

			dt = time.duration_seconds(time.since(lastFrameTime))
			lastFrameTime = time.now()
		}

		for sdl.PollEvent(&e) {


			#partial switch e.type {
			case .QUIT:
				quit = true
				break
			case .KEY_DOWN:
				if e.key.key == sdl.K_ESCAPE {
					quit = true
				} else if e.key.key == sdl.K_F11 {
					flags := sdl.GetWindowFlags(window)
					if .FULLSCREEN in flags {
						sdl.SetWindowFullscreen(window, false)
					} else {
						sdl.SetWindowFullscreen(window, true)
					}
				}

			case .WINDOW_RESIZED:
				screenWidth, screenHeight = e.window.data1, e.window.data2
			case .MOUSE_MOTION:
				Camera_process_mouse_movement(&camera, e.motion.xrel, e.motion.yrel)
			case:
				continue
			}
		}
		if prevScreenWidth != screenWidth || prevScreenHeight != screenHeight {
			sdl.SetWindowSize(window, screenWidth, screenHeight)

			sdl.ReleaseGPUTexture(device, depthTexture)
			depthTexture = sdl.CreateGPUTexture(
				device,
				sdl.GPUTextureCreateInfo {
					type = .D2,
					width = u32(screenWidth),
					height = u32(screenHeight),
					layer_count_or_depth = 1,
					num_levels = 1,
					sample_count = ._1,
					format = .D24_UNORM,
					usage = {.DEPTH_STENCIL_TARGET},
				},
			)

			sdl.SyncWindow(window)
			prevScreenWidth = screenWidth
			prevScreenHeight = screenHeight
		}

		Camera_process_keyboard_movement(&camera)

		cmdBuf := sdl.AcquireGPUCommandBuffer(device)
		if cmdBuf == nil do continue
		defer sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdBuf) != false)

		swapTexture: ^sdl.GPUTexture
		if sdl.WaitAndAcquireGPUSwapchainTexture(cmdBuf, window, &swapTexture, nil, nil) == false do continue
		color_target_info := sdl.GPUColorTargetInfo {
			texture     = swapTexture,
			clear_color = {0.6, 0.8, 1.0, 1.0},
			load_op     = .CLEAR,
			store_op    = .STORE,
		}
		depth_stencil_target_info: sdl.GPUDepthStencilTargetInfo = {
			texture          = depthTexture,
			cycle            = true,
			clear_depth      = 1,
			clear_stencil    = 0,
			load_op          = .CLEAR,
			store_op         = .STORE,
			stencil_load_op  = .CLEAR,
			stencil_store_op = .STORE,
		}


		render_pass := sdl.BeginGPURenderPass(
			cmdBuf,
			&color_target_info,
			1,
			&depth_stencil_target_info,
		)


		view, proj := Camera_view_proj(&camera)
		view_proj := proj * view
		sdl.PushGPUVertexUniformData(cmdBuf, 0, &view_proj, size_of(view_proj))
		chunks_draw(&render_pass, proj * view)
		sdl.EndGPURenderPass(render_pass)
	}
}
