#ifndef __LDLCONDITIONALLINELINE_H__
#define __LDLCONDITIONALLINELINE_H__

#include <LDLoader/LDLLineLine.h>

class LDLConditionalLineLine : public LDLLineLine
{
public:
	TCObject *copy(void);
	virtual bool parse(void);
	virtual int getNumControlPoints(void) const { return 2; }
	virtual const TCVector *getControlPoints(void) const { return m_controlPoints; }
	virtual LDLLineType getLineType(void) const
	{
		return LDLLineTypeConditionalLine;
	}
	virtual void scanPoints(TCObject *scanner,
		LDLScanPointCallback scanPointCallback, const TCFloat *matrix) const;
protected:
	LDLConditionalLineLine(LDLModel *parentModel, const char *line,
		int lineNumber, const char *originalLine = NULL);
	LDLConditionalLineLine(const LDLConditionalLineLine &other);
	virtual void dealloc(void);
	virtual bool shouldScanPoints(LDLModel::ScanPointType types) const;

	TCVector *m_controlPoints;

	friend class LDLFileLine; // Needed because constructors are protected.
};

#endif // __LDLCONDITIONALLINELINE_H__
