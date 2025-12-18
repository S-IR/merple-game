struct VSOutput
{
    float3 color : TEXCOORD0;
    float4 position : SV_Position;
};

#ifdef VERTEX
struct PointSBO {
    float3 position;
    float4 color;
};
// Two separate SBOs for positions and colors
StructuredBuffer<PointSBO> PositionsSBO : register(t0, space0);

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
   output.color = p.color.xyz;

   return output;
}
#endif

#ifdef FRAGMENT
struct FSOutput
{
    float4 color : SV_Target;
};

FSOutput main(VSOutput input)
{
    FSOutput output;
    output.color = float4(input.color, 1.0);
    return output;
}
#endif
