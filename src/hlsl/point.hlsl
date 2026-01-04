struct VSOutput {
    float4 position : SV_Position;
    float4 color    : COLOR;
};
#ifdef VERTEX


cbuffer CameraUBO : register(b0, space1)  
{
    matrix viewProj;
};

VSOutput main(float3 inPosition : POSITION, float4 inColor : COLOR0) {
    VSOutput output;
    output.position = mul(viewProj, float4(inPosition, 1.0));
    output.color = inColor;
    return output;
}
#endif

#ifdef FRAGMENT
struct FSOutput {
    float4 color : SV_Target;
};

FSOutput main(float4 inColor : COLOR) {
    FSOutput output;
    output.color = inColor;
    return output;
}
#endif