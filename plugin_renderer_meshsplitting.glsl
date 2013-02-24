#version 120
#extension GL_EXT_gpu_shader4 : enable

//////////////////////////////////////////////////////////////////////////
//<vertex>
//////////////////////////////////////////////////////////////////////////

	varying out vec3 positionVertex;
	varying out vec3 normalVertex;

	void main()
	{
		// Transform the vertex position to eye space
		positionVertex = vec3(gl_ModelViewMatrix * gl_Vertex);
	       
		// Calculate the normal
		normalVertex = normalize(gl_NormalMatrix * gl_Normal);

	   	gl_Position = ftransform();
		gl_TexCoord[0] = gl_MultiTexCoord0;
		gl_FrontColor = gl_Color;
		gl_BackColor = gl_Color;
		gl_FrontSecondaryColor = gl_SecondaryColor;
		gl_BackSecondaryColor = gl_SecondaryColor;
	}

//////////////////////////////////////////////////////////////////////////
//</vertex>
//////////////////////////////////////////////////////////////////////////

//<option name="mode" value="wireframe">	

//////////////////////////////////////////////////////////////////////////
//<geometry>
//////////////////////////////////////////////////////////////////////////

#extension GL_EXT_geometry_shader4 : enable
	
	
	varying in vec3 positionVertex[3];
	varying in vec3 normalVertex[3];
	
	noperspective varying out vec3 edgeness;
	varying out vec3 position;
	varying out vec3 normal;

	void main(void)
	{
		const vec2 vecScale = vec2(128.0,128.0);
		
		vec2 p0 = vecScale * gl_PositionIn[0].xy/gl_PositionIn[0].w;
		vec2 p1 = vecScale * gl_PositionIn[1].xy/gl_PositionIn[1].w;
		vec2 p2 = vecScale * gl_PositionIn[2].xy/gl_PositionIn[2].w;

		vec2 v0 = p2-p1;
		vec2 v1 = p2-p0;
		vec2 v2 = p1-p0;

		float area = abs(v1.x*v2.y - v1.y * v2.x);
		edgeness = vec3(area/length(v0),0,0);		
		position = positionVertex[0];
		normal = normalVertex[0];
		gl_Position = gl_PositionIn[0];
		gl_FrontColor = gl_FrontColorIn[0]; 
		gl_FrontSecondaryColor = gl_FrontSecondaryColorIn[0];
		EmitVertex();

		edgeness = vec3(0,area/length(v1),0);
		position = positionVertex[1];
		normal = normalVertex[1];
		gl_Position = gl_PositionIn[1];
		gl_FrontColor = gl_FrontColorIn[1]; 
		gl_FrontSecondaryColor = gl_FrontSecondaryColorIn[1];
		EmitVertex();

		edgeness = vec3(0,0,area/length(v2));		
		position = positionVertex[2];
		normal = normalVertex[2];
		gl_Position = gl_PositionIn[2];
		gl_FrontColor = gl_FrontColorIn[2]; 
		gl_FrontSecondaryColor = gl_FrontSecondaryColorIn[2];
		EmitVertex();

		EndPrimitive();
	}

//////////////////////////////////////////////////////////////////////////
//</geometry>
//////////////////////////////////////////////////////////////////////////

//</option>	

//////////////////////////////////////////////////////////////////////////
//<fragment>
//////////////////////////////////////////////////////////////////////////

