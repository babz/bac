#pragma once

#include "volumeshop.h"

#include <list>
#include <set>
#include <map>

#include <iostream>
#include <fstream>
#include <string>

#include "RendererPlugin.h"
#include "PluginInstance.h"
#include "Renderer.h"
#include "Mesh.h"
#include "Shader.h"
#include "Exception.h"
#include "ResourceTexture2D.h"

class RendererMeshSplitting : public Renderer, public PluginInstance<RendererPlugin>
{

public:

	RendererMeshSplitting(Plugin & pluPlugin) : PluginInstance(pluPlugin), m_uWidth(1), m_uHeight(1), m_bPicking(false), 
		m_shaShader(pluPlugin.GetPluginDirectory()+"plugin_renderer_meshsplitting.glsl"), m_bUpdateGroups(true), 
		m_fraFramebuffer(m_uWidth,m_uHeight), m_texColorTexture0(GL_RGBA,GL_RGBA16F_ARB), m_texColorTexture1(GL_RGBA,GL_RGBA16F_ARB), 
		m_texColorTexture2(GL_RGBA,GL_RGBA16F_ARB), m_texColorTexture3(GL_RGBA,GL_RGBA16F_ARB), m_texColorTexture4(GL_RGBA,GL_RGBA16F_ARB), 
		m_texColorTexture5(GL_RGBA,GL_RGBA16F_ARB), m_texDepthTexture(GL_DEPTH_COMPONENT), m_bMouseDownInWindow(false)
	{
		m_modVariantObserver.connect(this,&RendererMeshSplitting::propertyModified);
		m_modMeshObserver.connect(this,&RendererMeshSplitting::meshModified);
		//
		m_modMeshObserver.connect(this,&RendererMeshSplitting::meshModified);

		//create params
		GetPlugin().GetProperty("Projection Transformation").require(Variant::TypeMatrix());
		GetPlugin().GetProperty("Projection Transformation").addObserver(&m_modVariantObserver);

		GetPlugin().GetProperty("Viewing Transformation").require(Variant::TypeMatrix());
		GetPlugin().GetProperty("Viewing Transformation").addObserver(&m_modVariantObserver);

		GetPlugin().GetProperty("Mesh").require(Variant::TypeHandle());
		GetPlugin().GetProperty("Mesh").addObserver(&m_modMeshObserver);

		GetPlugin().GetProperty("Mode").require((Variant::TypeOption(), Variant("Default"), Variant("Normal"), Variant("Fancy"), Variant("Wireframe")));
		GetPlugin().GetProperty("Mode").addObserver(&m_modVariantObserver);

		GetPlugin().GetProperty("Stylized").require(Variant::TypeBoolean(false));
		GetPlugin().GetProperty("Stylized").addObserver(&m_modVariantObserver);

		GetPlugin().GetProperty("Color").require(Variant::TypeColor());
		GetPlugin().GetProperty("Color").addObserver(&m_modVariantObserver);

		GetPlugin().GetProperty("Opacity").require(Variant::TypeFloat(1.0f, 0.0f, 1.0f));
		GetPlugin().GetProperty("Opacity").addObserver(&m_modVariantObserver);

		//todo adapt
		GetPlugin().GetProperty("PlaneDepth").require(Variant::TypeFloat(1.0f, 0.0f, 1.0f));
		GetPlugin().GetProperty("PlaneDepth").addObserver(&m_modVariantObserver);

		GetPlugin().GetProperty("Plane").require(Variant::TypeHandle());
		GetPlugin().GetProperty("Plane").addObserver(&m_modMeshObserver);

		GetPlugin().GetProperty("Selection").require(Variant::TypeString());


		Handle hanMesh = GetPlugin().GetProperty("Mesh");
		TriangleMesh *pMesh = hanMesh.GetResource<TriangleMesh>();

		//
		Handle hanPlane = GetPlugin().GetProperty("Plane");
		TriangleMesh *pPlane = hanPlane.GetResource<TriangleMesh>();

		if (pMesh)
			updateGroups(*pMesh);

		//
		//if (pPlane)
		//	updateGroups(*pPlane);

		GetPlugin().GetProperty("Groups").addObserver(&m_modVariantObserver);
	};
 
	virtual ~RendererMeshSplitting()
	{
	};

	virtual void idle()
	{
	};

