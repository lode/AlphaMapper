// Copyright 2013 Joshua R. Rodgers
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// ========================================================================

//Standard structs
#ifdef STANDARD
struct VS_StandardIn
#else
struct VS_PrelitIn
#endif
{
    float3 position : POSITION;
    float2 uv : TEXCOORD;
    float3 normal : NORMAL;
	#ifdef PRELIT
	float3 color : COLOR;
	#endif
	float4x4 worldMatrix : TRANSFORM;
};

#ifdef STANDARD
struct VS_StandardOut
#else
struct VS_PrelitOut
#endif
{
    float4 positionH : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
	#ifdef PRELIT
	float3 color : COLOR;
	#endif
	float3 position : POSITION;
	float4 projTexC : TEXCOORD1;
	float3x3 transform : TRANSFORM;
};

#ifdef STANDARD
struct GS_StandardOut
#else
struct GS_PrelitOut
#endif
{
    float4 positionH : SV_POSITION;
    float2 uv : TEXCOORD0;
	float4 projTexC : TEXCOORD1;
    float3 normal : NORMAL;
	#ifdef PRELIT
	float3 color : COLOR;
	#endif
};

#ifdef STANDARD
VS_StandardOut VShaderStandard(VS_StandardIn vertex)
#else
VS_PrelitOut VShaderPrelit(VS_PrelitIn vertex)
#endif
{
	#ifdef STANDARD
    VS_StandardOut vsOut;
	#else
	VS_PrelitOut vsOut;
	#endif

	float4x4 worldMatrix;

	[branch]
	if(g_IsInstanced)
	{
		worldMatrix = vertex.worldMatrix;
	}
	else
	{
		worldMatrix = g_WorldMatrix;	
	}

	float4x4 wvp = mul(mul(mul(worldMatrix, g_PostWorldMatrix), g_ViewMatrix), g_ProjectionMatrix);
    vsOut.positionH = mul(float4(vertex.position, 1.0f), wvp);
    vsOut.uv = vertex.uv;
    vsOut.normal = normalize(mul(vertex.normal, (float3x3)mul(worldMatrix, g_PostWorldMatrix)));
	vsOut.position = vertex.position;
	vsOut.transform = (float3x3)mul(worldMatrix, g_PostWorldMatrix);

	vsOut.projTexC = mul(float4(vertex.position, 1.0f), mul(worldMatrix, g_LightViewProjectionMatrix));

	#ifdef PRELIT
	vsOut.color = vertex.color;
	#endif

    return vsOut;
}

[maxvertexcount(3)]
#ifdef STANDARD
void GShaderStandard(triangle VS_StandardOut input[3], inout TriangleStream<GS_StandardOut> triangleStream)
#else
void GShaderPrelit(triangle VS_PrelitOut input[3], inout TriangleStream<GS_PrelitOut> triangleStream)
#endif
{
	[unroll]
	for(int v = 0; v < 3; v++)
	{
		#ifdef STANDARD
		GS_StandardOut output;
		#else
		GS_PrelitOut output;
		#endif

		output.positionH = input[v].positionH;
		output.uv = input[v].uv;
		output.normal = input[v].normal;
		output.projTexC = input[v].projTexC;

		#ifdef PRELIT
		output.color = input[v].color;
		#endif

		triangleStream.Append(output);
	}

	triangleStream.RestartStrip();
}


[maxvertexcount(2)]
#ifdef STANDARD
void GShaderStandard_Wireframe(line VS_StandardOut input[2], inout LineStream<GS_StandardOut> lineStream)
#else
void GShaderPrelit_Wireframe(line VS_PrelitOut input[2], inout LineStream<GS_PrelitOut> lineStream)
#endif
{
	[unroll]
	for(int v = 0; v < 2; v++)
	{
		#ifdef STANDARD
		GS_StandardOut output;
		#else
		GS_PrelitOut output;
		#endif

		output.positionH = input[v].positionH;
		output.uv = input[v].uv;
		output.normal = input[v].normal;
		output.projTexC = input[v].projTexC;

		#ifdef PRELIT
		output.color = input[v].color;
		#endif

		lineStream.Append(output);
	}

	lineStream.RestartStrip();
}

[maxvertexcount(3)]
#ifdef STANDARD
void GShaderStandard_Flat(triangle VS_StandardOut input[3], inout TriangleStream<GS_StandardOut> triangleStream)
#else
void GShaderPrelit_Flat(triangle VS_PrelitOut input[3], inout TriangleStream<GS_PrelitOut> triangleStream)
#endif
{
	float3 faceEdgeA = input[1].position.xyz - input[0].position.xyz;
    float3 faceEdgeB = input[2].position.xyz - input[0].position.xyz;
    float3 faceNormal = normalize(mul(normalize( cross(faceEdgeA, faceEdgeB) ), input[0].transform));

	[unroll]
	for(int v = 0; v < 3; v++)
	{
		#ifdef STANDARD
		GS_StandardOut output;
		#else
		GS_PrelitOut output;
		#endif

		output.positionH = input[v].positionH;
		output.uv = input[v].uv;
		output.normal = faceNormal;
		output.projTexC = input[v].projTexC;

		#ifdef PRELIT
		output.color = input[v].color;
		#endif

		triangleStream.Append(output);
	}

	triangleStream.RestartStrip();
}

#ifdef STANDARD
float4 PShaderStandard(GS_StandardOut psIn) : SV_Target0
#else
float4 PShaderPrelit(GS_PrelitOut psIn) : SV_Target0
#endif
{
	float4 outColor;
	float maskComponent = 1;

	[branch]
	if(g_HasMask)
	{
		maskComponent = g_Mask.Sample(g_TextureSampler, psIn.uv).r;
		clip(maskComponent - 0.2f);
	}

	#ifdef STANDARD

	[branch]
	if(g_HasTexture)
	{
		float4 sampledColor = g_Texture.Sample(g_TextureSampler, psIn.uv);
		clip(sampledColor.a - 0.2f);
		outColor = sampledColor;

		[branch]
		if(g_IsColorTinted)
		{
			outColor *= g_Color;
		}

		outColor = ParallelLight(outColor, psIn.normal, g_Ambient, g_Diffuse, g_GlobalLight, CalcShadowFactor(psIn.projTexC));

		outColor.a = g_Opacity * maskComponent * sampledColor.a;
	}
	else
	{
		outColor = ParallelLight(g_Color, psIn.normal, g_Ambient, g_Diffuse, g_GlobalLight, 1);
		outColor.a = g_Opacity * maskComponent;
	}
	#else

	[branch]
	if(g_HasTexture)
	{
		float4 sampledColor = g_Texture.Sample(g_TextureSampler, psIn.uv);
		clip(sampledColor.a - 0.2f);
		outColor = float4(psIn.color, 1.0f) * float4(sampledColor.rgb, 1.0f);
		outColor.a = maskComponent * sampledColor.a;
	}
	else
	{
		outColor = float4(psIn.color, g_Opacity);
	}

	#endif
	
    return outColor;
}
