struct VSOutput {
    float4 position : SV_Position;
    nointerpolation uint colorIndex: COLOR0;
};
#ifdef VERTEX

cbuffer CameraUBO : register(b0, space1)
{
    matrix viewProj;
};

VSOutput main(float3 inPosition : POSITION, uint colorIndex: COLOR0) {
    VSOutput output;
    output.position = mul(viewProj, float4(inPosition, 1.0));
    output.colorIndex = colorIndex;
    return output;
}
#endif

#ifdef FRAGMENT
StructuredBuffer<float4> TriangleColorsSBO : register(t0, space2);

struct FSOutput
{
    float4 color : SV_Target;
};

FSOutput main(VSOutput input)
{
    FSOutput output;
    output.color = TriangleColorsSBO[input.colorIndex];
    return output;
}
#endif