//<option name="mode" value="normal">

	uniform bool bDiffuseTexture = false;
	uniform sampler2D samDiffuseTexture;

	varying vec3 positionVertex;
	varying vec3 normalVertex;

	const vec4 AMBIENT_BLACK = vec4(0.0, 0.0, 0.0, 1.0);
	const vec4 DEFAULT_BLACK = vec4(0.0, 0.0, 0.0, 0.0);

	bool isLightEnabled(const int i)
	{
		// A separate variable is used to get
		// rid of a linker error.
		bool enabled = true;
	   
		// If all the colors of the Light are set
		// to BLACK then we know we don't need to bother
		// doing a lighting calculation on it.
		if ((gl_LightSource[i].ambient  == AMBIENT_BLACK) &&
			(gl_LightSource[i].diffuse  == DEFAULT_BLACK) &&
			(gl_LightSource[i].specular == DEFAULT_BLACK))
			enabled = false;
	       
		return(enabled);
	}

	bool isLightEnabled(gl_LightSourceParameters light)
	{
		// A separate variable is used to get
		// rid of a linker error.
		bool enabled = true;
	   
		// If all the colors of the Light are set
		// to BLACK then we know we don't need to bother
		// doing a lighting calculation on it.
		if ((light.ambient  == AMBIENT_BLACK) &&
			(light.diffuse  == DEFAULT_BLACK) &&
			(light.specular == DEFAULT_BLACK))
			enabled = false;
	       
		return(enabled);
	}

	float calculateAttenuation(in gl_LightSourceParameters light, in float dist)
	{
		return(1.0 / (light.constantAttenuation +
					  light.linearAttenuation * dist +
					  light.quadraticAttenuation * dist * dist));
	}

	void directionalLight(in gl_LightSourceParameters light, in vec3 N, in vec3 V, in float shininess,
						  inout vec4 ambient, inout vec4 diffuse, inout vec4 specular)
	{
		vec3 L = normalize(light.position.xyz);
	   
		float nDotL = dot(N, L);
	   
		if (nDotL > 0.0)
		{   
			vec3 H = normalize(light.halfVector.xyz);
	       
			float pf = pow(max(dot(N,H), 0.0), shininess);

			diffuse  += light.diffuse  * nDotL;
			specular += light.specular * pf;
		}
	   
		ambient  += light.ambient;
	}

	void pointLight(in gl_LightSourceParameters light, in vec3 N, in vec3 V, in float shininess,
					inout vec4 ambient, inout vec4 diffuse, inout vec4 specular)
	{
		vec3 D = light.position.xyz - V;
		vec3 L = normalize(D);

		float dist = length(D);
		float attenuation = calculateAttenuation(light, dist);

		float nDotL = dot(N,L);

		if (nDotL > 0.0)
		{   
			vec3 E = normalize(-V);
			vec3 R = reflect(-L, N);
	       
			float pf = pow(max(dot(R,E), 0.0), shininess);

			diffuse  += light.diffuse  * attenuation * nDotL;
			specular += light.specular * attenuation * pf;
		}
	   
		ambient  += light.ambient * attenuation;
	}

	void spotLight(in gl_LightSourceParameters light, in vec3 N, in vec3 V, in float shininess,
				   inout vec4 ambient, inout vec4 diffuse, inout vec4 specular)
	{
		vec3 D = light.position.xyz - V;
		vec3 L = normalize(D);

		float dist = length(D);
		float attenuation = calculateAttenuation(light, dist);

		float nDotL = dot(N,L);

		if (nDotL > 0.0)
		{   
			float spotEffect = dot(normalize(light.spotDirection), -L);
	       
			if (spotEffect > light.spotCosCutoff)
			{
				attenuation *=  pow(spotEffect, light.spotExponent);

				vec3 E = normalize(-V);
				vec3 R = reflect(-L, N);
	       
				float pf = pow(max(dot(R,E), 0.0), shininess);

				diffuse  += light.diffuse  * attenuation * nDotL;
				specular += light.specular * attenuation * pf;
			}
		}
	   
		ambient  += light.ambient * attenuation;
	}

	void calculateLighting(in gl_LightSourceParameters light, in vec3 N, in vec3 V, in float shininess,
						   inout vec4 ambient, inout vec4 diffuse, inout vec4 specular)
	{
		// Just loop through each light, and if its enabled add
		// its contributions to the color of the pixel.
		{
			if (isLightEnabled(light))
			{
				if (light.position.w == 0.0)
					directionalLight(light, N, V, shininess, ambient, diffuse, specular);
				else if (light.spotCutoff == 180.0)
					pointLight(light, N, V, shininess, ambient, diffuse, specular);
				else
					 spotLight(light, N, V, shininess, ambient, diffuse, specular);
			}
		}
	}
				
	void calculateLighting(in int numLights, in vec3 N, in vec3 V, in float shininess,
						   inout vec4 ambient, inout vec4 diffuse, inout vec4 specular)
	{
		if (numLights > 0)
			calculateLighting(gl_LightSource[0], N, V, shininess, ambient, diffuse, specular);
		if (numLights > 1)
			calculateLighting(gl_LightSource[1], N, V, shininess, ambient, diffuse, specular);
		if (numLights > 2)
			calculateLighting(gl_LightSource[2], N, V, shininess, ambient, diffuse, specular);
	}

	void main()
	{
		// Normalize the normal. A varying variable CANNOT
		// be modified by a fragment shader. So a new variable
		// needs to be created.
		vec3 v = normalize(positionVertex);
		vec3 n = normalize(normalVertex);
	   
		vec4 ambient, diffuse, specular, color;
		
		// Initialize the contributions.
		ambient  = vec4(0.0);
		diffuse  = vec4(0.0);
		specular = vec4(0.0);
	   
		vec4 vecDiffuseTexture = vec4(1.0,1.0,1.0,1.0);

		if (bDiffuseTexture)
			vecDiffuseTexture = texture2D(samDiffuseTexture, gl_TexCoord[0].xy);

		// In this case the built in uniform gl_MaxLights is used
		// to denote the number of lights. A better option may be passing
		// in the number of lights as a uniform or replacing the current
		// value with a smaller value.
		calculateLighting(gl_MaxLights, n, v, gl_FrontMaterial.shininess,
						  ambient, diffuse, specular);

		diffuse *= vecDiffuseTexture;
   
		color.rgb  = (gl_FrontLightModelProduct.sceneColor  +
				 (ambient  * gl_FrontMaterial.ambient) +
				 (diffuse  * gl_FrontMaterial.diffuse) +
				 (specular * gl_FrontMaterial.specular)).rgb;

		// Re-initialize the contributions for the back
		// pass over the lights
		ambient  = vec4(0.0);
		diffuse  = vec4(0.0);
		specular = vec4(0.0);
	          
		// Now caculate the back contribution. All that needs to be
		// done is to flip the normal.
		calculateLighting(gl_MaxLights, -n, v, gl_BackMaterial.shininess,
						  ambient, diffuse, specular);

		diffuse *= vecDiffuseTexture;

		color.rgb += (gl_BackLightModelProduct.sceneColor  +
				 (ambient  * gl_BackMaterial.ambient) +
				 (diffuse  * gl_BackMaterial.diffuse) +
				 (specular * gl_BackMaterial.specular)).rgb;

		float nDotE = dot(n,-v);

		float fOpacity = max(gl_FrontMaterial.diffuse.a,gl_BackMaterial.diffuse.a);

		color.a = mix((smoothstep(0.0,0.75,1.0-(pow(abs(nDotE),fOpacity)))),fOpacity,fOpacity);// * smoothstep(0.0,1.0,abs(nDotE));
		color = clamp(color, 0.0, 1.0);
	
		color.rgb *= color.a;
		gl_FragData[0] = color;
		

		//<option name="normals" value="true">
		const float fEpsilon = 0.01;
		float fGs = n.z < fEpsilon ? 1.0 / fEpsilon : 1.0 / n.z;
		float fGx  = -n.x*fGs; 
		float fGy  = -n.y*fGs;

		vec4 vecNear = gl_ProjectionMatrixInverse*vec4(0.0,0.0,-1.0,1.0);
		vecNear /= vecNear.w;

		vec4 vecFar = gl_ProjectionMatrixInverse*vec4(0.0,0.0,1.0,1.0);
		vecFar /= vecFar.w;
		
		float fZmin = max(-vecNear.z,fEpsilon);
		float fZmax = max(-vecFar.z,fEpsilon);

		float fDepth = log(clamp(-positionVertex.z,fZmin,fZmax)/fZmin)/log(fZmax/fZmin);
		gl_FragData[1] = vec4(fGx,fGy,n.z,fDepth);
		//</option>
	}

