/*
===========================================================================
Copyright (C) 2006-2011 Robert Beckebans <trebor_7@users.sourceforge.net>

This file is part of XreaL source code.

XreaL source code is free software; you can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the License,
or (at your option) any later version.

XreaL source code is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with XreaL source code; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
===========================================================================
*/

/* lightMapping_fp.glsl */
uniform sampler2D	u_DiffuseMap;
uniform sampler2D	u_NormalMap;
uniform sampler2D	u_SpecularMap;
uniform sampler2D	u_GlowMap;
uniform sampler2D	u_LightMap;
uniform sampler2D	u_DeluxeMap;
uniform float		u_AlphaThreshold;
uniform vec3		u_ViewOrigin;
uniform float		u_ParallaxDepthScale;
uniform float		u_ParallaxOffsetBias;

IN(smooth) vec3		var_Position;
IN(smooth) vec4		var_TexDiffuseGlow;
IN(smooth) vec4		var_TexNormalSpecular;
IN(smooth) vec2		var_TexLight;

IN(smooth) vec3		var_Tangent;
IN(smooth) vec3		var_Binormal;
IN(smooth) vec3		var_Normal;

IN(smooth) vec4		var_Color;

DECLARE_OUTPUT(vec4)

void	main()
{
	// compute view direction in world space
	vec3 viewDir = normalize(u_ViewOrigin - var_Position);

	vec2 texDiffuse = var_TexDiffuseGlow.st;
	vec2 texGlow = var_TexDiffuseGlow.pq;
	vec2 texNormal = var_TexNormalSpecular.st;
	vec2 texSpecular = var_TexNormalSpecular.pq;

	mat3 tangentToWorldMatrix = mat3(var_Tangent.xyz, var_Binormal.xyz, var_Normal.xyz);

#if defined(USE_PARALLAX_MAPPING)
	// compute texcoords offset from heightmap
	vec2 texOffset = ParallaxTexOffset(u_NormalMap, texNormal, u_ParallaxDepthScale, u_ParallaxOffsetBias, viewDir, tangentToWorldMatrix);

	texDiffuse += texOffset;
	texGlow += texOffset;
	texNormal += texOffset;
	texSpecular += texOffset;
#endif // USE_PARALLAX_MAPPING

	// compute the diffuse term
	vec4 diffuse = texture2D(u_DiffuseMap, texDiffuse);

	if( abs(diffuse.a + u_AlphaThreshold) <= 1.0 )
	{
		discard;
		return;
	}

	// compute the specular term
	vec4 specular = texture2D(u_SpecularMap, texSpecular);

	// compute normal in world space from normalmap
	vec3 N = NormalInWorldSpace(u_NormalMap, texNormal, tangentToWorldMatrix);

	// compute light color from world space lightmap
	vec3 lightColor = texture2D(u_LightMap, var_TexLight).xyz;

	vec4 color = vec4( 0.0, 0.0, 0.0, diffuse.a );

	// compute light direction in world space
	vec4 deluxe = texture2D(u_DeluxeMap, var_TexLight);
	if( deluxe.w < 0.5 ) {
		// normal/deluxe mapping is disabled
		color.xyz += lightColor.xyz * diffuse.xyz;
	} else {
		vec3 L = 2.0 * deluxe.xyz - 1.0;
		L = normalize(L);

		// divide by cosine term to restore original light color
		lightColor /= clamp(dot(normalize(var_Normal), L), 0.004, 1.0);

		// compute final color
		computeLight( L, N, viewDir, lightColor, diffuse, specular, color );
	}
	computeDLights( var_Position, N, viewDir, diffuse, specular, color );

	color.rgb += texture2D(u_GlowMap, texGlow).rgb;

	outputColor = color;

#if defined(r_showLightMaps)
	outputColor = texture2D(u_LightMap, var_TexLight);
#elif defined(r_showDeluxeMaps)
	outputColor = texture2D(u_DeluxeMap, var_TexLight);
#endif
}
