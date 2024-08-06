Shader "Hroi/FireteamVR/WatchLit"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        [Header(Watchface Colors)][Space(5)]
        _HealthColor ("Health Color", Color) = (0, 1, 0, 1)
        _HealthGoneColor ("Health Gone Color", Color) = (0, 0.1, 0, 1)
        _ShieldColor ("Shield Color", Color) = (0, 0, 1, 1)
        _ShieldGoneColor ("Shield Gone Color", Color) = (0, 0, 0.1, 1)
        _WatchfaceColor ("Watchface Color", Color) = (0, 0, 0, 1)

        [Header(Watchface Sizes)][Space(5)]
        _WatchfaceBarSize ("Watchface Bar Size", Range(0, 0.25)) = 0.1
        _WatchfaceBarOffset ("Watchface Bar Offset", Range(0, 1)) = 0.05
        [Toggle(ENABLE_WATCHFACE_BAR_FLIP)]
        _WatchfaceBarFlip ("Watchface Bar Flip", Integer) = 1

        [Header(Health Runtime Variables)][Space(5)]
        _Health ("Health", Float) = 1.0
        _MaxHealth ("Max Health", Float) = 1.0
        _Armour ("Armour", Float) = 1.0
        _MaxArmour ("Max Armour", Float) = 1.0

        [Header(Other Runtime Variables)][Space(5)]
        _HideWatchface ("Hide Watchface", Float) = 0.0
        _HasArmour ("Has Armour", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        #pragma shader_feature ENABLE_WATCHFACE_BAR_FLIP

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        uniform float4 _HealthColor;
        uniform float4 _HealthGoneColor;
        uniform float4 _ShieldColor;
        uniform float4 _ShieldGoneColor;
        uniform float4 _WatchfaceColor;

        uniform float _WatchfaceBarSize;
        uniform float _WatchfaceBarOffset;
        uniform float _WatchfaceBarFlip;

        uniform float _Health;
        uniform float _MaxHealth;
        uniform float _Armour;
        uniform float _MaxArmour;

        uniform float _HideWatchface;
        uniform float _HasArmour;

        static const float PI = 3.14159265f;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;

            float4 watchFaceCol = float4(0, 0, 0, 1);
            float isWatchFace = 0;

            if (_HideWatchface < 0.5) {
                // Check if we're rendering the watchface
                float2 watchFaceCoords = ((IN.uv_MainTex - float2(0.5, 0)) * 2) - float2(0.5, 0.5);
                isWatchFace = (-0.5 <= watchFaceCoords.x && watchFaceCoords.x <= 0.5)
                    && (-0.5 <= watchFaceCoords.y && watchFaceCoords.y <= 0.5);

                // Check if we're rendering either of the bars
                float dist = pow(watchFaceCoords.x, 2) + pow(watchFaceCoords.y, 2);
                float isHpBar = pow((0.5 - _WatchfaceBarSize * 1), 2) < dist && dist < pow((0.5 - _WatchfaceBarSize * 0), 2);
                float isShieldBar = pow((0.5 - _WatchfaceBarSize * (_HasArmour > 0.5 ? 2 : 1)), 2) < dist && dist < pow((0.5 - _WatchfaceBarSize * 1), 2);

                // Adjust where the progress bars start/stop
                float progress = ((atan2(watchFaceCoords.y, watchFaceCoords.x) + PI) / (PI * 2));
                float offsetProgress = (progress + abs(_WatchfaceBarOffset)) % 1;
                #ifdef ENABLE_WATCHFACE_BAR_FLIP
                    offsetProgress = 1 - offsetProgress;
                #endif

                // Set the watchface color if we're rendering either of the bars and if that position is used up or not
                float hpBarThisFar = offsetProgress * _MaxHealth < _Health;
                float shildBarThisFar = offsetProgress * _MaxArmour < _Armour;
                watchFaceCol = (((_HealthColor * hpBarThisFar) + (_HealthGoneColor * !hpBarThisFar)) * isHpBar)
                    + (((_ShieldColor * shildBarThisFar) + (_ShieldGoneColor * !shildBarThisFar)) * isShieldBar);
            }

            // Standard shader stuff again
            o.Albedo = c.rgb * !isWatchFace + watchFaceCol * isWatchFace;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
            o.Emission = watchFaceCol * isWatchFace;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
