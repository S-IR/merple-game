#version 450

#ifdef VERTEX
layout(location = 0) in vec3 inPosition;
layout(location = 1) in uint colorIndex;

layout(location = 0) flat out uint vColorIndex;

layout(set = 1, binding = 0) uniform CameraUBO {
    mat4 viewProj;
};

void main() {
    gl_Position = viewProj * vec4(inPosition, 1.0);
    vColorIndex = colorIndex;
}
#endif

#ifdef FRAGMENT
layout(location = 0) flat in uint vColorIndex;

layout(set = 2, binding = 0) buffer TriangleColorsSBO {
    vec4 colors[];
};

layout(location = 0) out vec4 outColor;

void main() {
    outColor = colors[vColorIndex];
}
#endif