	virtual void display(Canvas & canCanvas)
	{
		//todo print 2 cows 

		//todo print plane

		const Matrix matProjectionTransformation = GetPlugin().GetProperty("Projection Transformation");
		const Matrix matViewingTransformation = GetPlugin().GetProperty("Viewing Transformation");

		Handle hanMesh = GetPlugin().GetProperty("Mesh");
		TriangleMesh *pMesh = hanMesh.GetResource<TriangleMesh>();

		//
		//Handle hanPlane = GetPlugin().GetProperty("Plane");
		//TriangleMesh *pPlane = hanPlane.GetResource<TriangleMesh>();
		
		if (!pMesh) {
			return;
		}
		//todo do better
		//if (!pPlane) {
		//	return;
		//}

		const Matrix matMeshTransformation = pMesh->GetProperty("Transformation",Matrix());
		updateGroups(*pMesh);
		glMultMatrixf(matMeshTransformation.Get());

		//const Matrix matPlaneTransformation = pPlane->GetProperty("Transformation",Matrix());
		//updateGroups(*pPlane);
		//glMultMatrixf(matPlaneTransformation.Get());

		canCanvas.bind();

		glEnable(GL_DEPTH_TEST);
		glDepthMask(GL_TRUE);
		glDepthFunc(GL_LESS);
		glDisable(GL_BLEND);

		glMatrixMode(GL_PROJECTION);
		glLoadMatrixf(matProjectionTransformation.Get());

		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();

		const float vfPosition[] = { 0.0f, 0.0f, 1.0f, 0.0f };
		const float vfAmbient[] = { 0.3f, 0.3f, 0.3f, 1.0f };
		const float vfDiffuse[] = { 0.9f, 0.9f, 0.9f, 1.0f };
		const float vfSpecular[] = { 0.7f, 0.7f, 0.7f, 1.0f };

		glLightfv(GL_LIGHT0, GL_POSITION, vfPosition);
		glLightfv(GL_LIGHT0, GL_AMBIENT, vfAmbient);
		glLightfv(GL_LIGHT0, GL_DIFFUSE, vfDiffuse);
		glLightfv(GL_LIGHT0, GL_SPECULAR, vfSpecular);
		glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, GL_TRUE);

		glLoadMatrixf(matViewingTransformation.Get());
		
		Color colColor = GetPlugin().GetProperty("Color");
		colColor.SetNormalizedAlpha(float(GetPlugin().GetProperty("Opacity")));
		glColor4ubv(colColor.Get());
		glSecondaryColor3ub(255,255,255);

		const std::string strMode = GetPlugin().GetProperty("Mode");
		bool bStylized = GetPlugin().GetProperty("Stylized");

		glDisable(GL_CULL_FACE);

		glEnable(GL_LIGHTING);
		glEnable(GL_LIGHT0);

		glEnable(GL_BLEND);
		glBlendFuncSeparate(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA,GL_ONE,GL_ONE_MINUS_SRC_ALPHA);

		if (GLEW_ARB_multisample)
		{
			glEnable( GL_MULTISAMPLE_ARB );
			glEnable( GL_SAMPLE_ALPHA_TO_COVERAGE_ARB );
		}


