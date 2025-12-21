package main
// import "core:fmt"
// import "core:math"
// import "core:math/noise"
// import "core:math/rand"
// import "core:mem"
// import vmem "core:mem/virtual"
// import "vendor:raylib"
// import "vendor:raylib/rlgl"
// import sdl "vendor:sdl3"

// CHUNK_SIZE :: 16
// RENDER_DISTANCE :: 5
// MIN_Y :: -1
// MAX_Y :: 1
// CHUNK_HEIGHT :: MAX_Y - MIN_Y
// DEFAULT_SURFACE_LEVEL :: -1
// X_SIZE :: 100  // World goes from -100 to 100
// Z_SIZE :: 100  // World goes from -100 to 100

// Chunk :: struct {
// 	sbo:           ^sdl.GPUBuffer,
// 	indexBuffer:        ^sdl.GPUBuffer,
// 	points:        [dynamic]Point,
// 	indexes:        [dynamic]u16,
// 	dirty:         bool,
// }

// chunks: map[[2]i32]Chunk
// chunksArena: vmem.Arena
// chunksAlloc: mem.Allocator

// chunks_init :: proc() {
// 	chunksAlloc = vmem.arena_allocator(&chunksArena)
// }


// chunks_cleanup :: proc() {
// 	for _, chunk in chunks {
// 		sdl.ReleaseGPUBuffer(device, chunk.sbo)
// 		sdl.ReleaseGPUBuffer(device, chunk.indexBuffer)
// 	}
// 	free_all(chunksAlloc)
// 	delete(chunks)
// }


// update_loaded_chunks :: proc(camera: ^Camera, chunks: ^map[[2]i32]Chunk) {
// 	assert(chunks != nil)
// 	playerChunk := [2]i32 {
// 		i32(math.floor(f64(camera.pos.x) / CHUNK_SIZE)),
// 		i32(math.floor(f64(camera.pos.z) / CHUNK_SIZE)),
// 	}
// 	toLoad := make([dynamic][2]i32, context.temp_allocator)
// 	for cx := playerChunk[0] - RENDER_DISTANCE; cx <= playerChunk[0] + RENDER_DISTANCE; cx += 1 {
// 		for cz := playerChunk[1] - RENDER_DISTANCE;
// 		    cz <= playerChunk[1] + RENDER_DISTANCE;
// 		    cz += 1 {
// 			key := [2]i32{cx, cz}
// 			if key not_in chunks^ {
// 				append(&toLoad, key)
// 			}
// 		}
// 	}
// 	HYSTERESIS :: 2
// 	toUnload := make([dynamic][2]i32, context.temp_allocator)
// 	for key in chunks {
// 		dx := math.abs(key[0] - playerChunk[0])
// 		dz := math.abs(key[1] - playerChunk[1])
// 		if dx > RENDER_DISTANCE + HYSTERESIS || dz > RENDER_DISTANCE + HYSTERESIS {
// 			append(&toUnload, key)
// 		}
// 	}
// 	for key in toUnload {
// 		chunk := chunks^[key]
// 		assert(chunk.sbo != nil)
// 		assert(chunk.indexBuffer != nil)
// 		sdl.ReleaseGPUBuffer(device, chunk.sbo)
// 		sdl.ReleaseGPUBuffer(device, chunk.indexBuffer)
// 		delete(chunk.points)
// 		delete(chunk.indexes)
// 		delete_key(chunks, key)
// 	}
// 	for key in toLoad {
// 		generate_chunk(key, chunks)
// 	}
// 	for key, &c in chunks {
// 		if c.dirty {
// 			rebuild_visible(&c, key, chunks)
// 		}
// 	}
// }
