#version 120

//<vertex>
	varying vec3 varPoint;
	
	varying vec3 positionVertex;
	varying vec3 normalVertex;
	
	void main()
	{		
		// Transform the vertex position to eye space
		positionVertex = vec3(gl_ModelViewMatrix * gl_Vertex);
	       
		// Calculate the normal
		normalVertex = normalize(gl_NormalMatrix * gl_Normal);
	
		gl_Position = ftransform(); //gl_ModelViewProjectionMatrix * gl_Vertex;
		varPoint = gl_Vertex.xyz;
	}
//</vertex>


//<fragment>
	uniform vec3 uPlanePoint;
	uniform vec3 uNormal;
		
	varying vec3 varPoint;

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
		vec3 v = normalize(positionVertex);
		vec3 n = normalize(normalVertex);
		
		vec4 ambient, diffuse, specular, color;
		
		// Initialize the contributions.
		ambient  = vec4(0.0);
		diffuse  = vec4(0.0);
		specular = vec4(0.0);
		
		// In this case the built in uniform gl_MaxLights is used
		// to denote the number of lights. A better option may be passing
		// in the number of lights as a uniform or replacing the current
		// value with a smaller value.
		calculateLighting(gl_MaxLights, n, v, gl_FrontMaterial.shininess,
						  ambient, diffuse, specular);
						  
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
		
		
		//(v - p) * N
		float isBeforePlane = dot((varPoint - uPlanePoint), uNormal);
		
		if(isBeforePlane <= 0.0) {
			discard;
		}
		if(!gl_FrontFacing) {
			gl_FragData[0] = vec4(1.0, 0.0, 0.0, 1.0);
		}
	}
//</fragment>