		//if (!bStylized)
		//{
			if (strMode == "Normal")
			{
				m_shaShader.SetOption("normals",false);
				m_shaShader.SetOption("mode","normal");
				m_shaShader.bind();

				renderMesh(*pMesh,&m_shaShader);
				//renderMesh(*pPlane,&m_shaShader);
				m_shaShader.release();		
			}
			/*else if (strMode == "Fancy")
			{
				m_shaShader.SetOption("normals",false);
				m_shaShader.SetOption("mode","fancy");
				m_shaShader.bind();

				renderMesh(*pMesh,&m_shaShader);
				m_shaShader.release();		
			}
			else if (strMode == "Wireframe")
			{
				m_shaShader.SetOption("normals",false);
				m_shaShader.SetOption("mode","wireframe");
				m_shaShader.SetParameter(GL_GEOMETRY_INPUT_TYPE_EXT, GL_TRIANGLES );
				m_shaShader.SetParameter(GL_GEOMETRY_OUTPUT_TYPE_EXT, GL_TRIANGLE_STRIP);
				m_shaShader.SetParameter(GL_GEOMETRY_VERTICES_OUT_EXT, 3);

				m_shaShader.bind();
				renderMesh(*pMesh,&m_shaShader);
				m_shaShader.release();
			}*/
			else
			{
				renderMesh(*pMesh);

				glLoadIdentity();

				//use vector 00depth
				//vec3 
				matViewingTransformation.GetTranslated()
				/*
				const Matrix matViewingTransformation = GetPlugin().GetProperty("Viewing Transformation");
				const Matrix matPlaneTransformation = pMesh->GetProperty("Transformation",Matrix());
				glMultMatrixf(matMeshTransformation.Get());
				glLoadMatrixf(matViewingTransformation.Get());*/

				glDisable(GL_TEXTURE_2D);
				//glDisable(GL_LIGHTING);
				glEnable(GL_COLOR_MATERIAL);
				glColor4f(1,0,0,1);
				glBegin(GL_QUADS);
					glNormal3f(0, 0, 1);
					glVertex3f(-1, -1, 0);
					glVertex3f( 1, -1, 0);
					glVertex3f( 1,  1, 0);
					glVertex3f(-1,  1, 0);
				glEnd();
				glEnable(GL_TEXTURE_2D);
				glEnable(GL_LIGHTING);
				//renderMesh(*pPlane);
			}
		/*}
		else
		{
			canCanvas.release();

			m_fraFramebuffer.attach(GL_COLOR_ATTACHMENT0,&m_texColorTexture0);
			m_fraFramebuffer.attach(GL_COLOR_ATTACHMENT1,&m_texColorTexture1);
			m_fraFramebuffer.attach(GL_COLOR_ATTACHMENT2,&m_texColorTexture2);
			m_fraFramebuffer.attach(GL_COLOR_ATTACHMENT3,&m_texColorTexture3);
			m_fraFramebuffer.attach(GL_COLOR_ATTACHMENT4,&m_texColorTexture4);
			m_fraFramebuffer.attach(GL_COLOR_ATTACHMENT5,&m_texColorTexture5);
			m_fraFramebuffer.attach(GL_DEPTH_ATTACHMENT,&m_texDepthTexture);
			m_fraFramebuffer.resize(m_uWidth,m_uHeight);

			m_fraFramebuffer.bind();
			glPushAttrib(GL_ALL_ATTRIB_BITS);

			GLenum veDrawBuffers[3][2] = {{GL_COLOR_ATTACHMENT0,GL_COLOR_ATTACHMENT1},{GL_COLOR_ATTACHMENT2,GL_COLOR_ATTACHMENT3}, {GL_COLOR_ATTACHMENT4,GL_COLOR_ATTACHMENT5}};
			Texture2D *vpTextures[3][2] = {{&m_texColorTexture0,&m_texColorTexture1},{&m_texColorTexture2,&m_texColorTexture3},{&m_texColorTexture4,&m_texColorTexture5}};

			glClearColor(0.0f,0.0f,0.0f,0.0f);

			glDrawBuffers(2,veDrawBuffers[2]);
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

			glDrawBuffers(2,veDrawBuffers[1]);
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

			glDrawBuffers(2,veDrawBuffers[0]);
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

			glEnable(GL_DEPTH_TEST);
			glDepthFunc(GL_LESS);
			glDepthMask(GL_TRUE);
			glDisable(GL_CULL_FACE);
			glDisable(GL_BLEND);

			glMatrixMode(GL_PROJECTION);
			glLoadMatrixf(matProjectionTransformation.Get());

			glMatrixMode(GL_MODELVIEW);
			glLoadMatrixf(matViewingTransformation.Get());
			glMultMatrixf(matMeshTransformation.Get());

			if (strMode == "Fancy")
			{
				m_shaShader.SetOption("normals",true);
				m_shaShader.SetOption("mode","fancy");
				m_shaShader.bind();

				renderMesh(*pMesh,&m_shaShader);
				m_shaShader.release();		
			}
			else if (strMode == "Wireframe")
			{
				m_shaShader.SetOption("normals",true);
				m_shaShader.SetOption("mode","wireframe");
				m_shaShader.SetParameter(GL_GEOMETRY_INPUT_TYPE_EXT, GL_TRIANGLES );
				m_shaShader.SetParameter(GL_GEOMETRY_OUTPUT_TYPE_EXT, GL_TRIANGLE_STRIP);
				m_shaShader.SetParameter(GL_GEOMETRY_VERTICES_OUT_EXT, 3);

				m_shaShader.bind();
				renderMesh(*pMesh,&m_shaShader);
				m_shaShader.release();
			}
			else
			{
				m_shaShader.SetOption("normals",true);
				m_shaShader.SetOption("mode","normal");
				m_shaShader.bind();

				renderMesh(*pMesh,&m_shaShader);
				renderMesh(*pPlane,&m_shaShader);
				m_shaShader.release();		
			}

			glDepthFunc(GL_ALWAYS);
			glDepthMask(GL_FALSE);
			glDisable(GL_BLEND);

			glMatrixMode(GL_PROJECTION);
			glPushMatrix();
			glLoadIdentity();

			glMatrixMode(GL_MODELVIEW);
			glPushMatrix();
			glLoadIdentity();
			m_shaShader.SetOption("mode","filter");
			m_shaShader.bind();
			glUniform1i(m_shaShader.GetUniformLocation("samColor"),0);
			glUniform1i(m_shaShader.GetUniformLocation("samNormal"),1);


			const int iIterations = 3;
			unsigned int uCurrentDrawBufferIndex = 0;
			unsigned int uCurrentTextureIndex = 1;
			unsigned int uCurrentIndexOffset = 1;

			GLenum *veCurrentDrawBuffers = veDrawBuffers[uCurrentIndexOffset];
			Texture2D **vpCurrentTextures = vpTextures[0];

			for (int i=iIterations;i>0;i--)
			{
				glDrawBuffers(2,veCurrentDrawBuffers);
				glUniform1i(m_shaShader.GetUniformLocation("iSize"),1);

				glActiveTexture(GL_TEXTURE0);		
				vpCurrentTextures[0]->bind();

				glActiveTexture(GL_TEXTURE1);
				vpCurrentTextures[1]->bind();

				glBegin(GL_QUADS);
				glTexCoord2f(0.0f,0.0f);
				glVertex2f(-1.0f,-1.0f);
				glTexCoord2f(1.0f,0.0f);
				glVertex2f(1.0f,-1.0f);
				glTexCoord2f(1.0f,1.0f);
				glVertex2f(1.0f,1.0f);
				glTexCoord2f(0.0f,1.0f);
				glVertex2f(-1.0f,1.0f);
				glEnd();

				glActiveTexture(GL_TEXTURE1);
				vpCurrentTextures[1]->release();

				glActiveTexture(GL_TEXTURE0);
				vpCurrentTextures[0]->release();

				uCurrentDrawBufferIndex = 1-uCurrentDrawBufferIndex;
				uCurrentTextureIndex = 1-uCurrentTextureIndex;

				veCurrentDrawBuffers = veDrawBuffers[uCurrentIndexOffset+uCurrentDrawBufferIndex];
				vpCurrentTextures = vpTextures[uCurrentIndexOffset+uCurrentTextureIndex];
			}


			m_shaShader.release();

			glMatrixMode(GL_PROJECTION);
			glPopMatrix();

			glMatrixMode(GL_MODELVIEW);
			glPopMatrix();

			glPopAttrib();
			m_fraFramebuffer.release();


			canCanvas.bind();

			//////////////////////////////////////////////////////////////////////////
			glDisable(GL_CULL_FACE);
			glDepthFunc(GL_LESS);
			glDepthMask(GL_TRUE);

			glEnable(GL_BLEND);
			glBlendFuncSeparate(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA,GL_ONE,GL_ONE_MINUS_SRC_ALPHA);

			glMatrixMode(GL_PROJECTION);
			glPushMatrix();
			glLoadIdentity();

			glMatrixMode(GL_MODELVIEW);
			glPushMatrix();
			glLoadIdentity();

			glActiveTexture(GL_TEXTURE0);		
			vpTextures[0][0]->bind();

			glActiveTexture(GL_TEXTURE1);		
			vpTextures[0][1]->bind();

			glActiveTexture(GL_TEXTURE2);		
			vpCurrentTextures[0]->bind();

			glActiveTexture(GL_TEXTURE3);		
			vpCurrentTextures[1]->bind();

			glActiveTexture(GL_TEXTURE4);
			m_texDepthTexture.bind();

			m_shaShader.SetOption("mode","stylize");
			m_shaShader.bind();
			glUniform1i(m_shaShader.GetUniformLocation("samColor"),0);
			glUniform1i(m_shaShader.GetUniformLocation("samNormal"),1);
			glUniform1i(m_shaShader.GetUniformLocation("samFilteredColor"),2);
			glUniform1i(m_shaShader.GetUniformLocation("samFilteredNormal"),3);
			glUniform1i(m_shaShader.GetUniformLocation("samDepth"),4);

			glBegin(GL_QUADS);
			glTexCoord2f(0.0f,0.0f);
			glVertex2f(-1.0f,-1.0f);
			glTexCoord2f(1.0f,0.0f);
			glVertex2f(1.0f,-1.0f);
			glTexCoord2f(1.0f,1.0f);
			glVertex2f(1.0f,1.0f);
			glTexCoord2f(0.0f,1.0f);
			glVertex2f(-1.0f,1.0f);
			glEnd();

			m_shaShader.release();

			glActiveTexture(GL_TEXTURE4);
			m_texDepthTexture.release();

			glActiveTexture(GL_TEXTURE3);		
			vpCurrentTextures[1]->bind();

			glActiveTexture(GL_TEXTURE2);		
			vpCurrentTextures[0]->bind();

			glActiveTexture(GL_TEXTURE1);		
			vpTextures[0][1]->bind();

			glActiveTexture(GL_TEXTURE0);		
			vpTextures[0][0]->bind();

			glMatrixMode(GL_PROJECTION);
			glPopMatrix();

			glMatrixMode(GL_MODELVIEW);
			glPopMatrix();
		}*/