//</option>

//<option name="mode" value="fancy">

	varying vec3 positionVertex;
	varying vec3 normalVertex;
	
	vec3 computeAsngan(in vec3 n,in vec3 v,in vec3 l, in vec3 diffuse, in vec3 specular, in float exponent, in float fresnel)
	{
	  float NDotL = max(dot(n,l),0.0);
	  
	  if (NDotL <= 0.0)
		vec3(0.0,0.0,0.0);

	  vec3  h = normalize(l-v);
	
	  float VDotH = max(dot(-v,h),0.0);
	  float NDotH = max(dot(n,h),0.0);
	  float NDotV = max(dot(n,-v),0.0);
	
	  const float INV_PI = 0.3183098861;
	  const float PI_23  = 72.256631032;
	  const float PI_8   = 25.132741228;

	  vec3  d = diffuse;
	  vec3  s = specular;
	  float e = exponent*2.0;
	  float f = fresnel;
	  float r = (d.x+d.y+d.z)*0.333333;


	  
	  float normalization = (e+1.0)/PI_8;


	  float specTerm = max(((pow(NDotH,e)/(VDotH*max(NDotL,NDotV)))*normalization*(f+(1.0-f)*pow(VDotH,5.0))),0.0);
	  float diffTerm = max((((28.0*r)/PI_23)*(1.0-f)*(1.0-pow(1.0-(NDotL/2.0),5.0))*(1.0-pow(1.0-(NDotV/2.0),5.0))),0.0);
	  
	  return d*diffTerm+s*specTerm;
	}	

	void main()
	{
		vec3 v = normalize(positionVertex);
		vec3 n = normalize(normalVertex);

		vec3 l = normalize(gl_LightSource[0].position.xyz);
		vec4 color =  gl_FrontLightModelProduct.sceneColor + gl_BackLightModelProduct.sceneColor;
				
		color.rgb += computeAsngan(n,v,l,gl_FrontMaterial.diffuse.rgb,gl_FrontMaterial.specular.rgb,gl_FrontMaterial.shininess,-2.0);
		color.rgb += computeAsngan(-n,v,l,gl_BackMaterial.diffuse.rgb,gl_BackMaterial.specular.rgb,gl_BackMaterial.shininess,-2.0);

		float nDotE = dot(n,-v);

		float fOpacity = max(gl_FrontMaterial.diffuse.a,gl_BackMaterial.diffuse.a);

		color.a = mix((smoothstep(0.0,0.75,1.0-(pow(abs(nDotE),fOpacity)))),fOpacity,fOpacity);// * smoothstep(0.0,1.0,abs(nDotE));
		color = clamp(color, 0.0, 1.0);
	
		color.rgb *= color.a;
		gl_FragData[0] = color;
		
		
		//<option name="normals" value="true">
		const float fEpsilon = 0.01;
		float fGs = n.z < fEpsilon ? 1.0 / fEpsilon : 1.0 / n.z;
		float fGx  = -n.x*fGs; 
		float fGy  = -n.y*fGs;

		vec4 vecNear = gl_ProjectionMatrixInverse*vec4(0.0,0.0,-1.0,1.0);
		vecNear /= vecNear.w;

		vec4 vecFar = gl_ProjectionMatrixInverse*vec4(0.0,0.0,1.0,1.0);
		vecFar /= vecFar.w;
		
		float fZmin = max(-vecNear.z,fEpsilon);
		float fZmax = max(-vecFar.z,fEpsilon);

		float fDepth = log(clamp(-positionVertex.z,fZmin,fZmax)/fZmin)/log(fZmax/fZmin);
		gl_FragData[1] = vec4(fGx,fGy,n.z,fDepth);
		//</option>
	}

