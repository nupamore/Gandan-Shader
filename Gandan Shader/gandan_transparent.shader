Shader "gandan/Transparent"
{
	Properties
	{
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Culling Mode", Float) = 2
		[NoScaleOffset] _MainTex("Texture", 2D) = "white" {}
        [NoScaleOffset] _alphaMask("Alpha Mask", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        [Toggle] _isToon("Toon Shadow", Range(0, 1)) = 0
        [Toggle] _isRim("Rim Light", Range(0, 1)) = 1
        _UnlitThreshold("Lit <-> Unlit", Range(0, 1)) = 0
	}
	SubShader
	{
        Tags {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "IgnoreProjector"="True"
        }
        Cull [_Cull]
		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

            sampler2D _MainTex;
			float4 _MainTex_ST;
            float4 _Color;
            float _isToon;
            float _isRim;
            float _UnlitThreshold;
            sampler2D _alphaMask;

			struct vertexInput
			{
				float4 vertex : POSITION;				
				float4 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct vertexOutput
			{
				float4 pos : SV_POSITION;
				float3 worldNormal : NORMAL;
				float2 uv : TEXCOORD0;
				float3 viewDir : TEXCOORD1;	
				SHADOW_COORDS(2)
			};
			
			vertexOutput vert (vertexInput v)
			{
				vertexOutput o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);		
				o.viewDir = WorldSpaceViewDir(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				TRANSFER_SHADOW(o)
				return o;
			}

			float4 frag (vertexOutput i) : SV_Target
			{
				float3 normal = normalize(i.worldNormal);
				float3 viewDir = normalize(i.viewDir);
				float NdotL = _isToon ? dot(_WorldSpaceLightPos0, normal) - 0.3 : 1;
				float shadow = SHADOW_ATTENUATION(i);
				float lightIntensity = smoothstep(0, 0.01, NdotL * shadow);
				float4 light = max(0.4, lightIntensity) * _LightColor0;
				float3 halfVector = normalize(_WorldSpaceLightPos0 + viewDir);
				float NdotH = dot(normal, halfVector);		
				float rimDot = 1 - dot(viewDir, normal);
				float rimIntensity = smoothstep(0.5, 0.6, rimDot * pow(NdotH, 0.5));
				float4 rim = _isRim * rimIntensity * _LightColor0 * 2;
				float4 tex = tex2D(_MainTex, i.uv);
                float4 ambient = saturate(float4(ShadeSH9(0.7), 1));
                float4 finalColor = saturate(light + rim + ambient) * 1.05 * tex * _Color;
                finalColor.a = tex.a * _Color.a * tex2D(_alphaMask, i.uv);
				return lerp(finalColor, tex, _UnlitThreshold);
			}
			ENDCG
		}
        Pass
		{
            Tags { "LightMode" = "ForwardAdd" }
            Blend SrcAlpha OneMinusSrcAlpha 
            Blend One One

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

            sampler2D _MainTex;
			float4 _MainTex_ST;
            float4 _Color;
            float _isToon;
            float _UnlitThreshold;
            sampler2D _alphaMask;

			struct vertexInput
			{
				float4 vertex : POSITION;				
				float4 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct vertexOutput
			{
				float4 pos : SV_POSITION;
                float4 posWorld : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 vertexLighting : TEXCOORD2;
                float2 uv : TEXCOORD3;
				SHADOW_COORDS(2)
			};
			
			vertexOutput vert (vertexInput v)
			{
				vertexOutput o;
				o.pos = UnityObjectToClipPos(v.vertex);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);		
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				TRANSFER_SHADOW(o)
				return o;
			}

			float4 frag (vertexOutput i) : SV_Target
			{
				float4 tex = tex2D(_MainTex, i.uv);
                float3 color = saturate(tex * _LightColor0.rgb);
                float3 vertexToLightSource = _WorldSpaceLightPos0.xyz - i.posWorld.xyz;
                float distance = length(vertexToLightSource);
                float atten = saturate(pow(1 / distance, 10) * 0.1);
                float3 lightDirection = normalize(vertexToLightSource);
                float NdotL = !_isToon ? 1 : dot(i.worldNormal, lightDirection) - 0.3 > 0 ? 0.6 : 0.2;
                float4 finalColor = float4(atten * color * NdotL, 1) * tex.a * _Color.a * tex2D(_alphaMask, i.uv);
                return lerp(finalColor, 0, _UnlitThreshold);
			}
			ENDCG
		}
	}
    FallBack "Diffuse"
}