		canCanvas.release();
	};

	virtual void overlay(Canvas & canCanvas)
	{
		return;
		if (!m_bPicking)
			return;

		const Matrix matProjectionTransformation = GetPlugin().GetProperty("Projection Transformation");
		const Matrix matViewingTransformation = GetPlugin().GetProperty("Viewing Transformation");

		Handle hanMesh = GetPlugin().GetProperty("Mesh");
		TriangleMesh *pMesh = hanMesh.GetResource<TriangleMesh>();

		//
		Handle hanPlane = GetPlugin().GetProperty("Plane");
		TriangleMesh *pPlane = hanPlane.GetResource<TriangleMesh>();

		if (!pMesh) {
			return;
		}
		//
		if (!pPlane) {
			return;
		}

		const Matrix matMeshTransformation = pMesh->GetProperty("Transformation",Matrix());
		updateGroups(*pMesh);
		glMultMatrixf(matMeshTransformation.Get());
		
		//does nothing
		const Matrix matPlaneTransformation = pPlane->GetProperty("Transformation",Matrix());
		updateGroups(*pPlane);
		glMultMatrixf(matPlaneTransformation.Get());

		canCanvas.bind();

		glMatrixMode(GL_PROJECTION);
		glLoadMatrixf(matProjectionTransformation.Get());

		glMatrixMode(GL_MODELVIEW);
		glLoadMatrixf(matViewingTransformation.Get());
		
		const std::string strGroupName = GetGroupName(*pMesh, m_vecPickingPosition);
		GetPlugin().GetProperty("Selection") = strGroupName;
		m_bPicking = false;

		canCanvas.release();
	};

	virtual void reshape(const unsigned int uWidth, const unsigned int uHeight)
	{
		m_uWidth = uWidth;
		m_uHeight = uHeight;
		GetPlugin().update();
	};

	virtual bool button(const Controller & conController)
	{
		// mouse down
		if (conController.GetActiveButton() == 0 && conController.GetActiveButtonState() && !m_bMouseDownInWindow)
		{
			m_bMouseDownInWindow = true;
			m_kLastMouseDownPosition = conController.GetActiveCursorPosition();
		}
		// mouse up
		else if (conController.GetActiveButton() == 0 && !conController.GetActiveButtonState() && m_bMouseDownInWindow)
		{
			m_bMouseDownInWindow = false;
			const Vector mouseReleasePosition = conController.GetActiveCursorPosition();
			// picking only occurs if mouse down and up happend at the same position (plus/minus a small amount)
			float epsilon = 0.001f;
			if ((mouseReleasePosition.GetX() > m_kLastMouseDownPosition.GetX()-epsilon && mouseReleasePosition.GetX() < m_kLastMouseDownPosition.GetX()+epsilon) &&
				(mouseReleasePosition.GetY() > m_kLastMouseDownPosition.GetY()-epsilon && mouseReleasePosition.GetY() < m_kLastMouseDownPosition.GetY()+epsilon) ) 
			{
				m_bPicking = true;
				//todo do something with mouse coordinates
				m_vecPickingPosition = conController.GetActiveCursorPosition();
				GetPlugin().update(UPDATEFLAG_OVERLAY);
			}
		}

		return false;
	};

	virtual bool cursor(const Controller & conController)
	{
		//show mouse coordinates in console
        m_vecPickingPosition = conController.GetActiveCursorPosition();
        //printf("%f %f\n", m_vecPickingPosition.GetX(), m_vecPickingPosition.GetY());
        return true;
		//return false;
	};

	virtual const std::string GetButtonRole(const unsigned int uIndex) const
	{
		switch (uIndex)
		{
		case 0:
			return "Pick";
		}

		return std::string();
	};

	virtual const std::string GetCursorRole(const unsigned int uIndex) const
	{
		switch (uIndex)
		{
		case 0:
			return "Select";
		}

		return std::string();
	};

