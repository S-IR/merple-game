#version 450

#ifdef VERTEX
layout(set = 0, binding = 0) uniform CameraUBO {
    mat4 view;
    mat4 proj;
};

layout(location = 0) in vec3 inPosition;

layout(location = 0) flat out uint colorIndex;

void main() {
    gl_Position = proj * view * vec4(inPosition, 1.0);
    colorIndex = gl_VertexIndex / 3;
}
#endif

#ifdef FRAGMENT
layout(set = 0, binding = 1) readonly buffer TriangleColorsSBO {
    vec4 colors[];
};

layout(location = 0) in flat uint colorIndex;

layout(location = 0) out vec4 outColor;

void main() {
    outColor = colors[colorIndex];
}
#endif
