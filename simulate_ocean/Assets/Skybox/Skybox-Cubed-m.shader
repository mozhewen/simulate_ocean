// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Modified by Mo Zhewen 2018.

Shader "Skybox/CubemapModified" {
	Properties{
		_Tint("Tint Color", Color) = (.5, .5, .5, .5)
		[Gamma] _Exposure("Exposure", Range(0, 8)) = 1.0
		_Rotation("Rotation", Range(0, 360)) = 0
		[NoScaleOffset] _Tex("Cubemap   (HDR)", Cube) = "grey" {}
		// 新增
		_ColorScatter("Color (Scatter)", Color) = (1, 1, 1, 1)
		_Clarity("Clarity(1 = most transparent, 0 = least transparent)", Range(0, 1)) = 0.5
	}

	SubShader{
		Tags{ "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
		Cull Off ZWrite Off

		Pass{

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0

			#include "UnityCG.cginc"
			// 新增
			#include "Lighting.cginc"

			samplerCUBE _Tex;
			half4 _Tex_HDR;
			half4 _Tint;
			half _Exposure;
			float _Rotation;

			fixed4 _ColorScatter;
			float _Clarity;

			float3 RotateAroundYInDegrees(float3 vertex, float degrees)
			{
				float alpha = degrees * UNITY_PI / 180.0;
				float sina, cosa;
				sincos(alpha, sina, cosa);
				float2x2 m = float2x2(cosa, -sina, sina, cosa);
				return float3(mul(m, vertex.xz), vertex.y).xzy;
			}

			struct appdata_t {
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f {
				float4 vertex : SV_POSITION;
				float3 texcoord : TEXCOORD0;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert(appdata_t v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				float3 rotated = RotateAroundYInDegrees(v.vertex, _Rotation);
				o.vertex = UnityObjectToClipPos(rotated);
				o.texcoord = v.vertex.xyz;
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				half4 tex = texCUBE(_Tex, i.texcoord);
				half3 c = DecodeHDR(tex, _Tex_HDR);
				c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
				c *= _Exposure;

				float sinphi = i.texcoord.y / length(i.texcoord);
				float tanphi = i.texcoord.y / length(i.texcoord.xz);
				float depth = -_WorldSpaceCameraPos.y;
				float depth1;
				if (depth > 2) {
					depth1 = 1;
				}
				else if (depth < -2) {
					depth1 = -1;
				}
				else {
					depth1 = depth / 2;
				}
				depth1 = depth + depth1;
				if (depth < 0)depth = 0;
				const float farthest = 300;
				if (tanphi <= depth1 / farthest) {
					float alphaR = lerp(0.798508, 0.544727, _Clarity),
						  alphaG = lerp(0.139262, 0.0512933, _Clarity),
						  alphaB = lerp(0.116534, 0.0202027, _Clarity);
					float C = lerp(0.075, 0.045, _Clarity);
					c.r = C * _ColorScatter.r / (1 - sinphi) / alphaR * exp(-alphaR * depth);
					c.g = C * _ColorScatter.g / (1 - sinphi) / alphaG * exp(-alphaG * depth);
					c.b = C * _ColorScatter.b / (1 - sinphi) / alphaB * exp(-alphaB * depth);
				}
				return half4(c, 1);
			}
			ENDCG
		}
	}
	
	Fallback Off

}
