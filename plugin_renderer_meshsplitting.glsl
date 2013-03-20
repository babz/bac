//<vertex>
	varying vec3 varPoint;
	
	void main()
	{		
		gl_Position = ftransform(); //gl_ModelViewProjectionMatrix * gl_Vertex;
		varPoint = gl_Vertex.xyz;
		gl_FrontColor = gl_Color;
		gl_BackColor = gl_Color;
		gl_FrontSecondaryColor = gl_SecondaryColor;
		gl_BackSecondaryColor = gl_SecondaryColor;
	}
//</vertex>


//<fragment>
	uniform vec3 uPlanePoint;
	uniform vec3 uNormal;
		
	varying vec3 varPoint;

	void main()
	{		
		//(v - p) * N
		float isBeforePlane = dot((varPoint - uPlanePoint), uNormal);
		vec4 color = (gl_FrontLightModelProduct.sceneColor  +
				 (gl_FrontMaterial.ambient) +
				 (gl_FrontMaterial.diffuse) +
				 (gl_FrontMaterial.specular));
		
		//gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0);
		if (isBeforePlane > 0.0) {
			//if point is inside cow - give it color (like backface culling; based on N)
			
			//TODO add phong shading
			gl_FragColor = color ;
			//gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0);
		} else {
			//gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
			discard;
		}
	}
//</fragment>