//</option>

//<option name="mode" value="wireframe">

	noperspective varying vec3 edgeness;
	varying vec3 position;
	varying vec3 normal;
	
	void main(void)
	{
		vec3 n = normalize(normal);
			
		float fD = min(edgeness[0],min(edgeness[1],edgeness[2]));
		float fI1 = exp2(-2.0*fD*fD);
		float fI0 = smoothstep(0.5,1.0,fI1);

		vec4 vecResult = gl_Color*fI0;
		vecResult += (1.0-vecResult.a)*vec4(0.0,0.0,0.0,1.0)*fI1;
		vecResult += (1.0-vecResult.a)*gl_SecondaryColor;

		gl_FragData[0] = vecResult;
		
		//<option name="normals" value="true">
		const float fEpsilon = 0.01;
		float fGs = n.z < fEpsilon ? 1.0 / fEpsilon : 1.0 / n.z;
		float fGx  = -n.x*fGs; 
		float fGy  = -n.y*fGs;

		vec4 vecNear = gl_ProjectionMatrixInverse*vec4(0.0,0.0,-1.0,1.0);
		vecNear /= vecNear.w;

		vec4 vecFar = gl_ProjectionMatrixInverse*vec4(0.0,0.0,1.0,1.0);
		vecFar /= vecFar.w;
		
		float fZmin = max(-vecNear.z,fEpsilon);
		float fZmax = max(-vecFar.z,fEpsilon);

		float fDepth = log(clamp(-position.z,fZmin,fZmax)/fZmin)/log(fZmax/fZmin);
		gl_FragData[1] = vec4(fGx,fGy,n.z,fDepth);
		//</option>		
	}

