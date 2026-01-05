package main
cubeVertices := [8]float3 {
	{-0.5, -0.5, 0.5}, // 0: front bottom left
	{0.5, -0.5, 0.5}, // 1: front bottom right
	{0.5, 0.5, 0.5}, // 2: front top right
	{-0.5, 0.5, 0.5}, // 3: front top left
	{-0.5, -0.5, -0.5}, // 4: back bottom left
	{0.5, -0.5, -0.5}, // 5: back bottom right
	{0.5, 0.5, -0.5}, // 6: back top right
	{-0.5, 0.5, -0.5}, // 7: back top left
}

cubeIndices := [36]u16 {
	// Front face
	0,
	1,
	2,
	0,
	2,
	3,
	// Back face
	5,
	4,
	7,
	5,
	7,
	6,
	// Right face
	1,
	5,
	6,
	1,
	6,
	2,
	// Left face
	4,
	0,
	3,
	4,
	3,
	7,
	// Top face
	3,
	2,
	6,
	3,
	6,
	7,
	// Bottom face
	4,
	5,
	1,
	4,
	1,
	0,
}
