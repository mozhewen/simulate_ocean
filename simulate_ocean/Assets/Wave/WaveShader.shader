Shader "Unlit/WaveShader"
{
	Properties
	{
		_Env("CubeMap", CUBE) = ""{}
		_ColorScatter("Color (Scatter)", Color) = (0,0,0,0)
		_Clarity("Clarity(1 = most transparent, 0 = least transparent)", Range(0, 1)) = 0.5
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		CGINCLUDE
		#include "UnityCG.cginc"
		// 新增
		#include "Lighting.cginc"

		struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct v2f
		{
			float4 vertex : SV_POSITION;
			float2 uv : TEXCOORD0;
			// 新增
			float4 world_pos: TEXCOORD1;
		};

		static const float PI = 3.14159265f;
		// 水的 Phong 参数
		static const float m = 500;
		// 常量（需与 MATLAB 生成原始数据所用的参数一致）
		static const uint p = 9;
		static const uint N = 1 << p;
		static const float d = 20.0f /* m */;

		// 波形数据
		sampler2D _Waveform;
		sampler2D _WaveformNormal;
		// 环境
		samplerCUBE _Env;
		// 散射颜色
		fixed4 _ColorScatter;

		float _Clarity;


		v2f vert(appdata v)
		{
			v2f o;
			o.uv = v.uv;
			float4 disp = tex2Dlod(_Waveform, float4(o.uv, 0.0, 0.0));
			o.world_pos = v.vertex;
			o.vertex = mul(UNITY_MATRIX_VP, v.vertex + disp);

			return o;
		}
		ENDCG

		// 海面上
		Pass
		{
			Cull Back
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			fixed4 frag (v2f i) : SV_Target
			{
				// 1. 计算法线、入射方向
				float3 norm = tex2D(_WaveformNormal, i.uv);
				float3 dir =  normalize(i.world_pos - _WorldSpaceCameraPos);

				// 2. Fresnel 方程
				const float n21 = 1.33; // 1 = 空气, 2 = 水
				//   反射折射方向
				float3 refl_dir = reflect(dir, norm);
				float3 refr_dir = refract(dir, norm, 1 / n21);
				float costheta1 = -dot(norm, dir);
				float costheta2 = -dot(norm, refr_dir);
				//   反射率
				float r1 = (costheta1 - n21 * costheta2) / (costheta1 + n21 * costheta2);
				float r2 = (costheta2 - n21 * costheta1) / (costheta2 + n21 * costheta1);
				float R = (r1 * r1 + r2 * r2)*0.5;
				if (R > 1)R = 1;

				// 3. Phong 阳光反射
				float4 sunlight = 0;
				float intense = dot(refl_dir, _WorldSpaceLightPos0.xyz);
				if (intense > 0) {
					sunlight = _LightColor0 * (m + 1) / (2 * PI)*pow(intense, m);
				}
				else {
					sunlight = float4(0, 0, 0, 0);
				}

				// 4. 折射探头
				float4 refrColor = 0;
				float4 val = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, refr_dir);
				refrColor.xyz = DecodeHDR(val, unity_SpecCube0_HDR);
				refrColor.w = 0.0;
				float4 reflColor = 0;
				if (refl_dir.y > 0) {
					reflColor = texCUBE(_Env, refl_dir);
				}
				else {
					val = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, refl_dir);
					reflColor.xyz = DecodeHDR(val, unity_SpecCube0_HDR);
					reflColor.w = 0.0;
				}
				
				// 5. 颜色混合
				fixed4 col = (reflColor + sunlight)*R + refrColor * (1 - R);
				
				return col;
			}
			ENDCG
		}
			
		// 海面下
		Pass
		{
			Cull Front
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			fixed4 frag(v2f i) : SV_Target
			{
				// 1. 计算法线、入射方向
				float3 norm = -tex2D(_WaveformNormal, i.uv);
				float3 dir = normalize(i.world_pos - _WorldSpaceCameraPos);

				// 2. Fresnel 方程
				const float n21 = 1/1.33; // 1 = 水, 2 = 空气
				float3 refl_dir = reflect(dir, norm);
				float3 refr_dir = refract(dir, norm, 1 / n21);
				float costheta1 = -dot(norm, dir);
				float R;
				float4 refrColor;
				bool totalRefl = length(refr_dir) < 1e-6;
				if (!totalRefl) {
					float costheta2 = -dot(norm, refr_dir);
					float r1 = (costheta1 - n21 * costheta2) / (costheta1 + n21 * costheta2);
					float r2 = (costheta2 - n21 * costheta1) / (costheta2 + n21 * costheta1);
					R = (r1 * r1 + r2 * r2) * 0.5;
					if (R > 1)R = 1;
					refrColor = texCUBE(_Env, refr_dir);
				}
				else {
					R = 1;
					refrColor = float4(0, 0, 0, 0);
				}	

				// 3. Phong 阳光折射
				float4 sunlight;
				float intense = dot(refr_dir, _WorldSpaceLightPos0.xyz);
				if (intense > 0) {
					sunlight = _LightColor0 * (m + 1) / (2 * PI)*pow(intense, m);
				}
				else {
					sunlight = float4(0, 0, 0, 0);
				}
				
				// 4. 反射探头
				float4 reflColor = 1.0;
				float4 val = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, refl_dir);
				reflColor.xyz = DecodeHDR(val, unity_SpecCube0_HDR);
				reflColor.w = 0.0;

				// 5. 颜色混合
				float4 col = (refrColor + sunlight)*(1 - R) + reflColor * R;
				float3 v = i.world_pos - _WorldSpaceCameraPos;
				float L = length(v);
				float H = v.y;
				float sinphi = H / L;
				float temp = 1 - sinphi;
				float alphaR = lerp(0.798508, 0.544727, _Clarity),
					  alphaG = lerp(0.139262, 0.0512933, _Clarity),
					  alphaB = lerp(0.116534, 0.0202027, _Clarity);
				float C = lerp(0.075, 0.045, _Clarity);
				col.r = col.r*exp(-alphaR * L) + C*_ColorScatter.r / temp / alphaR * exp(-alphaR * H) * (1 - exp(-alphaR * L * temp));
				col.g = col.g*exp(-alphaG * L) + C*_ColorScatter.g / temp / alphaG * exp(-alphaG * H) * (1 - exp(-alphaG * L * temp));
				col.b = col.b*exp(-alphaB * L) + C*_ColorScatter.b / temp / alphaB * exp(-alphaB * H) * (1 - exp(-alphaB * L * temp));
				
				return col;
			}
				ENDCG
		}
		
	}
}
