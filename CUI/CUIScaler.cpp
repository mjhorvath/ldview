#include "CUIScaler.h"
#include "CUIModuleHolder.h"

#ifdef _DEBUG
#include <VersionHelpers.h>
bool CUIScaler::sm_use32bit = IsWindowsXPOrGreater();
#else // _DEBUG
bool CUIScaler::sm_use32bit = false;
#endif // !_DEBUG

typedef enum MONITOR_DPI_TYPE {
	MDT_EFFECTIVE_DPI = 0,
	MDT_ANGULAR_DPI = 1,
	MDT_RAW_DPI = 2,
	MDT_DEFAULT = MDT_EFFECTIVE_DPI
} MONITOR_DPI_TYPE;

typedef HRESULT(WINAPI *PFNGETDPIFORMONITOR)(
	_In_  HMONITOR         hmonitor,
	_In_  MONITOR_DPI_TYPE dpiType,
	_Out_ UINT             *dpiX,
	_Out_ UINT             *dpiY);

class ShcoreHolder : public CUIModuleHolder
{
public:
	ShcoreHolder(void)
		: CUIModuleHolder("Shcore.dll")
		, m_getDpiForMonitor(NULL)
	{
		if (m_hModule != NULL)
		{
			m_getDpiForMonitor = (PFNGETDPIFORMONITOR)GetProcAddress(m_hModule,
				"GetDpiForMonitor");
		}
	}
	~ShcoreHolder(void)
	{
		m_getDpiForMonitor = NULL;
	}
	PFNGETDPIFORMONITOR m_getDpiForMonitor;
};

static ShcoreHolder s_shcore;

CUIScaler::CUIScaler(CUIWindow *window)
	: m_window(window) // window is our owner; do not retain.
	, m_hScaleSrcDC(NULL)
	, m_hScaleDstDC(NULL)
	, m_scaleFactor(1.0)
	, m_dpiX(96)
	, m_dpiY(96)
{
	getScaleFactor(true);
}

CUIScaler::~CUIScaler(void)
{
}

void CUIScaler::dealloc(void)
{
	// DO NOT RELEASE m_window: it is our owner.
	TCObject::dealloc();
	if (m_hScaleSrcDC != NULL)
	{
		DeleteDC(m_hScaleSrcDC);
	}
	if (m_hScaleDstDC != NULL)
	{
		DeleteDC(m_hScaleDstDC);
	}
}

double CUIScaler::getScaleFactor(
	bool recalculate /*= false*/,
	UINT *dpiX /*= NULL*/,
	UINT *dpiY /*= NULL*/)
{
	if (recalculate)
	{
		m_scaleFactor = 1.0;
		m_dpiX = m_dpiY = 96;
		if (s_shcore.m_getDpiForMonitor != NULL)
		{
			HMONITOR hMonitor = MonitorFromWindow(m_window->getHWindow(),
				MONITOR_DEFAULTTOPRIMARY);
			UINT ldpiX, ldpiY;
			if (s_shcore.m_getDpiForMonitor(hMonitor, MDT_EFFECTIVE_DPI,
				&ldpiX, &ldpiY) == S_OK)
			{
				m_dpiX = (UINT)fmax(96, ldpiX);
				m_dpiY = (UINT)fmax(96, ldpiY);
				// Don't go below 1.0, and if X and Y differ, go with the higher
				// value. That's probably not going to work right, but I don't
				// have any way to test non-square-pixel displays.
				m_scaleFactor = fmax(1.0, fmax(m_dpiX, m_dpiY) / 96.0);
			}
		}
	}
	if (dpiX != NULL)
	{
		*dpiX = m_dpiX;
	}
	if (dpiY != NULL)
	{
		*dpiY = m_dpiY;
	}
	return m_scaleFactor;
}

bool CUIScaler::scaleBitmap(
	HBITMAP hSrc,
	HBITMAP& hDst,
	double scaleFactor /*= -1*/)
{
	if (scaleFactor == -1.0)
	{
		scaleFactor = m_scaleFactor;
	}
	if (m_hScaleSrcDC == NULL)
	{
		m_hScaleSrcDC = CreateCompatibleDC(NULL);
		if (m_hScaleSrcDC == NULL)
		{
			return false;
		}
	}
	if (m_hScaleDstDC == NULL)
	{
		m_hScaleDstDC = CreateCompatibleDC(NULL);
		if (m_hScaleDstDC == NULL)
		{
			return false;
		}
	}
	SIZE srcSize;
	if (!m_window->getBitmapSize(hSrc, srcSize))
	{
		return false;
	}
	SIZE dstSize;
	dstSize.cx = (int)(srcSize.cx * scaleFactor);
	dstSize.cy = (int)(srcSize.cy * scaleFactor);
	BYTE *bmBuffer;
	hDst = m_window->createDIBSection(m_hScaleDstDC, dstSize.cx, dstSize.cy, m_dpiX, m_dpiY,
		&bmBuffer, sm_use32bit);
	if (hDst != NULL)
	{
		HBITMAP hOldDst = (HBITMAP)SelectObject(m_hScaleDstDC, hDst);
		HBITMAP hOldSrc = (HBITMAP)SelectObject(m_hScaleSrcDC, hSrc);
		SetStretchBltMode(m_hScaleDstDC, COLORONCOLOR);
		bool retValue = StretchBlt(m_hScaleDstDC, 0, 0, dstSize.cx, dstSize.cy, m_hScaleSrcDC,
			0, 0, srcSize.cx, srcSize.cy, SRCCOPY) != FALSE;
		SelectObject(m_hScaleSrcDC, hOldSrc);
		SelectObject(m_hScaleDstDC, hOldDst);
		if (!retValue)
		{
			DeleteObject(hDst);
			hDst = NULL;
		}
		return retValue;
	}
	return false;
}