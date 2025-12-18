package main
import sdl "vendor:sdl3"


screenWidth: i32 = 1280
screenHeight: i32 = 720

seed: u64 = 123
device: ^sdl.GPUDevice
window: ^sdl.Window


camera: Camera
dt: f64


near_plane: f32 : 0.2
far_plane: f32 : 160.0
