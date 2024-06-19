// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

Shader "Hroi/FireteamVR/HPBar"
{
    Properties
    {
        [Header(HPBar Color)][Space(5)]
        _GoodColor("Good Color", Color) = (0.0, 1.0, 0.0, 1)
        _BadColor("Bad Color", Color) = (1.0, 0.0, 0.0, 1)
        _ArmourColor("Armour Color", Color) = (0.0, 0.0, 1.0, 1)

        [Header(HPBar Size)][Space(5)]
        _BarHudOffset("Bar HUD Offset", Float) = -0.28
        _BarHudWidth("Bar HUD Width", Float) = 0.0
        _ArmourBarSize("Armour Bar Size", Float) = 0.33
        _BarSize("Bar Size", Float) = 0.1
        _Alpha("Alpha", Float) = 0.6

        [Header(Health)][Space(5)]
        _Health("Health", Float) = 1.0
        _MaxHealth("Max Health", Float) = 1.0

        [Header(Armour)][Space(5)]
        _Armour("Armour", Float) = 2.0
        _MaxArmour("Max Armour", Float) = 1.0

        [Header(Death Cross)][Space(5)]
        _DeathCrossTexture("Death Cross Texture", 2D) = "white" {}
        _DeathCrossColor1("Death Cross Color 1", Color) = (1.0, 1.0, 1.0, 1.0)
        _DeathCrossColor2("Death Cross Color 2", Color) = (0.6, 0.0, 0.0, 1.0)
        _DeathCrossShiftSpeed("Death Cross Shift Speed", Float) = 1.0

        [Header(Death HUD Overlay)][Space(5)]
        _DeathHudOverlay("Death HUD Overlay Texture", 2D) = "white" {}
        _DeathHudColor("Death HUD Color", Color) = (0.0, 0.0, 0.0, 0.4)

        [Header(HUD Stuff)][Space(5)]
        _TunnelVision ("Tunnel Vision", Float) = 0.0
        _TunnelVisionStrength ("Tunnel Vision Strength", Float) = 1.0

        [Header(Toggles)][Space(5)]
        _ShowHealthBar("Show Health Bar", Float) = 1.0
        _ShowDeathIndicator("Show Death Indicator", Float) = 0.0
        _IsHUD("Is HUD", Float) = 0.0
    }
    SubShader
    {
        Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" "DisableBatching" = "True" }

        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Back

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float armourBarY : COLOR0;
                float halfBarSize : COLOR1;
                float4 deathCrossColor : COLOR2;
                float2 deathCrossTextureUV : TEXCOORD1;

                // HUD Stuff
                float4 screenPos : TEXCOORD2;
            };

            // sampler2D _MainTex;
            // float4 _MainTex_ST;
            float4 _GoodColor;
            float4 _BadColor;
            float4 _ArmourColor;

            float _Health;
            float _MaxHealth;

            float _Armour;
            float _MaxArmour;

            float _BarHudOffset;
            float _BarHudWidth;
            float _ArmourBarSize;
            float _BarSize;
            float _Alpha;

            sampler2D _DeathCrossTexture;
            float4 _DeathCrossTexture_ST;
            float4 _DeathCrossColor1;
            float4 _DeathCrossColor2;
            float _DeathCrossShiftSpeed;

            sampler2D _DeathHudOverlay;
            float4 _DeathHudOverlay_ST;
            float4 _DeathHudColor;

            float _TunnelVision;
            float _TunnelVisionStrength;

            float _ShowHealthBar;
            float _ShowDeathIndicator;
            float _IsHUD;
        
            float mapRange(float input_start, float input_end, float output_start, float output_end, float input) {
                return output_start + ((output_end - output_start) / (input_end - input_start)) * (input - input_start);
            }
        
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = v.vertex;

                float3 cameraWorldPosition = _WorldSpaceCameraPos;
                float3 objectWorldPosition = unity_ObjectToWorld._m03_m13_m23;
                float3 objectToCameraVec = normalize(cameraWorldPosition - objectWorldPosition);

                // Vertex position in world space
                // float3 vertexPosition = mul((float3x3)unity_ObjectToWorld, v.vertex.xyz);
                // float4 worldCoord = float4(unity_ObjectToWorld._m03, unity_ObjectToWorld._m13, unity_ObjectToWorld._m23, 1);
                // float4 viewPos = mul(UNITY_MATRIX_V, worldCoord) + float4(vertexPosition, 0);
                // float4 outPos = mul(UNITY_MATRIX_P, viewPos);

                float3 up = objectToCameraVec;
                float3 forward = float3(0,1,0);
                float3 right = normalize(cross(up, forward));
                forward = cross(right, up);
                
                float3x3 rotMatrix = float3x3(right, up, forward);
                // This is done conditionally based on _IsHUD
                o.pos.xyz = mul(o.pos.xyz, rotMatrix) * !_IsHUD + o.pos.xyz * _IsHUD;

                o.pos = UnityObjectToClipPos(o.pos);
                o.uv.xy = v.uv.xy;

                // Set pre-calculations for the fragmentation shader
                o.halfBarSize = ((1 - _BarSize) / 2);
                o.armourBarY = mapRange(0, 1, 1 - o.halfBarSize, o.halfBarSize, _ArmourBarSize);
                float deathShift = (sin(_Time.z * _DeathCrossShiftSpeed) + 1) / 2;
                o.deathCrossColor = (_DeathCrossColor1 * deathShift) + (_DeathCrossColor2 * (1 - deathShift));
                o.deathCrossTextureUV = TRANSFORM_TEX(v.uv, _DeathCrossTexture);

                // HUD calculations
                o.screenPos = ComputeScreenPos(o.pos);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // HUD Calculations
                float2 screenPos = i.screenPos.xy / i.screenPos.w;

                // This X and Y is based on the screenspace if _IsHUD is true and
                // otherwise the UVs of the model.
                float x = ((1 - i.uv.x) * !_IsHUD) + (mapRange(0, 1, 1 - _BarHudWidth, _BarHudWidth, screenPos.x) * _IsHUD);
                float y = ((1 - i.uv.y) * !_IsHUD) + ((screenPos.y + _BarHudOffset) * _IsHUD);

                // Armour calculations
                float isArmourPos = x * _MaxArmour < _Armour;
                float4 armourColor = _ArmourColor * isArmourPos;

                // Do the HP color calculations
                float isGoodPos = x * _MaxHealth < _Health;
                float4 hpBarColor = _GoodColor * isGoodPos + _BadColor * !isGoodPos;

                // Differentiate between armour and hp bars
                float isBar = (i.halfBarSize < y) * ((1 - i.halfBarSize) > y) * (x > 0) * (x < 1);
                float isHpBar = y < i.armourBarY;
                float4 healthBarSolid = (hpBarColor * isBar * isHpBar) + (armourColor * isBar * !isHpBar);
                float4 healthBarAlpha = float4(healthBarSolid.xyz, _Alpha * isBar);

                // Add the death cross
                fixed4 texCol = tex2D(_DeathCrossTexture, i.deathCrossTextureUV);
                fixed4 deathCrossFinal = texCol * i.deathCrossColor;
                float4 aboveHead = (healthBarAlpha * _ShowHealthBar) + (deathCrossFinal * _ShowDeathIndicator);

                // Tunnel vision HUD
                // float normalTunnelVision = max((abs(screenPos.x - 0.5) + abs(screenPos.y - 0.5)), 0.5);
                float2 curr = float2((screenPos.x * 2) - 1, (screenPos.y * 2) - 1);
                float vecLength = pow(curr.x, 2) + pow(curr.y, 2);
                float tunnelVisionStrength = pow(vecLength, _TunnelVisionStrength);
                float normalTunnelVision = tunnelVisionStrength * _TunnelVision;
                float4 tunnelVisionFinal = float4(0, 0, 0, normalTunnelVision);

                float4 hudFinal = tunnelVisionFinal * (1 - round(healthBarAlpha.w)) + healthBarAlpha;

                return (aboveHead * !_IsHUD) + (hudFinal * _IsHUD);
            }
            ENDCG
        }
    }
}