//</option>

//<option name="mode" value="filter">

	uniform sampler2D samColor;
	uniform sampler2D samNormal;
	uniform int iSize;

	void main(void)
	{
		vec4 vecColors = vec4(0.0,0.0,0.0,0.0);
		vec4 vecColorWeights = vec4(0.0,0.0,0.0,0.0);

		vec4 vecNormals = vec4(0.0,0.0,0.0,0.0);
		vec4 vecNormalWeights = vec4(0.0,0.0,0.0,0.0);

		ivec2 vecColorTextureSize = textureSize2D(samColor,0);
		ivec2 vecNormalTextureSize = textureSize2D(samNormal,0);

		ivec2 vecPosition = ivec2(int(gl_FragCoord.x),int(gl_FragCoord.y));

		vec4 vecPreviousColor = texelFetch2D(samColor,vecPosition,0);
		vec4 vecPreviousNormal = texelFetch2D(samNormal,vecPosition,0);


		for (int j=-1;j<=1;j++)
		{
			for (int i=-1;i<=1;i++)
			{

				ivec2 vecOffset = ivec2(i,j);
				vec4 vecColor = texelFetch2D(samColor,vecPosition+vecOffset*iSize,0);
				vec4 vecNormal = texelFetch2D(samNormal,vecPosition+vecOffset*iSize,0);

				float fDistanceWeight = 1.0 - smoothstep(0.0,0.0125,abs(vecPreviousNormal.w-vecNormal.w));
				float fDirectionWeight = 1.0 - smoothstep(0.0,0.125,abs(vecPreviousNormal.z-vecNormal.z));
				float fWeight = fDistanceWeight*fDirectionWeight;

				vec4 vecColorWeight = vec4(1.0,1.0,1.0,1.0);
				vec4 vecNormalWeight = vec4(fWeight,fWeight,fWeight,1.0);

				vecColors += vecColor*vecColorWeight;
				vecNormals += vecNormal*vecNormalWeight;

				vecColorWeights += vecColorWeight;
				vecNormalWeights += vecNormalWeight;
			}
		}


		vecColors /= vecColorWeights;
		vecNormals /= vecNormalWeights;

		gl_FragData[0] = vecColors;
		gl_FragData[1] = vecNormals;

	}

