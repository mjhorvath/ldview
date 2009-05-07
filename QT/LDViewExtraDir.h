#ifndef __LDVIEWEXTRADIR_H__
#define __LDVIEWEXTRADIR_H__

#include <TCFoundation/TCTypedObjectArray.h>
#include "ui_ExtraDirPanel.h"
#include <QtGui/QDialog>
class QFileDialog;
class ModelViewerWidget;
class LDrawModelViewer ;
class TCStringArray;
class QFileDialog;

class ExtraDir : public QDialog , Ui::ExtraDirPanel
{
	Q_OBJECT
public:
	ExtraDir(QWidget *parent,ModelViewerWidget *modelWidget);
	~ExtraDir(void);

	void show(void);
	void clear(void);
	int populateListView(void);
	void populateExtraDirsListBox(void);
    void recordExtraSearchDirs(void);
    void populateExtraSearchDirs(void);
    static TCStringArray* extraSearchDirs;

public slots:
	void doAddExtraDir(void);
	void doDelExtraDir(void);
	void doUpExtraDir(void);
	void doDownExtraDir(void);
	void doExtraDirSelected(void);
	void doOk(void);
	void doCancel(void) {close();}

protected:

	LDrawModelViewer *modelViewer;
	ModelViewerWidget *modelWidget;
	bool listViewPopulated;
	QFileDialog *fileDialog;
};

#endif 
