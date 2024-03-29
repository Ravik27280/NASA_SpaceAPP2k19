﻿// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "World Political Map/Unlit Earth 16K Scenic City Lights" {

	Properties {
		_TexTL ("Tex TL", 2D) = "white" {}
		_TexTR ("Tex TR", 2D) = "white" {}
		_TexBL ("Tex BL", 2D) = "white" {}
		_TexBR ("Tex BR", 2D) = "white" {}
		_NormalMap ("Normal Map", 2D) = "bump" {}
		_BumpAmount ("Bump Amount", Range(0, 1)) = 0.5
		_CloudMap ("Cloud Map", 2D) = "black" {}
		_CloudSpeed ("Cloud Speed", Range(-1, 1)) = -0.04
		_CloudAlpha ("Cloud Alpha", Range(0, 1)) = 1
		_CloudShadowStrength ("Cloud Shadow Strength", Range(0, 1)) = 0.2
		_CloudElevation ("Cloud Elevation", Range(0.001, 0.1)) = 0.003
		_SunLightDirection("Sun Light Direction", Vector) = (0,0,1)
		_AtmosphereColor("Atmosphere Color", Color) = (0.4, 0.3, 0.9, 1)
		_AtmosphereAlpha("Atmosphere Alpha", Range(0,1)) = 1
		_AtmosphereFallOff("Atmosphere Falloff", Range(0,5)) = 1.35
		_AtmosphereScatter("Atmosphere Scatter", Range(0,5)) = 3.5
		_ScenicIntensity("Intensity", Range(0,1)) = 1
		_CityLights ("City Lights (RGB)", 2D) = "black" {}		
		_Brightness("Brightness", Range(1,3)) = 1.25
		_Contrast("Contrast", Range(0,2)) = 1.1
	}
	
	Subshader {
		Tags { "RenderType"="Opaque" }
		Lighting Off
		Offset 5,2
		Pass {
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma fragmentoption ARB_precision_hint_fastest
				
				#include "UnityCG.cginc"
				
				sampler2D _TexTL;
				sampler2D _TexTR;
				sampler2D _TexBL;
				sampler2D _TexBR;
				sampler2D _NormalMap;
				sampler2D _CloudMap;
				float _BumpAmount;
				float _CloudSpeed;
				float _CloudAlpha;
				float _CloudShadowStrength;
				float _CloudElevation;
				float3 _SunLightDirection;
				fixed4 _AtmosphereColor;
				float _AtmosphereAlpha;
				float _AtmosphereFallOff;
				float _AtmosphereScatter;
				float _ScenicIntensity;
				sampler2D _CityLights;
				uniform float _Brightness;
				uniform float _Contrast;
				
				struct v2f {
					float4 pos : SV_POSITION;
					half2 uv : TEXCOORD0;
					float3 viewDir: TEXCOORD1;
					float3 normal: TEXCOORD2;
					float2 scatter: TEXCOORD3;
				};
        
				v2f vert (appdata_tan v) {
					TANGENT_SPACE_ROTATION;
					v2f o;
					o.pos 				= UnityObjectToClipPos (v.vertex);
					o.uv 				= v.texcoord;
					o.normal			= mul( unity_ObjectToWorld, float4( v.normal, 0.0 ) ).xyz;
					o.viewDir 			= normalize(mul(rotation, ObjSpaceViewDir(v.vertex)));
					// compute scatter vectors
					float3 worldObjPos 	= mul( unity_ObjectToWorld, float4(0,0,0,1)).xyz;
					float d 			= dot(o.viewDir, normalize(_SunLightDirection)); //normalize(worldObjPos - _WorldSpaceCameraPos));
					o.scatter 			= float2(1.0 - saturate(d * _AtmosphereFallOff),  0);
					return o;
				 }
				
				fixed4 frag (v2f i) : SV_Target {
					// compute Earth pixel color
					fixed4 color;
					
					// compute Earth pixel color
					if (i.uv.x<0.5) {
						if (i.uv.y>0.5) {
							color = tex2D (_TexTL, i.uv.xy * 2.0.xx);
						} else {
							color = tex2D (_TexBL, half2(i.uv.x * 2.0f, (i.uv.y-0.5) * 2.0));	
						}
					} else {
						if (i.uv.y>0.5) {
							color = tex2D (_TexTR, half2((i.uv.x - 0.5) * 2.0f, i.uv.y * 2.0));
						} else {
							color = tex2D (_TexBR, half2((i.uv.x - 0.5) * 2.0f, (i.uv.y-0.5) * 2.0));	
						}
					}
					float3 elevation = UnpackNormal(tex2D(_NormalMap, i.uv));
					float d = 1.0 - 0.5 * saturate(dot(elevation, i.viewDir) * _BumpAmount );
					fixed4 earth = color * d;
					
					// compute cloud and shadows
					float2 t = fixed2(_Time[0] * _CloudSpeed, 0);
					float2 disp = -i.viewDir * _CloudElevation;
					fixed4 cloud = tex2D (_CloudMap, i.uv + t - disp);
					const float2 c = fixed2(0.998,0);
					fixed4 shadows = tex2D (_CloudMap, i.uv + t + c + disp) * _CloudShadowStrength;
					shadows *=  dot(elevation, i.viewDir);
					
					// apply clouds
					fixed4 rgb = earth + (cloud - clamp(shadows, shadows, 1-cloud)) * _CloudAlpha ;
					
					// apply atmosphere scattering
					rgb = lerp(rgb, _AtmosphereColor * i.scatter.x, _AtmosphereAlpha); // rgb * (1-_AtmosphereAlpha) + _AtmosphereAlpha * (_AtmosphereColor * i.scatter.x); // + i.scatter.yyy);

					// apply light falloff + city lights
					float dir = saturate(dot(_SunLightDirection, i.normal));
					rgb *= dir;
					fixed3 cityLights = tex2D(_CityLights, i.uv).rgb;
					rgb.xyz += cityLights * (1.0 - saturate(dir * 4));
					
					// apply final contrast
		  			rgb.xyz = (rgb - 0.5.xxx) * _Contrast + 0.5.xxx;
  			   		rgb.xyz *= _Brightness;

					
					return lerp(color, rgb, _ScenicIntensity);
				}
			
			ENDCG
		}
	}
}