protected:

	virtual void propertyModified(const Variant & varVariant, const Observable::Event & eveEvent)
	{
		GetPlugin().update();
	};

	virtual void meshModified (const Variant & varVariant, const Observable::Event & eveEvent)
	{
		if (!eveEvent.IsType<PropertyContainer::Event>())
			m_bUpdateGroups = true;

		GetPlugin().update();
	}

	virtual void updateGroups (const TriangleMesh & mesMesh)
	{
		if (m_bUpdateGroups)
		{
			if (GetPlugin().HasProperty("Groups"))
			{
				Variant & varOldVariant = GetPlugin().GetProperty("Groups");
				Variant varVariant = Variant::TypeMap();

				for (TriangleMesh::Iterator i(mesMesh);!i.IsAtEnd();++i)
				{
					const std::string & strGroupName = (*i).GetGroupName();
					Variant & varGroup = varVariant[strGroupName].require(Variant::TypeBoolean(true));

					if (varOldVariant.HasElement(strGroupName))
						varGroup = varOldVariant[strGroupName];
				}

				GetPlugin().GetProperty("Groups").swap(varVariant);
			}

			m_bUpdateGroups = false;
		}
	};

	virtual void setupAttributes(const TriangleMesh & mesMesh)
	{
		if (mesMesh.HasAttributes(TriangleMesh::ATTRIBUTETYPE_POSITION))
		{
			const AbstractAttributeArray & attPositions = mesMesh.GetAttributes(TriangleMesh::ATTRIBUTETYPE_POSITION);

			if (!attPositions.IsEmpty())
			{
				if (attPositions.GetElementComponents() >= 2 && attPositions.GetElementComponents() <= 4)
				{
					if (attPositions.GetElementOpenGLType() == GL_SHORT || attPositions.GetElementOpenGLType() == GL_INT || attPositions.GetElementOpenGLType() == GL_FLOAT || attPositions.GetElementOpenGLType() == GL_DOUBLE)
					{
						glVertexPointer(attPositions.GetElementComponents(),attPositions.GetElementOpenGLType(),0,attPositions.Get());
						glEnableClientState(GL_VERTEX_ARRAY);
					}
				}
			}
		}

		if (mesMesh.HasAttributes(TriangleMesh::ATTRIBUTETYPE_NORMAL))
		{
			const AbstractAttributeArray & attNormals = mesMesh.GetAttributes(TriangleMesh::ATTRIBUTETYPE_NORMAL);

			if (!attNormals.IsEmpty())
			{
				if (attNormals.GetElementComponents() == 3)
				{
					if (attNormals.GetElementOpenGLType() == GL_BYTE || attNormals.GetElementOpenGLType() == GL_SHORT || attNormals.GetElementOpenGLType() == GL_INT || attNormals.GetElementOpenGLType() == GL_FLOAT || attNormals.GetElementOpenGLType() == GL_DOUBLE)
					{
						glNormalPointer(attNormals.GetElementOpenGLType(),0,attNormals.Get());
						glEnableClientState(GL_NORMAL_ARRAY);
						glEnable(GL_NORMALIZE);
					}
				}
			}
		}

		if (mesMesh.HasAttributes(TriangleMesh::ATTRIBUTETYPE_TEXTURECOORDINATE))
		{
			const AbstractAttributeArray & attTextureCoordinates = mesMesh.GetAttributes(TriangleMesh::ATTRIBUTETYPE_TEXTURECOORDINATE);

			if (!attTextureCoordinates.IsEmpty())
			{
				if (attTextureCoordinates.GetElementComponents() >= 1 && attTextureCoordinates.GetElementComponents() <= 4)
				{
					if (attTextureCoordinates.GetElementOpenGLType() == GL_SHORT || attTextureCoordinates.GetElementOpenGLType() == GL_INT || attTextureCoordinates.GetElementOpenGLType() == GL_FLOAT || attTextureCoordinates.GetElementOpenGLType() == GL_DOUBLE)
					{
						glTexCoordPointer(attTextureCoordinates.GetElementComponents(),attTextureCoordinates.GetElementOpenGLType(),0,attTextureCoordinates.Get());
						glEnableClientState(GL_TEXTURE_COORD_ARRAY);
					}
				}
			}
		}

		if (mesMesh.HasAttributes(TriangleMesh::ATTRIBUTETYPE_COLOR))
		{
			const AbstractAttributeArray & attColors = mesMesh.GetAttributes(TriangleMesh::ATTRIBUTETYPE_COLOR);

			if (!attColors.IsEmpty())
			{
				if (attColors.GetElementComponents() >= 3 && attColors.GetElementComponents() <= 4)
				{
					if (attColors.GetElementOpenGLType() == GL_BYTE || attColors.GetElementOpenGLType() == GL_UNSIGNED_BYTE || attColors.GetElementOpenGLType() == GL_SHORT || attColors.GetElementOpenGLType() == GL_UNSIGNED_SHORT || attColors.GetElementOpenGLType() == GL_INT || attColors.GetElementOpenGLType() == GL_UNSIGNED_INT || attColors.GetElementOpenGLType() == GL_FLOAT || attColors.GetElementOpenGLType() == GL_DOUBLE)
					{
						glColorPointer(attColors.GetElementComponents(),attColors.GetElementOpenGLType(),0,attColors.Get());
						glEnableClientState(GL_COLOR_ARRAY);
					}
				}
			}
		}
	};

	virtual bool renderGroup(const TriangleMesh::Iterator & iteGroup, bool bTransparency, Shader *pShader = NULL)
	{
		const float  fOpacity = GetPlugin().GetProperty("Opacity",Variant::TypeFloat(1.0f, 0.0f, 1.0f));
		const Variant varMaterials = iteGroup.GetMesh().GetProperty("Materials",Variant::TypeMap());

		const TrianglePrimitiveArray & indices = iteGroup.GetGroupPrimitives();

		if (!indices.IsEmpty())
		{
			if (indices.GetElementOpenGLType() == GL_UNSIGNED_BYTE || indices.GetElementOpenGLType() == GL_UNSIGNED_SHORT || indices.GetElementOpenGLType() == GL_UNSIGNED_INT)
			{
				const std::string & strMaterial = iteGroup.GetGroupMaterial();

				Color colAmbient(0.2f,0.2f,0.2f,1.0f);
				Color colDiffuse(0.8f,0.8f,0.8f,1.0f);
				Color colSpecular(0.0f,0.0f,0.0f,1.0f);
				Color colEmission(0.0f,0.0f,0.0f,0.0f);
				float fShininess = 0.0f;

				bool bAmbient = false;
				bool bDiffuse = false;
				bool bSpecular = false;
				bool bEmission = false;
				bool bShininess = false;

				ImageResource *pDiffuseTexture = NULL;				
				float fAlpha = fOpacity;

				if (varMaterials.HasElement(strMaterial))
				{
					const Variant & varCurrentMaterial = varMaterials[strMaterial];

					if (varCurrentMaterial.HasElement("Ambient Color"))
					{
						colAmbient = varCurrentMaterial["Ambient Color"];
						bAmbient = true;
					}

					if (varCurrentMaterial.HasElement("Diffuse Color"))
					{
						colDiffuse = varCurrentMaterial["Diffuse Color"];
						bDiffuse = true;
					}

					if (varCurrentMaterial.HasElement("Specular Color"))
					{
						colSpecular = varCurrentMaterial["Specular Color"];
						bSpecular = true;
					}

					if (varCurrentMaterial.HasElement("Emission Color"))
					{
						colEmission = varCurrentMaterial["Emission Color"];
						bEmission = true;
					}

					if (varCurrentMaterial.HasElement("Shininess"))
					{
						fShininess = varCurrentMaterial["Shininess"];
						bShininess = true;
					}

					if (varCurrentMaterial.HasElement("Diffuse Texture"))
					{
						Handle hanTexture = varCurrentMaterial["Diffuse Texture"];

						if (hanTexture.IsValid())
							pDiffuseTexture = hanTexture.GetResource<ImageResource>();
					}
				}

				//fAlpha = std::min(fAlpha,colAmbient.GetNormalizedAlpha());
				fAlpha = std::min(fAlpha,colDiffuse.GetNormalizedAlpha());
				//fAlpha = std::min(fAlpha,colSpecular.GetNormalizedAlpha());
				//fAlpha = std::min(fAlpha,colEmission.GetNormalizedAlpha());

				if (fAlpha > 0.0f)
				{
					if (!bTransparency && fAlpha < 1.0 )
						return false;

					glPushAttrib(GL_LIGHTING_BIT);
					bool bMaterial = false;

					if (bAmbient)
					{
						const float vfAmbient[] = { colAmbient.GetNormalizedRed(), colAmbient.GetNormalizedGreen(), colAmbient.GetNormalizedBlue(), colAmbient.GetNormalizedAlpha() };
						glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, vfAmbient);
						bMaterial = true;
					}

					if  (bDiffuse)
					{
						const float vfDiffuse[] = { colDiffuse.GetNormalizedRed(), colDiffuse.GetNormalizedGreen(), colDiffuse.GetNormalizedBlue(), colDiffuse.GetNormalizedAlpha() };
						glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, vfDiffuse);
						bMaterial = true;
					}

					if (bSpecular)
					{
						const float vfSpecular[] = { colSpecular.GetNormalizedRed(), colSpecular.GetNormalizedGreen(), colSpecular.GetNormalizedBlue(), colSpecular.GetNormalizedAlpha() };
						glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, vfSpecular);
						bMaterial = true;
					}

					if (bEmission)
					{
						const float vfEmission[] = { colEmission.GetNormalizedRed(), colEmission.GetNormalizedGreen(), colEmission.GetNormalizedBlue(), colEmission.GetNormalizedAlpha() };
						glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, vfEmission);
						bMaterial = true;
					}

					if (bShininess)
					{
						glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, fShininess);
						bMaterial = true;
					}

					int iDiffuseTextureUnit = -1;

					if (pDiffuseTexture)
					{
						glActiveTexture(GL_TEXTURE0);
						glEnable(GL_TEXTURE_2D);
						ResourceTexture::Get<ImageTexture2D>(pDiffuseTexture).bind();
						glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP);
						glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP);
						glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
						glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);

						if (pShader)
						{
							const int iUniformLocation_bDiffuseTexture = pShader->GetUniformLocation("bDiffuseTexture");

							if (iUniformLocation_bDiffuseTexture != -1)
								glUniform1iARB(iUniformLocation_bDiffuseTexture,true);


							const int iUniformLocation_samDiffuseTexture = pShader->GetUniformLocation("samDiffuseTexture");

							if (iUniformLocation_samDiffuseTexture != -1)
								glUniform1iARB(iUniformLocation_samDiffuseTexture,0);
						}

						iDiffuseTextureUnit = GL_TEXTURE0;
					}
					else
					{
						glActiveTexture(GL_TEXTURE0);
						glBindTexture(GL_TEXTURE_2D,0);
						glDisable(GL_TEXTURE_2D);

						if (pShader)
						{
							const int iUniformLocation_bDiffuseTexture = pShader->GetUniformLocation("bDiffuseTexture");

							if (iUniformLocation_bDiffuseTexture != -1)
								glUniform1iARB(iUniformLocation_bDiffuseTexture,false);


							const int iUniformLocation_samDiffuseTexture = pShader->GetUniformLocation("samDiffuseTexture");

							if (iUniformLocation_samDiffuseTexture != -1)
								glUniform1iARB(iUniformLocation_samDiffuseTexture,0);
						}

						iDiffuseTextureUnit = -1;
					}

					if (bMaterial)
						glDisable(GL_COLOR_MATERIAL);
					else
					{
						glColorMaterial(GL_FRONT_AND_BACK,GL_DIFFUSE);
						glEnable(GL_COLOR_MATERIAL);
					}

					glDrawElements(GL_TRIANGLES,indices.GetArrayVertices(),indices.GetElementOpenGLType(),indices.Get());

					if (iDiffuseTextureUnit != -1)
					{
						glActiveTexture(iDiffuseTextureUnit);
						ResourceTexture::Get<ImageTexture2D>(pDiffuseTexture).release();
					}

					glPopAttrib();
				}
			}
		}

		return true;
	};

	virtual void renderMesh(const TriangleMesh & mesMesh, Shader *pShader = NULL)
	{
		const Matrix matProjectionTransformation = GetPlugin().GetProperty("Projection Transformation");
		const Matrix matViewingTransformation = GetPlugin().GetProperty("Viewing Transformation");
		const Matrix matMeshTransformation = mesMesh.GetProperty("Transformation",Matrix());

		const Matrix matTransformation = matProjectionTransformation * matViewingTransformation * matMeshTransformation;
		const std::string strSelection = GetPlugin().GetProperty("Selection");
		const Variant & varGroups  = GetPlugin().GetProperty("Groups");

		glPushAttrib(GL_ALL_ATTRIB_BITS);
		glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);

		setupAttributes(mesMesh);	

		std::multimap<float,TriangleMesh::Iterator> mapRemaining;
	
		for (TriangleMesh::Iterator i(mesMesh);!i.IsAtEnd();++i)
		{
			TriangleMesh::Iterator iteGroup = *i;

			const std::string & strGroupName = iteGroup.GetGroupName();
			const bool bEnabled = varGroups[strGroupName];

			if (bEnabled)
			{
				if (!renderGroup(iteGroup,false,pShader))
				{
					const Box & boxBounds = iteGroup.GetGroupBounds();
					const Vector vecMinimum = boxBounds.GetMinimum(matTransformation);
					mapRemaining.insert(std::make_pair(vecMinimum.GetZ(),iteGroup));
				}
			}
		}

		for (std::multimap<float,TriangleMesh::Iterator>::reverse_iterator j = mapRemaining.rbegin(); j != mapRemaining.rend(); j++)
		{
			const TriangleMesh::Iterator & iteGroup = j->second;
			renderGroup(iteGroup,true,pShader);
		}

		glPopClientAttrib();
		glPopAttrib();
	};

	virtual const std::string GetGroupName(const TriangleMesh & mesMesh, const Vector & vecPosition)
	{
		const int iX = int(0.5f*(vecPosition.GetX()+1.0f) * float(m_uWidth));
		const int iY = int(0.5f*(vecPosition.GetY()+1.0f) * float(m_uHeight));

		glPushAttrib(GL_ALL_ATTRIB_BITS);
		glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);

		glEnable(GL_SCISSOR_TEST);
		glScissor(iX,iY,1,1);

		glDepthMask(GL_TRUE);
		glColorMask(GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE);

		glEnable(GL_DEPTH_TEST);
		glClearDepth(1.0);
		glDepthFunc(GL_LESS);

		glDisable(GL_CULL_FACE);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		TriangleMesh::Iterator i(mesMesh);

		if (i.HasAttributes(TriangleMesh::ATTRIBUTETYPE_POSITION))
		{
			const AbstractAttributeArray & attPositions = i.GetAttributes(TriangleMesh::ATTRIBUTETYPE_POSITION);

			if (!attPositions.IsEmpty())
			{
				if (attPositions.GetElementComponents() >= 2 && attPositions.GetElementComponents() <= 4)
				{
					if (attPositions.GetElementOpenGLType() == GL_SHORT || attPositions.GetElementOpenGLType() == GL_INT || attPositions.GetElementOpenGLType() == GL_FLOAT || attPositions.GetElementOpenGLType() == GL_DOUBLE)
					{
						glVertexPointer(attPositions.GetElementComponents(),attPositions.GetElementOpenGLType(),0,attPositions.Get());
						glEnableClientState(GL_VERTEX_ARRAY);
					}
				}
			}
		}

		std::vector<std::string> vecGroups;
		unsigned int uCount = 0;

		Variant & varVariant = GetPlugin().GetProperty("Groups");
		for (;!i.IsAtEnd();++i)
		{
			const std::string & strGroupName = (*i).GetGroupName();
			const bool bEnabled = varVariant[strGroupName];

			Color color(255,255,255,255);

			if (mesMesh.HasProperty("Materials"))
			{
				Variant varMaterials = mesMesh.GetProperty("Materials");

				if (varMaterials.HasElement((*i).GetGroupMaterial()))
				{
					Variant varMaterial = varMaterials[(*i).GetGroupMaterial()];

					if (varMaterial.HasElement("Diffuse Color"))
						color = varMaterial["Diffuse Color"];
				}
			}

			// use only objects that are enabled and visible
			if (bEnabled && color.GetAlpha() > 0)
			{
				const TrianglePrimitiveArray & indices = (*i).GetGroupPrimitives();

				if (!indices.IsEmpty())
				{
					if (indices.GetElementOpenGLType() == GL_UNSIGNED_BYTE || indices.GetElementOpenGLType() == GL_UNSIGNED_SHORT || indices.GetElementOpenGLType() == GL_UNSIGNED_INT)
					{
						Color col((int)(uCount/256/256), (uCount/256)%256, uCount%256);
						vecGroups.push_back(strGroupName);

						glColor3ubv(col.Get());
						glDrawElements(GL_TRIANGLES,indices.GetArrayVertices(),indices.GetElementOpenGLType(),indices.Get());
						uCount++;
					}
				}
			}
		}

		unsigned char vuResult[4];
		std::string strGroupName;

		glReadPixels(iX, iY, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, vuResult);

		if (vuResult[3] > 0.0)
		{
			const unsigned uResult = (vuResult[0]*256*256 + vuResult[1]*256 + vuResult[2]);

			if (uResult < vecGroups.size())
				strGroupName = vecGroups[uResult];
		}


		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		glPopClientAttrib();
		glPopAttrib();

		return strGroupName;
	};

private:

	unsigned int m_uWidth;
	unsigned int m_uHeight;

	bool m_bUpdateGroups;
	ModifiedObserver m_modVariantObserver;
	ModifiedObserver m_modMeshObserver;
	Shader m_shaShader;

	Framebuffer m_fraFramebuffer;
	Texture2D m_texColorTexture0;
	Texture2D m_texColorTexture1;
	Texture2D m_texColorTexture2;
	Texture2D m_texColorTexture3;
	Texture2D m_texColorTexture4;
	Texture2D m_texColorTexture5;
	Texture2D m_texDepthTexture;

	Vector m_vecPickingPosition;
	bool m_bPicking;

	bool m_bMouseDownInWindow;
	Vector m_kLastMouseDownPosition;
};
