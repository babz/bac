#version 120

//<vertex>
	uniform vec3 uNormal;
	
	varying vec3 vVertexPositionWorldSpace;
	varying vec3 vVertexPosition;	
	varying vec3 vVertexNormal;	

	varying vec3 vPlaneNormal;
	
	
	void main()
	{		
	    vVertexPositionWorldSpace = gl_Vertex.xyz; // World space
	    
		// Transform the vertex position to eye space
		gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex; // ftransform() is deprecated
		vVertexPosition = gl_Position.xyz;
	       
		// Transform the vertex normal to eye space
		vVertexNormal = normalize(gl_NormalMatrix * gl_Normal);
		vPlaneNormal = normalize (gl_NormalMatrix * uNormal);
		
		gl_FrontColor = gl_Color;
		gl_BackColor = vec4(0.0, 0.0, 1.0, 1.0);
		gl_FrontSecondaryColor = gl_SecondaryColor;
		gl_BackSecondaryColor = vec4(0.0, 0.0, 1.0, 1.0);
	}
//</vertex>


//<fragment>
	uniform vec3 uPlanePoint;
	uniform vec3 uNormal;
		
	varying vec3 vVertexPositionWorldSpace;
	varying vec3 vVertexPosition;	
	varying vec3 vVertexNormal;	

	varying vec3 vPlaneNormal;
	
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
	
		// discard pixels behind the cutting plane
	    //(v - p) * N
		float isBeforePlane = dot((vVertexPositionWorldSpace - uPlanePoint), uNormal);		
		if(isBeforePlane <= 0.0) {
			discard;
		}

		vec3 v = normalize(vVertexPosition);
		vec3 n = normalize(vVertexNormal);
		
		vec4 ambient = vec4(0.0);
		vec4 diffuse = vec4(0.0);
		vec4 specular = vec4(0.0);
		vec4 color = vec4(0.0);
		
		if(gl_FrontFacing) {    		
		
		    calculateLighting(gl_MaxLights, n, v, gl_FrontMaterial.shininess,
						      ambient, diffuse, specular);
    						  
		    color.rgb  = (gl_FrontLightModelProduct.sceneColor  +
				     (ambient  * gl_FrontMaterial.ambient) +
				     (diffuse  * gl_FrontMaterial.diffuse) +
				     (specular * gl_FrontMaterial.specular)).rgb;
				     
		    ambient  = vec4(0.0);
		    diffuse  = vec4(0.0);
		    specular = vec4(0.0);
		    
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
		
		/*
            color.a = gl_FrontMaterial.diffuse.a;
            color = clamp(color, 0.0, 1.0);
		    color.rgb *= color.a;    	
		*/
    	} else { // back facing fragments
    			
			calculateLighting(1, -n, v, 0.7,
						  ambient, diffuse, specular);

			color.rgb  = ((ambient  * vec4(1.0, 0.1, 0.0, 1.0)) +
				     (diffuse  * vec4(1.0, 0.1, 0.0, 1.0)) +
				     (specular * vec4(1.0, 1.0, 1.0, 1.0))).rgb;			
			color.a = 1.0;			
            color = clamp(color, 0.0, 1.0);
		}
	
		gl_FragColor = color;		
	}
//</fragment>
