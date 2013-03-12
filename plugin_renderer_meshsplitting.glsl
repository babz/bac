//<vertex>
	varying vec3 varPoint;

	void main()
	{		
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
		varPoint = gl_Position.xyz;
	}
//</vertex>


//<fragment>
	uniform vec3 uPlanePoint;
	uniform vec3 uNormal;
		
	varying vec3 varPoint;

	void main()
	{
		//(v - p) * N
		float isBeforePlane = dot((varPoint - uPlanePoint),uNormal);
		
		if (isBeforePlane > 0.0) {
			//gl_FragColor = gl_Color;
			gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0);
		} else {
			discard;
			//gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0); //black
		}
	}
//</fragment>
