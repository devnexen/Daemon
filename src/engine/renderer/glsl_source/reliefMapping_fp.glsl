/*
===========================================================================
Copyright (C) 2009-2011 Robert Beckebans <trebor_7@users.sourceforge.net>

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
// reliefMapping_vp.glsl - Relief mapping helper functions

uniform int u_HeightMapInNormalMap;
uniform vec3 u_NormalFormat;

struct light {
  vec4  center_radius;
  vec4  color_type;
  vec4  direction_angle;
};

#ifdef HAVE_ARB_uniform_buffer_object
layout(std140) uniform u_Lights {
  light lights[ MAX_REF_LIGHTS ];
};
#define GetLight(idx, component) lights[idx].component
#else
uniform sampler2D u_Lights;
#define idxToTC( idx, w, h ) vec2( floor( ( idx * ( 1.0 / w ) ) + 0.5 ) * ( 1.0 / h ), \
				   fract( ( idx + 0.5 ) * (1.0 / w ) ) )
const struct GetLightOffsets {
  int center_radius;
  int color_type;
  int direction_angle;
} getLightOffsets = GetLightOffsets(0, 1, 2);
#define GetLight(idx, component) texture2D( u_Lights, idxToTC(3 * idx + getLightOffsets.component, 64.0, float( 3 * MAX_REF_LIGHTS / 64 ) ) )
#endif

uniform int u_numLights;

uniform vec2 u_SpecularExponent;

// lighting helper functions
void computeLight( vec3 lightDir, vec3 normal, vec3 eyeDir, vec3 lightColor,
		   vec4 diffuseColor, vec4 specularColor,
		   inout vec4 accumulator ) {
  vec3 H = normalize( lightDir + eyeDir );
  float NdotH = clamp( dot( normal, H ), 0.0, 1.0 );

#if defined( USE_PHYSICAL_SHADING )
  float metalness = specularColor.x;
  float roughness = specularColor.y;

  float NdotV = clamp( dot( normal, eyeDir ), 0.0, 1.0);
  float VdotH = clamp( dot( eyeDir, H ), 0.0, 1.0);
  float NdotL = clamp( dot( normal, lightDir ), 0.0, 1.0 );

  float alpha = roughness * roughness;
  float k = 0.125 * (roughness + 1.0) * (roughness + 1.0);

  float D = alpha / ((NdotH * NdotH) * (alpha * alpha - 1.0) + 1.0);
  D *= D;

  float FexpNH = pow(1.0 - NdotH, 5.0);
  float FexpNV = pow(1.0 - NdotV, 5.0);
  vec3 F = mix(vec3(0.04), diffuseColor.xyz, metalness);
  F = F + (1.0 - F) * FexpNH;

  float G = NdotL / (NdotL * (1.0 - k) + k);
  G *= NdotV / (NdotV * (1.0 - k) + k);

  accumulator.xyz += lightColor.xyz * (1.0 - metalness) * NdotL * diffuseColor.xyz;
  accumulator.xyz += lightColor.xyz * vec3((D * F * G) / (4.0 * NdotV));
  accumulator.a = mix(diffuseColor.a, 1.0, FexpNV);
#else
  float NdotL = dot( normal, lightDir );
#if defined(r_HalfLambertLighting)
  // http://developer.valvesoftware.com/wiki/Half_Lambert
  NdotL = NdotL * 0.5 + 0.5;
  NdotL *= NdotL;
#elif defined(r_WrapAroundLighting)
  NdotL = clamp( NdotL + r_WrapAroundLighting, 0.0, 1.0) / clamp(1.0 + r_WrapAroundLighting, 0.0, 1.0);
#else
  NdotL = clamp( NdotL, 0.0, 1.0 );
#endif

  accumulator.xyz += diffuseColor.xyz * lightColor.xyz * NdotL;
  accumulator.xyz += specularColor.xyz * lightColor.xyz * pow( NdotH, u_SpecularExponent.x * specularColor.w + u_SpecularExponent.y) * r_SpecularScale;
#endif
}

#if defined( TEXTURE_INTEGER )
const int lightsPerLayer = 16;
uniform usampler3D u_LightTiles;
#define idxs_t uvec4
idxs_t fetchIdxs( in vec3 coords ) {
  return texture3D( u_LightTiles, coords );
}
int nextIdx( inout idxs_t idxs ) {
  uvec4 tmp = ( idxs & uvec4( 3 ) ) * uvec4( 0x40, 0x10, 0x04, 0x01 );
  idxs = idxs >> 2;
  return int( tmp.x + tmp.y + tmp.z + tmp.w );
}
#else
const int lightsPerLayer = 4;
uniform sampler3D u_LightTiles;
#define idxs_t vec4
idxs_t fetchIdxs( in vec3 coords ) {
  return texture3D( u_LightTiles, coords ) * 255.0;
}
int nextIdx( inout idxs_t idxs ) {
  vec4 tmp = idxs;
  idxs = floor(idxs * 0.25);
  tmp -= 4.0 * idxs;
  return int( dot( tmp, vec4( 64.0, 16.0, 4.0, 1.0 ) ) );
}
#endif

const int numLayers = MAX_REF_LIGHTS / 256;

void computeDLight( int idx, vec3 P, vec3 N, vec3 I, vec4 diffuse,
		    vec4 specular, inout vec4 color ) {
  vec4 center_radius = GetLight( idx, center_radius );
  vec4 color_type = GetLight( idx, color_type );
  vec3 L;
  float attenuation;

  if( color_type.w == 0.0 ) {
    // point light
    L = center_radius.xyz - P;
    attenuation = 1.0 / (1.0 + 8.0 * length(L) / center_radius.w);
    L = normalize(L);
  } else if( color_type.w == 1.0 ) {
    // spot light
    vec4 direction_angle = GetLight( idx, direction_angle );
    L = center_radius.xyz - P;
    attenuation = 1.0 / (1.0 + 8.0 * length(L) / center_radius.w);
    L = normalize( L );

    if( dot( L, direction_angle.xyz ) <= direction_angle.w ) {
      attenuation = 0.0;
    }
  } else if( color_type.w == 2.0 ) {
    // sun (directional) light
    L = GetLight( idx, direction_angle ).xyz;
    attenuation = 1.0;
  }
  computeLight( L, N, I,
		attenuation * attenuation * color_type.xyz,
		diffuse, specular, color );
}

void computeDLights( vec3 P, vec3 N, vec3 I, vec4 diffuse, vec4 specular,
		     inout vec4 color ) {
  vec2 tile = floor( gl_FragCoord.xy * (1.0 / float( TILE_SIZE ) ) ) + 0.5;
  vec3 tileScale = vec3( r_tileStep, 1.0/numLayers );

#if defined(r_showLightTiles)
  float numLights = 0.0;
#endif

  for( int layer = 0; layer < numLayers; layer++ ) {
    idxs_t idxs = fetchIdxs( tileScale * vec3( tile, float( layer ) + 0.5 ) );
    for( int i = 0; i < lightsPerLayer; i++ ) {
      int idx = numLayers * nextIdx( idxs ) + layer;

      if( idx > u_numLights )
      {
#if defined(r_showLightTiles)
        if (numLights > 0.0)
        {
          color = vec4(numLights/(lightsPerLayer*numLayers), numLights/(lightsPerLayer*numLayers), numLights/(lightsPerLayer*numLayers), 1.0);
        }
#endif
        return;
      }

      computeDLight( idx, P, N, I, diffuse, specular, color );

#if defined(r_showLightTiles)
      numLights++;
#endif
    }
  }
  
#if defined(r_showLightTiles)
  if (numLights > 0.0)
  {
    color = vec4(numLights/(lightsPerLayer*numLayers), numLights/(lightsPerLayer*numLayers), numLights/(lightsPerLayer*numLayers), 1.0);
  }
#endif
}

vec3 normalFlip(vec3 normal)
{
	// undefined (zero) means default means 1.0 means do nothing

	if (u_NormalFormat.x < 0.0)
	{
		normal.x *= -1.0;
	}

	if (u_NormalFormat.y < 0.0)
	{
		normal.y *= -1.0;
	}

	if (u_NormalFormat.z < 0.0)
	{
		normal.z *= -1.0;
	}

	return normal;
}

// compute normal in tangent space
vec3 NormalInTangentSpace(sampler2D normalMap, vec2 texNormal)
{
	vec3 normal;
	if (u_HeightMapInNormalMap == 0)
	{
		// the Capcom trick abusing alpha channel of DXT1/5 formats to encode normal map
		// https://github.com/DaemonEngine/Daemon/issues/183#issuecomment-473691252
		//
		// the algorithm also works with normal maps in rgb format without alpha channel
		// but we still must be sure there is no height map in alpha channel hence the test
		//
		// crunch -dxn seems to produce such files, since alpha channel is abused such format
		// is unsuitable to embed height map, then height map must be distributed as loose file
		normal = texture2D(normalMap, texNormal).rga;
		normal.x *= normal.z;
		normal.xy = 2.0 * normal.xy - 1.0;
		normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));
	}
	else
	{
		// alpha channel contains the height map so do not try to restore the normal map from it
		normal = texture2D(normalMap, texNormal).rgb;
		normal = 2.0 * normal - 1.0;
	}

	normal = normalFlip(normal);

#if defined(r_NormalScale)
	normal.z *= r_NormalScale;
#endif

	return normal;
}

// compute normal in worldspace from normalmap
vec3 NormalInWorldSpace(sampler2D normalMap, vec2 texNormal, mat3 tangentToWorldMatrix)
{
	// compute normal in tangent space from normalmap
	vec3 normal = NormalInTangentSpace(normalMap, texNormal);
	// transform normal into world space
	return normalize(tangentToWorldMatrix * normal);
}

#if defined(USE_PARALLAX_MAPPING)
// compute texcoords offset from heightmap
// most of the code doing somewhat the same is likely to be named
// RayIntersectDisplaceMap in other id tech3-based engines
// so please keep the comment above to enable cross-tree look-up
vec2 ParallaxTexOffset(sampler2D normalMap, vec2 rayStartTexCoords, float parallaxDepthScale, float parallaxOffsetBias, vec3 viewDir, mat3 tangentToWorldMatrix)
{
	// compute view direction in tangent space
	vec3 tangentViewDir = normalize(viewDir * tangentToWorldMatrix);

	vec2 displacement = tangentViewDir.xy * -parallaxDepthScale / tangentViewDir.z;

	const int linearSearchSteps = 16;
	const int binarySearchSteps = 6;

	float depthStep = 1.0 / float(linearSearchSteps);
	float topDepth = 1.0 - parallaxOffsetBias;

	// current size of search window
	float currentSize = depthStep;

	// current depth position
	float currentDepth = 0.0;

	// best match found (starts with last position 1.0)
	float bestDepth = 1.0;

	// search front to back for first point inside object
	for(int i = 0; i < linearSearchSteps - 1; ++i)
	{
		currentDepth += currentSize;

		float heightMapDepth = topDepth - texture2D(normalMap, rayStartTexCoords + displacement * currentDepth).a;

		if(bestDepth > 0.996) // if no depth found yet
		{
			if(currentDepth >= heightMapDepth)
			{
				bestDepth = currentDepth;
			}
		}
	}

	currentDepth = bestDepth;

	// recurse around first point (depth) for closest match
	for(int i = 0; i < binarySearchSteps; ++i)
	{
		currentSize *= 0.5;

		float heightMapDepth = topDepth - texture2D(normalMap, rayStartTexCoords + displacement * currentDepth).a;

		if(currentDepth >= heightMapDepth)
		{
			bestDepth = currentDepth;
			currentDepth -= 2.0 * currentSize;
		}

		currentDepth += currentSize;
	}

	return bestDepth * displacement;
}
#endif
