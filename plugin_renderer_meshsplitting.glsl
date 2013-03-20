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

	void main()
	{		
		vec3 V = normalize(positionVertex);
		vec3 N = normalize(normalVertex);
		
		vec4 ambient = vec4(0.0);
		vec4 diffuse = vec4(0.0);
		vec4 specular = vec4(0.0);
		
		//(v - p) * N
		float isBeforePlane = dot((varPoint - uPlanePoint), uNormal);
		
		if (isBeforePlane > 0.0) {
			//if point is inside cow - give it color (like backface culling; based on N)
			
			//Phong shading
			directionalLight(gl_LightSource[0], N, V, gl_FrontMaterial.shininess, ambient, diffuse, specular);
			
			gl_FragColor = (gl_FrontLightModelProduct.sceneColor  +
				 (ambient  * gl_FrontMaterial.ambient) +
				 (diffuse  * gl_FrontMaterial.diffuse) +
				 (specular * gl_FrontMaterial.specular));
			
		} else {
			//gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
			discard;
		}
	}
//</fragment>
