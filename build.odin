package build
import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:unicode/utf8"


SPIRV :: true
DXIL :: false

PRINT_COMMAND :: true

main :: proc() {
	inputDir := filepath.join({"src", "hlsl"})
	outputDir := filepath.join({"./build", "shader-binaries"})
	files, err := os.read_directory_by_path(inputDir, 1024, context.temp_allocator)
	if err != nil do log.fatalf("err trying to read input dir : %v", err)
	defer free_all(context.allocator)
	os.make_directory_all(outputDir)

	w := os.walker_create(inputDir)
	defer os.walker_destroy(&w)
	for file in os.walker_walk(&w) {
		if path, err := os.walker_error(&w); err != nil {
			fmt.eprintfln("failed walking %s: %s", path, err)
			continue
		}
		if !strings.has_suffix(file.fullpath, ".hlsl") do continue
		relPath, relError := filepath.rel(inputDir, file.fullpath)
		if relError != nil {
			log.fatalf("failed getting relative path %s: %s", relPath, err)
			return
		}
		dirOfRelativePath := filepath.dir(relPath)
		actualOutputPath := filepath.join({outputDir, dirOfRelativePath})
		if SPIRV {
			compile_shader(file.fullpath, actualOutputPath, "spv", .vertex)
			compile_shader(file.fullpath, actualOutputPath, "spv", .fragment)
		}

		if DXIL {
			compile_shader(file.fullpath, actualOutputPath, "dxil", .vertex)
			compile_shader(file.fullpath, actualOutputPath, "dxil", .fragment)
		}
	}

}
compile_shader :: proc(path, dir, ext: string, stage: enum {
		vertex,
		fragment,
	}) {
	name := strings.trim_suffix(filepath.base(path), ".hlsl")
	stage := stage == .vertex ? "vertex" : "fragment"
	define := strings.to_upper(stage)
	debugLine := "--debug" when ODIN_DEBUG else ""
	os.make_directory_all(dir)

	exec(
		{
			"shadercross",
			debugLine,
			"--stage",
			string(stage),
			"--output",
			filepath.join({dir, strings.join({name, stage, ext}, ".")}),
			fmt.tprintf("-D%s", define),
			path,
		},
	)
}


exec :: proc(command: []string) {
	if PRINT_COMMAND {
		fmt.printfln(strings.join(command, " "))

	}
	state, stdOut, stdErr, error := os.process_exec(
		os.Process_Desc{working_dir = ".", command = command},
		allocator = context.temp_allocator,
	)

	msg := fmt.tprintf("%s%s", string(stdOut), string(stdErr))
	if state.exit_code != 0 {
		panic(msg)
	} else {
		fmt.print(msg)
	}
}
