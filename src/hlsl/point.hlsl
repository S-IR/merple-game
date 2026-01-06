struct VSOutput {
    float4 position : SV_Position;
};
#ifdef VERTEX


cbuffer CameraUBO : register(b0, space1)  
{
    matrix viewProj;
};

VSOutput main(float3 inPosition : POSITION) {
    VSOutput output;
    output.position = mul(viewProj, float4(inPosition, 1.0));
    return output;
}
#endif

#ifdef FRAGMENT
StructuredBuffer<float4> TriangleColorsSBO : register(t0, space2);

struct FSOutput
{
    float4 color : SV_Target;
};

FSOutput main(VSOutput input, uint primID : SV_PrimitiveID)
{
    FSOutput output;
    output.color = TriangleColorsSBO[primID];
    return output;
}
#endif




