package main
import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:path/filepath"
import "core:prof/spall"
import "core:sync"
import "core:time"
import sdl "vendor:sdl3"


sdl_ensure :: proc(cond: bool, message: string = "") {
	msg := fmt.tprintf("%s:%s\n", message, sdl.GetError())
	ensure(cond, msg)
}

float2 :: [2]f32
float3 :: [3]f32
float4 :: [4]f32

ENABLE_SPALL :: true && ODIN_DEBUG
when ODIN_DEBUG && ENABLE_SPALL {
	spall_ctx: spall.Context
	@(thread_local)
	spall_buffer: spall.Buffer


	@(instrumentation_enter)
	spall_enter :: proc "contextless" (
		proc_address, call_site_return_address: rawptr,
		loc: runtime.Source_Code_Location,
	) {
		spall._buffer_begin(&spall_ctx, &spall_buffer, "", "", loc)
	}

	@(instrumentation_exit)
	spall_exit :: proc "contextless" (
		proc_address, call_site_return_address: rawptr,
		loc: runtime.Source_Code_Location,
	) {
		spall._buffer_end(&spall_ctx, &spall_buffer)
	}

}
Scale_3d: f32 = 0.02
Octaves: int = 1
Persistence: f32 = 0.25
Lacunarity: f64 = 3
main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}

		when ENABLE_SPALL {
			spall_ctx = spall.context_create("spall-trace.spall")
			defer spall.context_destroy(&spall_ctx)

			buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
			defer delete(buffer_backing)

			spall_buffer = spall.buffer_create(buffer_backing, u32(sync.current_thread_id()))
			defer spall.buffer_destroy(&spall_ctx, &spall_buffer)
		}

	}
	width := 1280
	height := 720
	sdl_ensure(sdl.Init({.VIDEO, .EVENTS}))
	window = sdl.CreateWindow("Merple", i32(width), i32(height), {.RESIZABLE})
	sdl_ensure(window != nil)
	defer sdl.DestroyWindow(window)
	sdl.SetLogPriorities(.WARN)

	device = sdl.CreateGPUDevice({.SPIRV}, true, nil)
	sdl_ensure(device != nil)
	defer sdl.DestroyGPUDevice(device)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(device, window) != false)

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
	middleOfChunksInNormalCoords := f32((CHUNKS_PER_DIRECTION / 2)) * CHUNK_SIZE + CHUNK_SIZE / 2
	middleOfMiddleChunkPos := float3{middleOfChunksInNormalCoords, 0, middleOfChunksInNormalCoords}
	camera = Camera_new(pos = middleOfMiddleChunkPos)
	chunks_init(&camera)
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

			SCALE_STEP :: f32(0.001)
			PERSIST_STEP :: f32(0.01)
			LACUNARITY_STEP :: f64(0.1)
			OCTAVE_STEP :: 1
			#partial switch e.type {
			case .QUIT:
				quit = true
				break
			case .KEY_DOWN:
				switch e.key.key {
				case sdl.K_ESCAPE:
					quit = true
				case sdl.K_F11:
					flags := sdl.GetWindowFlags(window)
					if .FULLSCREEN in flags {
						sdl.SetWindowFullscreen(window, false)
					} else {
						sdl.SetWindowFullscreen(window, true)
					}
				case sdl.K_J:
					// Scale_3d +
					Scale_3d += SCALE_STEP
					fmt.println("Scale_3d:", Scale_3d)
					chunks_init(&camera)

				case sdl.K_K:
					// Scale_3d -
					Scale_3d -= SCALE_STEP
					fmt.println("Scale_3d:", Scale_3d)
					chunks_init(&camera)

				case sdl.K_U:
					// Octaves +
					Octaves += OCTAVE_STEP
					fmt.println("Octaves:", Octaves)
					chunks_init(&camera)

				case sdl.K_I:
					// Octaves -
					if Octaves > 1 do Octaves -= OCTAVE_STEP
					fmt.println("Octaves:", Octaves)
					chunks_init(&camera)

				case sdl.K_O:
					// Persistence +
					Persistence += PERSIST_STEP
					fmt.println("Persistence:", Persistence)
					chunks_init(&camera)

				case sdl.K_P:
					// Persistence -
					Persistence -= PERSIST_STEP
					fmt.println("Persistence:", Persistence)
					chunks_init(&camera)

				case sdl.K_N:
					// Lacunarity +
					Lacunarity += LACUNARITY_STEP
					fmt.println("Lacunarity:", Lacunarity)
					chunks_init(&camera)

				case sdl.K_M:
					// Lacunarity -
					Lacunarity -= LACUNARITY_STEP
					fmt.println("Lacunarity:", Lacunarity)
					chunks_init(&camera)
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
		chunks_shift_per_player_movement(&camera)
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
