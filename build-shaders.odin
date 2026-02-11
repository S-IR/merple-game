package build

import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:strings"

SPIRV :: true
// DXIL :: false
PRINT_COMMAND :: true

main :: proc() {
	inputDir := filepath.join({"src", "glsl"})
	outputDir := filepath.join({"./build", "shader-binaries"})

	cwd, err := os.get_executable_directory(context.temp_allocator)
	if err != nil do log.panicf("error getting cwd %s", os.error_string(err))

	inputDir = filepath.join({cwd, inputDir})
	outputDir = filepath.join({cwd, outputDir})

	if !os.exists(outputDir) {
		if err := os.make_directory_all(outputDir); err != nil {
			panic(os.error_string(err))
		}
	}

	w := os.walker_create(inputDir)
	defer os.walker_destroy(&w)

	for file in os.walker_walk(&w) {
		if path, err := os.walker_error(&w); err != nil {
			fmt.eprintfln("failed walking %s: %s", path, err)
			continue
		}

		if !strings.has_suffix(file.fullpath, ".glsl") do continue

		relPath, relErr := filepath.rel(inputDir, file.fullpath)
		if relErr != nil {
			log.fatalf("failed getting relative path %s: %v", file.fullpath, relErr)
		}

		dirOfRelativePath := filepath.dir(relPath)
		actualOutputPath := filepath.join({outputDir, dirOfRelativePath})

		if SPIRV {
			compile_shader(file.fullpath, actualOutputPath, "spv", .vertex)
			compile_shader(file.fullpath, actualOutputPath, "spv", .fragment)
		}
		// if DXIL {
		// 	// add later if you integrate dxc.exe
		// }
	}
}

compile_shader :: proc(path, dir, ext: string, stage: enum {
		vertex,
		fragment,
	}) {
	name := strings.trim_suffix(filepath.base(path), ".glsl")
	stageStr := stage == .vertex ? "vert" : "frag"
	define := stage == .vertex ? "VERTEX" : "FRAGMENT"
	debugLine := "-g" when ODIN_DEBUG else ""

	os.make_directory_all(dir)

	exec(
		{
			"glslangValidator",
			"-V",
			debugLine,
			"-o",
			filepath.join({dir, strings.join({name, stageStr, ext}, ".")}),
			"-S",
			stageStr,
			fmt.tprintf("-D%s", define),
			path,
		},
	)
}

exec :: proc(command: []string) {
	if PRINT_COMMAND {
		fmt.printfln(strings.join(command, " "))
	}

	state, stdOut, stdErr, err := os.process_exec(
		os.Process_Desc{working_dir = ".", command = command},
		allocator = context.temp_allocator,
	)
	if err != nil {
		panic(fmt.tprintf("error executing command %v : %s", command, os.error_string(err)))
	}

	msg := fmt.tprintf("%s%s", string(stdOut), string(stdErr))
	if state.exit_code != 0 {
		panic(msg)
	}
	fmt.print(msg)
}
