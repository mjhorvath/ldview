#ifndef __LDLMAINMODEL_H__
#define __LDLMAINMODEL_H__

#include <LDLoader/LDLModel.h>

class LDLPalette;

class LDLMainModel : public LDLModel
{
public:
	LDLMainModel(void);
	LDLMainModel(const LDLMainModel &other);
	TCObject *copy(void);
	virtual bool load(const char *filename);
	virtual TCDictionary* getLoadedModels(void);
	virtual void print(void);
	virtual TCULong getEdgeColorNumber(TCULong colorNumber);
	virtual void getRGBA(TCULong colorNumber, int& r, int& g, int& b, int& a);
	virtual bool colorNumberIsTransparent(TCULong colorNumber);
	virtual LDLPalette *getPalette(void) { return m_mainPalette; }

	// Flags
	void setLowResStuds(bool value) { m_mainFlags.lowResStuds = value; }
	bool getLowResStuds(void) const { return m_mainFlags.lowResStuds; }
	void setBlackEdgeLines(bool value) { m_mainFlags.blackEdgeLines = value; }
	bool getBlackEdgeLines(void) { return m_mainFlags.blackEdgeLines; }
	virtual void cancelLoad(void) { m_mainFlags.loadCanceled = true; }
	virtual bool getLoadCanceled(void)
	{
		return m_mainFlags.loadCanceled != false;
	}
protected:
	virtual void dealloc(void);

	TCDictionary *m_loadedModels;
	LDLPalette *m_mainPalette;
	struct
	{
		// Public flags
		bool lowResStuds:1;
		bool blackEdgeLines:1;
		// Semi-public flags
		bool loadCanceled:1;
	} m_mainFlags;
};

#endif // __LDLMAINMODEL_H__
