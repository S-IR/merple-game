struct VSOutput
{
    float4 position : SV_Position;
};
struct PointSBO {
    float3 position;
    float _pad;
};

StructuredBuffer<PointSBO> PositionsSBO : register(t0, space0);

#ifdef VERTEX


cbuffer CameraUBO : register(b0, space1)
{
    matrix viewProj;
};

struct VSInput
{
    uint vertexId : SV_VertexID;
};

VSOutput main(VSInput input)
{
    VSOutput output;
    PointSBO p = PositionsSBO[input.vertexId];
    output.position = mul(viewProj, float4(p.position, 1.0));
    return output;
}
#endif

#ifdef FRAGMENT
StructuredBuffer<float4> TriangleColorsSBO : register(t0, space2);

struct FSOutput
{
    float4 color : SV_Target;
};

FSOutput main(VSOutput input, uint primitiveId : SV_PrimitiveID)
{
    FSOutput output;
    output.color = TriangleColorsSBO[primitiveId];
    return output;
}
#endif
