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
        _BarHudHeight("Bar HUD Height", Float) = 0.0
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
        _DeathHudLocationY("Death HUD Location Y", Float) = 1.23
        _DeathHudSize("Death HUD Size", Float) = 3.5

        [Header(Tunnel Vision Overlay)][Space(5)]
        _TunnelVision ("Tunnel Vision", Float) = 0.0
        _TunnelVisionStrength ("Tunnel Vision Strength", Float) = 1.0

        [Header(Team Marker)][Space(5)]
        _TeamMarkerHue("Team Marker Hue", Float) = 0.7
        _TeamMarkerSaturation("Team Marker Saturation", Float) = 0.7
        _TeamMarkerBrightness("Team Marker Brightness", Float) = 1.0
        _TeamMarkerAlpha("Team Marker Alpha", Float) = 0.6
        _TeamMarkerTriangleFromY("Team Marker From Y", Float) = 0.6
        _TeamMarkerTriangleToY("Team Marker To Y", Float) = 0.8
        _TeamMarkerTriangleWidthX("Team Marker Width X", Float) = 0.39

        [Header(HUD)][Space(5)]
        _HudDistanceFromCamera("HUD Distance From Camera", Float) = 0.001

        [Header(Toggles)][Space(5)]
        _ShowHealthBar("Show Health Bar", Float) = 1.0
        _ShowDeathIndicator("Show Death Indicator", Float) = 0.0
        _ShowTeamMarker("Show Team Marker", Float) = 1.0
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
                float4 teamColor : COLOR5;

                // HUD Stuff
                float4 screenPos : TEXCOORD2;
                float2 deathHudAspectRatioAdjustment: COLOR3;
                float2 deathHudCenteringOffset: COLOR4;
            };

            // sampler2D _MainTex;
            // float4 _MainTex_ST;
            uniform float4 _GoodColor;
            uniform float4 _BadColor;
            uniform float4 _ArmourColor;

            uniform float _Health;
            uniform float _MaxHealth;

            uniform float _Armour;
            uniform float _MaxArmour;

            uniform float _BarHudOffset;
            uniform float _BarHudWidth;
            uniform float _BarHudHeight;
            uniform float _ArmourBarSize;
            uniform float _BarSize;
            uniform float _Alpha;

            sampler2D _DeathCrossTexture;
            float4 _DeathCrossTexture_ST;
            uniform float4 _DeathCrossColor1;
            uniform float4 _DeathCrossColor2;
            uniform float _DeathCrossShiftSpeed;

            sampler2D _DeathHudOverlay;
            float4 _DeathHudOverlay_ST;
            uniform float4 _DeathHudOverlay_TexelSize;
            uniform float4 _DeathHudColor;
            uniform float _DeathHudLocationY;
            uniform float _DeathHudSize;

            uniform float _TunnelVision;
            uniform float _TunnelVisionStrength;

            uniform float _TeamMarkerHue;
            uniform float _TeamMarkerSaturation;
            uniform float _TeamMarkerBrightness;
            uniform float _TeamMarkerAlpha;
            uniform float _TeamMarkerTriangleFromY;
            uniform float _TeamMarkerTriangleToY;
            uniform float _TeamMarkerTriangleWidthX;

            uniform float _HudDistanceFromCamera;
            uniform float _ShowHealthBar;
            uniform float _ShowDeathIndicator;
            uniform float _ShowTeamMarker;
            uniform float _IsHUD;
        
            float mapRange(float input_start, float input_end, float output_start, float output_end, float input) {
                return output_start + ((output_end - output_start) / (input_end - input_start)) * (input - input_start);
            }

            // Source: https://docs.unity3d.com/Packages/com.unity.shadergraph@6.9/manual/Colorspace-Conversion-Node.html
            void Unity_ColorspaceConversion_HSV_RGB_float(float3 In, out float3 Out)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 P = abs(frac(In.xxx + K.xyz) * 6.0 - K.www);
                Out = In.z * lerp(K.xxx, saturate(P - K.xxx), In.y);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = v.vertex;

                float3 objectToCameraVec = normalize(ObjSpaceViewDir(float4(0, 0, 0, 0)));

                // Keep the plane looking at the camera
                float3 up = objectToCameraVec;
                float3 forward = float3(0,1,0);
                float3 right = normalize(cross(up, forward));
                forward = cross(right, up);
                float3x3 rotMatrix = float3x3(right, up, forward);

                // Move the plane up to the camera to fill it completely
                float3 screenCoords = float4((v.uv - float2(0.5, 0.5)) * 2 * _ScreenParams.xy, _HudDistanceFromCamera * -1, 1);
                float3 fullScreenPos = mul(unity_WorldToObject, mul(UNITY_MATRIX_I_V, screenCoords)).xyz;

                // This is done conditionally based on _IsHUD
                o.pos.xyz = mul(o.pos.xyz, rotMatrix) * !_IsHUD + fullScreenPos * _IsHUD;

                o.pos = UnityObjectToClipPos(o.pos);
                o.uv.xy = v.uv.xy;

                // Set pre-calculations for the fragmentation shader
                o.halfBarSize = ((1 - _BarSize) / 2);
                o.armourBarY = mapRange(0, 1, 1 - o.halfBarSize, o.halfBarSize, _ArmourBarSize);
                float deathShift = (sin(_Time.z * _DeathCrossShiftSpeed) + 1) / 2;
                o.deathCrossColor = (_DeathCrossColor1 * deathShift) + (_DeathCrossColor2 * (1 - deathShift));
                o.deathCrossTextureUV = TRANSFORM_TEX(v.uv, _DeathCrossTexture);
                float3 teamColor;
                float3 teamColorHSV = float3(_TeamMarkerHue, _TeamMarkerSaturation, _TeamMarkerBrightness);
                Unity_ColorspaceConversion_HSV_RGB_float(teamColorHSV, teamColor);
                o.teamColor = float4(teamColor, _TeamMarkerAlpha);

                // HUD calculations
                o.screenPos = ComputeScreenPos(o.pos);
                float2 texAspectRatio = _DeathHudOverlay_TexelSize.zw;
                float2 screenAspectRatio = _ScreenParams.xy;
                o.deathHudAspectRatioAdjustment =  (screenAspectRatio / texAspectRatio) * _DeathHudSize;
                o.deathHudCenteringOffset = (o.deathHudAspectRatioAdjustment - 1) / 2;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // HUD Calculations
                float2 screenPos = i.screenPos.xy / i.screenPos.w;

                // This X and Y is based on the screenspace if _IsHUD is true and
                // otherwise the UVs of the model.
                float x = ((1 - i.uv.x) * !_IsHUD) + (mapRange(0, 1, 1 - _BarHudWidth, _BarHudWidth, screenPos.x) * _IsHUD);
                float y = ((1 - i.uv.y) * !_IsHUD) + (mapRange(0, 1, _BarHudHeight, 1 - _BarHudHeight, (screenPos.y + _BarHudOffset)) * _IsHUD);

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

                // Team indicator
                float trianglePos = mapRange(_TeamMarkerTriangleFromY, _TeamMarkerTriangleToY, 0, 1, y);
                float triangleX = mapRange(_TeamMarkerTriangleWidthX, 1 - _TeamMarkerTriangleWidthX, 0, 1, x);
                float inTeamMarker = (0 < trianglePos) * (trianglePos < 1)
                    * ((1.0 - triangleX) < trianglePos) * ((triangleX) < trianglePos);
                float4 teamMarker = i.teamColor * inTeamMarker;

                // Add the death cross
                fixed4 texCol = tex2D(_DeathCrossTexture, i.deathCrossTextureUV);
                fixed4 deathCrossFinal = texCol * i.deathCrossColor;
                float4 aboveHead = (healthBarAlpha * _ShowHealthBar)
                    + (teamMarker * _ShowTeamMarker)
                    + (deathCrossFinal * _ShowDeathIndicator);

                // Tunnel vision HUD
                // float normalTunnelVision = max((abs(screenPos.x - 0.5) + abs(screenPos.y - 0.5)), 0.5);
                float2 curr = float2((screenPos.x * 2) - 1, (screenPos.y * 2) - 1);
                float vecLength = pow(curr.x, 2) + pow(curr.y, 2);
                float tunnelVisionStrength = pow(vecLength, _TunnelVisionStrength);
                float normalTunnelVision = tunnelVisionStrength * _TunnelVision;
                float4 tunnelVisionFinal = float4(0, 0, 0, normalTunnelVision);

                // You died HUD text
                float2 deathHudTexUV = screenPos * i.deathHudAspectRatioAdjustment;
                deathHudTexUV.y += _DeathHudLocationY * -1;
                deathHudTexUV -= i.deathHudCenteringOffset;
                float4 deathHudTex = tex2D(_DeathHudOverlay, deathHudTexUV);
                float renderDeathHudText = (deathHudTex.w > 0.1)
                    * ((deathHudTexUV.x > 0) * (deathHudTexUV.x < 1))
                    * ((deathHudTexUV.y > 0) * (deathHudTexUV.y < 1));
                float4 deathHudFinal = deathHudTex * renderDeathHudText + _DeathHudColor * !renderDeathHudText;

                float4 hudFinal = tunnelVisionFinal * (1 - round(healthBarAlpha.w)) + healthBarAlpha;
                float4 hudFinalDeath = hudFinal * !_ShowDeathIndicator + deathHudFinal * _ShowDeathIndicator;

                return (aboveHead * !_IsHUD) + (hudFinalDeath * _IsHUD);
            }
            ENDCG
        }
    }
}