//</option>

//<option name="mode" value="stylize">

	uniform sampler2D samColor;
	uniform sampler2D samNormal;

	uniform sampler2D samFilteredColor;
	uniform sampler2D samFilteredNormal;

	uniform sampler2D samDepth;

	vec3 color(float fValue)
	{
		if (fValue < 0.0)
			return mix(vec3(1.0,1.0,1.0),vec3(0.0,0.0,1.0),-fValue);
		else
			return mix(vec3(1.0,1.0,1.0),vec3(1.0,0.0,0.0),fValue);
	}

	vec4 over(vec4 vecF, vec4 vecB)
	{
		return vecF + (1.0-vecF.a)*vecB;
	}

	void main(void)
	{
	
		//todo test if pixel is in the plane
		//wrong: discard;
		
		ivec2 vecPosition = ivec2(int(gl_FragCoord.x),int(gl_FragCoord.y));

		vec4 vecColor = texelFetch2D(samColor,vecPosition,0);
		vec4 vecNormal = texelFetch2D(samNormal,vecPosition,0);
		float fDepth = texelFetch2D(samDepth,vecPosition,0).z;

		vec4 vecNormal1nx0py = texelFetch2DOffset(samNormal,vecPosition,0,ivec2(-1,0));
		vec4 vecNormal1px0py = texelFetch2DOffset(samNormal,vecPosition,0,ivec2(1,0));
		vec4 vecNormal0px1ny = texelFetch2DOffset(samNormal,vecPosition,0,ivec2(0,-1));
		vec4 vecNormal0px1py = texelFetch2DOffset(samNormal,vecPosition,0,ivec2(0,1));

		vec4 vecNormalX = vecNormal1px0py-vecNormal1nx0py;
		vec4 vecNormalY = vecNormal0px1py-vecNormal0px1ny;
		vec3 vecHessian = vec3(vecNormalX.x,vecNormalY.y,0.5*(vecNormalX.y+vecNormalY.x));
		float fTemporary = sqrt(vecHessian.x*vecHessian.x+4.0*vecHessian.z*vecHessian.z-2.0*vecHessian.x*vecHessian.y+vecHessian.y*vecHessian.y);
		vec2 vecCurvature = vec2(-0.5*(vecHessian.x+vecHessian.y+fTemporary),-0.5*(vecHessian.x+vecHessian.y-fTemporary));

		float fDistanceWeight = 1.0 - smoothstep(0.0,0.0125,0.5*(abs(vecNormalX.w)+abs(vecNormalY.w)));
		float fDirectionWeight = 1.0 - smoothstep(0.0,0.125,0.5*(abs(vecNormalX.z)+abs(vecNormalY.z)));


		vec4 vecFilteredColor = texelFetch2D(samFilteredColor,vecPosition,0);
		vec4 vecFilteredNormal = texelFetch2D(samFilteredNormal,vecPosition,0);

		vec4 vecFilteredNormal1nx0py = texelFetch2DOffset(samFilteredNormal,vecPosition,0,ivec2(-1,0));
		vec4 vecFilteredNormal1px0py = texelFetch2DOffset(samFilteredNormal,vecPosition,0,ivec2(1,0));
		vec4 vecFilteredNormal0px1ny = texelFetch2DOffset(samFilteredNormal,vecPosition,0,ivec2(0,-1));
		vec4 vecFilteredNormal0px1py = texelFetch2DOffset(samFilteredNormal,vecPosition,0,ivec2(0,1));

		vec4 vecFilteredNormalX = vecFilteredNormal1px0py-vecFilteredNormal1nx0py;
		vec4 vecFilteredNormalY = vecFilteredNormal0px1py-vecFilteredNormal0px1ny;
		vec3 vecFilteredHessian = vec3(vecFilteredNormalX.x,vecFilteredNormalY.y,0.5*(vecFilteredNormalX.y+vecFilteredNormalY.x));
		float fFilteredTemporary = sqrt(vecHessian.x*vecHessian.x+4.0*vecHessian.z*vecHessian.z-2.0*vecHessian.x*vecHessian.y+vecHessian.y*vecHessian.y);
		vec2 vecFilteredCurvature = vec2(-0.5*(vecFilteredHessian.x+vecFilteredHessian.y+fFilteredTemporary),-0.5*(vecFilteredHessian.x+vecFilteredHessian.y-fFilteredTemporary));

		float fFilteredDistanceWeight = 1.0 - smoothstep(0.0,0.0125,0.5*(abs(vecNormalX.w)+abs(vecNormalY.w)));
		float fFilteredDirectionWeight = 1.0 - smoothstep(0.0,0.125,0.5*(abs(vecNormalX.z)+abs(vecNormalY.z)));


		float fU = 1.0-smoothstep(0.0,0.125,0.5*(abs(vecNormalX.w)+abs(vecNormalY.w)));
		float fV = 1.0-smoothstep(0.0,0.125,0.5*(abs(vecNormalX.w)+abs(vecNormalY.w)));
		float fMean = (vecFilteredCurvature.x+vecFilteredCurvature.y)*0.5;

		float fI = vecNormal.w-vecFilteredNormal.w;
		float fX = fMean;

		float fFocus = (1.0-smoothstep(0.33,0.5,vecNormal.w));

		vec4 vecBase = vecFilteredColor;//(1.0-fFocus)*vecFilteredColor+fFocus*vecColor;

		vec4 vecResult = vec4(0.0,0.0,0.0,0.0);
		//mix(vec3(1.0,1.0,1.0),vecResult.rgb,min(1.0,max(0.0,-fX)))

		vec4 vecColor0 = vec4(0.0,0.0,0.0,1.0-fDistanceWeight);

		vec4 vecColor1 = mix(vec4(vecColor.rgb+vec3(0.5,0.5,0.5),vecColor.a),vec4(vecColor.rgb,vecColor.a),smoothstep(0.0,0.5,abs(fX)));
		vecColor1.rgb *= vecColor1.a;

	
/*
		vec4 vecColor2 = mix(vec4(vecFilteredColor.rgb+vec3(0.5,0.5,0.5),vecColor.a),vecColor,smoothstep(0.0,0.25,fX));
		vecColor2.rgb *= vecColor2.a;
*/

		//vecResult = over(vecColor0,vecResult);

		vecResult.rgb = vecColor.rgb  + clamp(fX * (1.0-fI),-0.5,0.5);//color(4.0*fX);//over(vecColor1,vecResult);

		//vecResult.rgb = vecColor.rgb  + (vec3(1.0,1.0,1.0)-vecFilteredColor.rgb)*clamp(fX * (1.0-fI),-0.5,0.5);//color(4.0*fX);//over(vecColor1,vecResult);

		//vecResult += vecColor;
		//vecResult = over(vecColor2,vecResult);

		vecResult.a = vecColor.a;
	//	vecResult = over(vecColor3,vecResult);
	//	vecResult = over(vecColor4,vecResult);

		//vecResult.rgb = mix(vec3(1.0,1.0,1.0),vecResult.rgb,min(1.0,max(0.0,fX)));//*fDistanceWeight;
		//color(fMean);//(vecColor.rgb)+ fV*fMean;//color(fMean);
		gl_FragColor = clamp(vecResult,0.0,1.0);//vec4(0.0,0.0,0.0,0.0),vec4(1.0,1.0,1.0,1.0));
		gl_FragDepth = fDepth;
	}

//</option>

//////////////////////////////////////////////////////////////////////////
//</fragment>
//////////////////////////////////////////////////////////////////////////

