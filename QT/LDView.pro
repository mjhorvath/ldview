SOURCES	+= QTMain.cpp ModelViewerWidget.cpp Preferences.cpp LDViewErrors.cpp \
		   LDViewExtraDir.cpp AlertHandler.cpp LDViewSnapshotSettings.cpp
HEADERS	+= ModelViewerWidget.h Preferences.h LDViewErrors.h LDViewExtraDir.h \
		   AlertHandler.h

UI_DIR = .ui
MOC_DIR = .moc
OBJECTS_DIR = .obj

unix {
  documentation.path = /usr/local/share/ldview
  documentation.files = ../Readme.txt ../Help.html ../license.txt \
						../m6459.ldr ../LDViewMessages.ini \
						../ChangeHistory.html ../8464.mpd todo.txt
  target.path = /usr/local/bin
  INSTALLS += documentation target
  LIBS += -L../TCFoundation -L../LDLib -L../LDLoader -L../TRE -L../boost/lib \
          -lLDraw -lboost_thread
  ldlib.target = ../LDLib/libLDraw.a
  ldlib.commands = cd ../LDLib ; make all
  ldlib.depends = ../LDLib/*.cpp ../LDLib/*.h
  tre.target = ../TRE/libTRE.a
  tre.commands = cd ../TRE ; make all
  tre.depends = ../TRE/*.cpp ../TRE/*.h
  tcfoundation.target = ../TCFoundation/libTCFoundation.a
  tcfoundation.commands = cd ../TCFoundation ; make all
  tcfoundation.depends = ../TCFoundation/*.cpp ../TCFoundation/*.h
  ldloader.target = ../LDLoader/libLDLoader.a
  ldloader.commands = cd ../LDLoader ; make all
  ldloader.depends = ../LDLoader/*.cpp ../LDLoader/*.h
  QMAKE_EXTRA_UNIX_TARGETS += ldlib tre tcfoundation ldloader
  PRE_TARGETDEPS += ../LDLib/libLDraw.a ../TRE/libTRE.a \
                    ../TCFoundation/libTCFoundation.a ../LDLoader/libLDLoader.a
}

win32 {
  DEFINES += _TC_STATIC
  INCLUDE += -I../../boost_1_33_1
  LIBS += -L../TCFoundation/Release -L../LDLib/Release -L../LDLoader/Release \
          -L../TRE/Release -lLDLib -L../lib -lunzip32 -llibboost_thread-vc71-mt-s
}

translations.commands = lrelease LDView.pro
translations.target = ldview_de.qm
QMAKE_EXTRA_UNIX_TARGETS += translations
QMAKE_EXTRA_WIN_TARGETS += translations
PRE_TARGETDEPS += ldview_de.qm
QMAKE_CLEAN += *.qm

FORMS	= LDView.ui PreferencesPanel.ui OpenGLExtensionsPanel.ui \
		  AboutPanel.ui ErrorPanel.ui ImageHolder.ui ExtraDirPanel.ui \
		  HelpPanel.ui SnapshotSettingsPanel.ui
IMAGES	= images/fileopen.png images/filesave.png images/print.png \
		  images/LDViewIcon.png images/LDViewIcon16.png images/StudLogo.png \
		  images/toolbar_reload.png images/toolbar_wireframe.png \
		  images/toolbar_seams.png images/toolbar_edge.png \
		  images/toolbar_privsubs.png images/toolbar_snapshot.png \
		  images/toolbar_view.png images/toolbar_preferences.png \
		  images/toolbar_bfc.png images/toolbar_light.png \
		  images/error_colinear.png images/error_color.png \
		  images/error_concave_quad.png images/error_determinant.png \
		  images/error_fnf.png images/error_info.png \
		  images/error_matching_points.png images/error_matrix.png \
		  images/error_non_flat_quad.png images/error_opengl.png \
		  images/error_parse.png images/error_vertex_order.png
TEMPLATE	=app
CONFIG	+= qt opengl thread warn_on release
DEFINES	+= QT_THREAD_SUPPORT _QT
INCLUDEPATH	+= . .. ../include
exists($(QTDIR)/include/Qt3Support/q3button.h){
	CONFIG 	+= uic3
	DEFINES += QT3_SUPPORT
	QT 	+= qt3support opengl
	INCLUDEPATH	+= $(QTDIR)/include/Qt $(QTDIR)/include/QtCore
message(QT4)
}
LIBS	+= -lLDLoader -lTRE -lTCFoundation
DBFILE	= LDView.db
LANGUAGE	= C++
TRANSLATIONS   =  	ldview_en.ts \
					ldview_de.ts \
					ldview_it.ts
VERSION = 3.1
macx {
	RC_FILE = images/LDView.icns
	messagefile.target = LDView.app/Contents/MacOS/LDViewMessages.ini
	messagefile.commands = cp ../LDViewMessages.ini LDView.app/Contents/MacOS
	messagefile.depends = ../LDViewMessages.ini
	QMAKE_EXTRA_UNIX_TARGETS += messagefile
	POST_TARGETDEPS += LDView.app/Contents/MacOS/LDViewMessages.ini
}
