#import "LDrawModelView.h"
#import "ModelWindow.h"
#import "OCLocalStrings.h"
#import <LDLib/LDrawModelViewer.h>
#include <LDLib/LDInputHandler.h>
#include <LDLib/LDUserDefaultsKeys.h>
#include <TCFoundation/TCMacros.h>
#include <TRE/TREGLExtensions.h>
#include <TCFoundation/TCImage.h>
#include <TCFoundation/TCDefines.h>
#include <TCFoundation/TCAlert.h>
#include <TCFoundation/TCUserDefaults.h>

@implementation LDrawModelView

static NSOpenGLContext *sharedContext = nil;
static BOOL loadResizeCornerImageTried = NO;
static TCImage *resizeCornerImage = NULL;

- (void)dealloc
{
	if (modelViewer)
	{
		modelViewer->openGlWillEnd();
	}
	TCObject::release(modelViewer);
	//[lastMoveTime release];
	[super dealloc];
}

- (TCULong)convertKeyModifiers:(TCULong)osModifiers
{
	TCULong retValue = 0;

	if (osModifiers & NSShiftKeyMask)
	{
		retValue |= LDInputHandler::MKShift;
	}
	if (osModifiers & NSCommandKeyMask)
	{
		retValue |= LDInputHandler::MKControl;
	}
	if (osModifiers & NSControlKeyMask)
	{
		retValue |= LDInputHandler::MKAppleControl;
	}
	return retValue;
}
	
- (void)rotationUpdate
{
	if (!redisplayRequested)
	{
		redisplayRequested = YES;
		[self performSelectorOnMainThread:@selector(redisplay) withObject:nil waitUntilDone:NO];
	}
}

- (TCImage *)tcImageFromPngData:(NSData *)pngImageData
{
	if (pngImageData)
	{
		TCImage *tcImage = new TCImage;
		
		tcImage->setFlipped(true);
		tcImage->setLineAlignment(4);
		tcImage->setDataFormat(TCRgba8);
		if (tcImage->loadData((TCByte *)[pngImageData bytes], [pngImageData length]))
		{
			return tcImage;
		}
	}
	return NULL;
}

- (TCImage *)tcImageFromBitmapRep:(NSBitmapImageRep *)imageRep
{
	if ([imageRep bitsPerPixel] == 32 && ![imageRep isPlanar])
	{
		TCImage *tcImage = new TCImage;
		TCByte *dstData;
		int dstRowSize;
		int width = [imageRep pixelsWide];
		int height = [imageRep pixelsHigh];
		int dstOfs;
		int x, y;
		float components[4];
		float r, g, b, a;
		BOOL useDeviceColor = NO;
		int numComponents;
		
		tcImage->setFlipped(true);
		tcImage->setLineAlignment(4);
		tcImage->setDataFormat(TCRgba8);
		tcImage->setSize(width, height);
		tcImage->allocateImageData();
		dstData = tcImage->getImageData();
		dstRowSize = tcImage->getRowSize();
		memset(dstData, 0, dstRowSize * height);
		numComponents = [[[imageRep colorAtX:0 y:0] colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]] numberOfComponents];
		if (numComponents == 4)
		{
			useDeviceColor = YES;
		}
		for (y = 0; y < height; y++)
		{
			dstOfs = 0;
			TCByte *row = &dstData[(height - y - 1) * dstRowSize];
			for (x = 0; x < width; x++)
			{
				NSColor *color = [imageRep colorAtX:x y:y];
				if (useDeviceColor)
				{
					NSColor *devColor = [color colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];

					[devColor getComponents:components];
					row[dstOfs++] = (TCByte)(components[0] * 255.0f + 0.5);
					row[dstOfs++] = (TCByte)(components[1] * 255.0f + 0.5);
					row[dstOfs++] = (TCByte)(components[2] * 255.0f + 0.5);
					row[dstOfs++] = (TCByte)(components[3] * 255.0f + 0.5);
				}
				else
				{
					[color getRed:&r green:&g blue:&b alpha:&a];
					row[dstOfs++] = (TCByte)(r * 255.0f + 0.5);
					row[dstOfs++] = (TCByte)(g * 255.0f + 0.5);
					row[dstOfs++] = (TCByte)(b * 255.0f + 0.5);
					row[dstOfs++] = (TCByte)(a * 255.0f + 0.5);
				}
			}
		}
		return tcImage;
	}
	return NULL;
}

- (void)loadResizeCornerImage:(TCImage *)tcImage
{
	if (tcImage)
	{
		TCByte *srcData = tcImage->getImageData();
		int srcRowSize = tcImage->getRowSize();
		TCByte *dstData;
		int dstRowSize;
		int srcWidth = tcImage->getWidth();
		int srcHeight = tcImage->getHeight();
		int shiftBytes = (16 - srcWidth) * 4;

		resizeCornerImage = new TCImage;
		resizeCornerImage->setDataFormat(TCRgba8);
		resizeCornerImage->setFlipped(true);
		resizeCornerImage->setLineAlignment(4);
		resizeCornerImage->setSize(16, 16);
		resizeCornerImage->allocateImageData();
		dstData = resizeCornerImage->getImageData();
		dstRowSize = resizeCornerImage->getRowSize();
		memset(dstData, 0, dstRowSize * resizeCornerImage->getHeight());
		for (int i = 0; i < srcHeight; i++)
		{
			int rowOfs = dstRowSize * i;
			memcpy(&dstData[rowOfs + shiftBytes], &srcData[srcRowSize * i], 4 * 15);
			for (int x = 3; x < dstRowSize; x += 4)
			{
				dstData[rowOfs + x] = (TCByte)((double)dstData[rowOfs + x] * 0.667);
			}
		}
	}
}

- (void)loadResizeCornerImage
{
	if (!resizeCornerImage && !loadResizeCornerImageTried)
	{
		NSImage *resizeCornerNSImage = [NSImage imageNamed:@"NSGrayResizeCorner"];
		TCImage *tcImage = NULL;

		loadResizeCornerImageTried = YES;
		if (resizeCornerNSImage)
		{
			NSBitmapImageRep *imageRep = [[resizeCornerNSImage representations] objectAtIndex:0];
			
			if ([imageRep pixelsWide] <= 16 && [imageRep pixelsHigh] <= 16)
			{
				tcImage = [self tcImageFromBitmapRep:imageRep];
				if (!tcImage)
				{
					tcImage = [self tcImageFromPngData:[imageRep representationUsingType:NSPNGFileType properties:nil]];
				}
			}
		}
		if (!tcImage)
		{
			tcImage = [self tcImageFromPngData:[NSData dataWithContentsOfFile:
				[[NSBundle mainBundle] pathForResource:@"MyResizeCorner" ofType:@"png"]]];
		}
		if (tcImage)
		{
			[self loadResizeCornerImage:tcImage];
			tcImage->release();
		}
	}
}

- (void)setupWithFrame:(NSRect)frame
{
	NSData *fontData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SansSerif" ofType:@"fnt"]];
	[self loadResizeCornerImage];
	redisplayRequested = NO;
	modelViewer = new LDrawModelViewer((int)frame.size.width,
		(int)frame.size.height);
	modelViewer->setFontData((TCByte *)[fontData bytes], [fontData length]);
	inputHandler = modelViewer->getInputHandler();
}

- (NSOpenGLPixelFormat *)customPixelFormat
{
	NSOpenGLPixelFormatAttribute attrs[] =
	{
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute)24,
		NSOpenGLPFABackingStore, (NSOpenGLPixelFormatAttribute)NO,
		NSOpenGLPFAAccelerated, (NSOpenGLPixelFormatAttribute)NO,
		(NSOpenGLPixelFormatAttribute)0
	};
	return [[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] autorelease];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		[self setupWithFrame:[self frame]];
	}
	return self;
}

- (void)initWithFrame:(NSRect)frame pixelFormat:(NSOpenGLPixelFormat *)format
{
	[format release];
	[self initWithFrame:frame];
}

- (id)initWithFrame:(NSRect)frame
{
	if ((self = [super initWithFrame:frame pixelFormat:[self customPixelFormat]]) != nil)
	{
		[self setupWithFrame:frame];
	}
	return self;
}

- (ModelWindow *)modelWindow
{
	return (ModelWindow *)[[self window] delegate];
}

- (void)redisplay
{
	redisplayRequested = NO;
	if ([NSApp nextEventMatchingMask:NSAnyEventMask untilDate:nil inMode:NSDefaultRunLoopMode dequeue:NO])
	{
		// If there are any events in the event queue, we don't want to redisplay yet; that causes
		// the event queue to get jammed up with unprocessed events.
		[self rotationUpdate];
	}
	else
	{
		[self setNeedsDisplay:YES];
	}
}

- (void)reshape
{
	NSRect frame = [self frame];
	modelViewer->setWidth((int)frame.size.width);
	modelViewer->setHeight((int)frame.size.height);
}

- (LDrawModelViewer *)modelViewer
{
	return modelViewer;
}

- (BOOL)openModel:(NSString *)filename
{
	BOOL retValue = NO;

	if (modelViewer)
	{
		loading = YES;
		modelViewer->setFilename([filename cStringUsingEncoding:
			NSASCIIStringEncoding]);
		if (modelViewer->loadModel(true))
		{
			retValue = YES;
		}
		else
		{
			NSRunAlertPanel([OCLocalStrings get:@"Error"], [NSString stringWithFormat: [OCLocalStrings get:@"ErrorLoadingModel"], [filename cStringUsingEncoding:NSASCIIStringEncoding]], [OCLocalStrings get:@"OK"], nil, nil);
		}
		loading = NO;
		[self rotationUpdate];
	}
	return retValue;
}

- (void)mouseDown:(NSEvent *)event
{
	NSPoint loc = [event locationInWindow];
	
	inputHandler->mouseDown([self convertKeyModifiers:[event modifierFlags]], LDInputHandler::MBLeft, (int)loc.x, (int)-loc.y);
//	[self rotationUpdate];
//	mouseDownModifierFlags = [event modifierFlags];
//	if (mouseDownModifierFlags & NSControlKeyMask)
//	{
//		[self rightMouseDown:event];
//	}
//	else
//	{
//		lButtonDown = YES;
//		lastMouseLocation = [event locationInWindow];
//		lastFrameMouseLocation = lastMouseLocation;
//		modelViewer->setRotationSpeed(0.0);
//		rotationSpeed = 0.0f;
//		//NSLog(@"Stopped?\n");
//	}
}

- (void)rightMouseDown:(NSEvent *)event
{
	NSPoint loc = [event locationInWindow];
	
	inputHandler->mouseDown([self convertKeyModifiers:[event modifierFlags]], LDInputHandler::MBRight, (int)loc.x, (int)-loc.y);
	//	[self rotationUpdate];
	//	rightMouseDownModifierFlags = [event modifierFlags];
	//	if (!lButtonDown)
	//	{
	//		if (viewMode == LDVViewExamine)
	//		{
	//			originalZoomY = [event locationInWindow].y;
	//			rButtonDown = YES;
	//		}
	//	}
}

- (void)otherMouseDown:(NSEvent *)event
{
	NSPoint loc = [event locationInWindow];
	
	inputHandler->mouseDown([self convertKeyModifiers:[event modifierFlags]], LDInputHandler::MBMiddle, (int)loc.x, (int)-loc.y);
}

- (void)mouseUp:(NSEvent *)event
{
	NSPoint loc = [event locationInWindow];
	
	inputHandler->mouseUp([self convertKeyModifiers:[event modifierFlags]], LDInputHandler::MBLeft, (int)loc.x, (int)-loc.y);
//	//NSLog(@"mouseUp: (%g, %g)\n", lastMouseLocation.x, lastMouseLocation.y);
//	if (mouseDownModifierFlags & NSControlKeyMask)
//	{
//		[self rightMouseUp:event];
//	}
//	else
//	{
//		lButtonDown = NO;
//		[self rotationUpdate];
//		modelViewer->setCameraXRotate(0.0f);
//		modelViewer->setCameraYRotate(0.0f);
//	}
}

- (void)rightMouseUp:(NSEvent *)event
{
	NSPoint loc = [event locationInWindow];
	
	inputHandler->mouseUp([self convertKeyModifiers:[event modifierFlags]], LDInputHandler::MBRight, (int)loc.x, (int)-loc.y);
	//	[self rotationUpdate];
	//	if (rButtonDown)
	//	{
	//		rButtonDown = NO;
	//		modelViewer->setZoomSpeed(0.0f);
	//	}
}

- (void)otherMouseUp:(NSEvent *)event
{
	NSPoint loc = [event locationInWindow];
	
	inputHandler->mouseUp([self convertKeyModifiers:[event modifierFlags]], LDInputHandler::MBMiddle, (int)loc.x, (int)-loc.y);
	//	[self rotationUpdate];
	//	if (rButtonDown)
	//	{
	//		rButtonDown = NO;
	//		modelViewer->setZoomSpeed(0.0f);
	//	}
}

- (void)mouseDragged:(NSEvent *)event
{
	NSPoint loc = [event locationInWindow];
	
	inputHandler->mouseMove([self convertKeyModifiers:[event modifierFlags]], (int)loc.x, (int)-loc.y);
	//	if (mouseDownModifierFlags & NSControlKeyMask)
	//	{
	//		[self rightMouseDragged:event];
	//	}
	//	else
	//	{
	//		[self rotationUpdate];
	//		//[lastMoveTime release];
	//		//lastMoveTime = [[NSDate alloc] init];
	//		NSPoint mouseLocation = [event locationInWindow];
	//		if (viewMode == LDVViewExamine)
	//		{
	//			if (mouseDownModifierFlags & NSCommandKeyMask)
	//			{
	//				[self updatePanXY:mouseLocation];
	//			}
	//			else
	//			{
	//				[self updateSpinRateXY:mouseLocation];
	//			}
	//		}
	//	}
}

- (void)rightMouseDragged:(NSEvent *)event
{
	NSPoint loc = [event locationInWindow];
	
	inputHandler->mouseMove([self convertKeyModifiers:[event modifierFlags]], (int)loc.x, (int)-loc.y);
	//	[self rotationUpdate];
	//	if (rightMouseDownModifierFlags & NSAlternateKeyMask)
	//	{
	//		modelViewer->setClipZoom(true);
	//	}
	//	else
	//	{
	//		modelViewer->setClipZoom(false);
	//	}
	//	[self updateZoom:[event locationInWindow].y];
}

- (void)otherMouseDragged:(NSEvent *)event
{
	NSPoint loc = [event locationInWindow];
	
	inputHandler->mouseMove([self convertKeyModifiers:[event modifierFlags]], (int)loc.x, (int)-loc.y);
	//	[self rotationUpdate];
	//	if (rightMouseDownModifierFlags & NSAlternateKeyMask)
	//	{
	//		modelViewer->setClipZoom(true);
	//	}
	//	else
	//	{
	//		modelViewer->setClipZoom(false);
	//	}
	//	[self updateZoom:[event locationInWindow].y];
}

- (LDInputHandler::KeyCode)convertKeyCode:(NSEvent *)theEvent
{
	NSString *characters = [theEvent charactersIgnoringModifiers];
	
	if ([characters length] == 1)
	{
		unichar character = [characters characterAtIndex:0];
		
		if (isalpha(character))
		{
			return (LDInputHandler::KeyCode)(toupper(character) - 'A' + LDInputHandler::KCA);
		}
		else
		{
			switch (character)
			{
			case NSUpArrowFunctionKey:
				return LDInputHandler::KCUp;
			case NSDownArrowFunctionKey:
				return LDInputHandler::KCDown;
			case NSLeftArrowFunctionKey:
				return LDInputHandler::KCLeft;
			case NSRightArrowFunctionKey:
				return LDInputHandler::KCRight;
			case ' ':
				return LDInputHandler::KCSpace;
			case NSPageUpFunctionKey:
				return LDInputHandler::KCPageUp;
			case NSPageDownFunctionKey:
				return LDInputHandler::KCPageDown;
			case NSHomeFunctionKey:
				return LDInputHandler::KCHome;
			case NSEndFunctionKey:
				return LDInputHandler::KCEnd;
			case NSInsertFunctionKey:
				return LDInputHandler::KCInsert;
			case NSDeleteFunctionKey:
				return LDInputHandler::KCDelete;
			case 27:
				return LDInputHandler::KCEscape;
			}
		}
	}
	return LDInputHandler::KCUnknown;
}

- (TCULong)currentKeyModifiers
{
	return 0;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	return YES;
}

- (BOOL)resignFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	inputHandler->keyDown([self convertKeyModifiers:[theEvent modifierFlags]], [self convertKeyCode:theEvent]);
}

- (void)keyUp:(NSEvent *)theEvent
{
	inputHandler->keyUp([self convertKeyModifiers:[theEvent modifierFlags]], [self convertKeyCode:theEvent]);
}

//- (void)updateZoom:(float)yPos
//{
//	float magnitude = yPos - originalZoomY;
//
//	modelViewer->setZoomSpeed(-magnitude / 2.0f);
//}

//- (void)updatePanXY:(NSPoint)mouseLocation
//{
//	float deltaX = mouseLocation.x - lastMouseLocation.x;
//	float deltaY = mouseLocation.y - lastMouseLocation.y;
//	
//	lastMouseLocation = mouseLocation;
//	modelViewer->panXY((int)deltaX, (int)-deltaY);
//}

//- (void)updateSpinRateXY:(NSPoint)mouseLocation
//{
//	float deltaX = mouseLocation.x - lastMouseLocation.x;
//	float deltaY = mouseLocation.y - lastMouseLocation.y;
//	float magnitude = (float)sqrt(deltaX * deltaX + deltaY * deltaY);
//
//	//NSLog(@"lastMouseLocation: (%g, %g); mouseLocation: (%g, %g)", lastMouseLocation.x, lastMouseLocation.y, mouseLocation.x, mouseLocation.y);
//	lastMouseLocation = mouseLocation;
//	rotationSpeed = magnitude / 10.0f;
//	if (fEq(rotationSpeed, 0.0f))
//	{
//		rotationSpeed = 0.0f;
//		modelViewer->setXRotate(1.0f);
//		modelViewer->setYRotate(1.0f);
//	}
//	else
//	{
//		modelViewer->setXRotate(-deltaY);
//		modelViewer->setYRotate(deltaX);
//	}
//	modelViewer->setRotationSpeed(rotationSpeed);
//}

//- (void)updateSpinRate
//{
//	NSEvent *mouseUpEvent = [[self window] nextEventMatchingMask:NSLeftMouseUpMask untilDate:nil inMode:NSDefaultRunLoopMode dequeue:NO];
//	
//	// if mouseUpEvent has a value, then there's a mouse up in the queue, and we
//	// don't want to stop our spinning.
//	if (lButtonDown && !mouseUpEvent)
//	{
//		[self updateSpinRateXY:lastMouseLocation];
////		if ([[NSDate date] timeIntervalSinceReferenceDate] -
////			[lastMoveTime timeIntervalSinceReferenceDate] > -0.1 ||
////			(lastFrameMouseLocation.x == lastMouseLocation.x &&
////			 lastFrameMouseLocation.y == lastMouseLocation.y))
////		{
////			[self updateSpinRateXY:lastMouseLocation];
////		}
//	}
//}

- (void)scrollWheel:(NSEvent *)event
{
	inputHandler->mouseWheel([self convertKeyModifiers:[event modifierFlags]], [event deltaY] * 20.0f);
//	[self rotationUpdate];
//	if ([event modifierFlags] & NSAlternateKeyMask)
//	{
//		modelViewer->setClipZoom(YES);
//	}
//	else
//	{
//		modelViewer->setClipZoom(NO);
//	}
//	modelViewer->zoom([event deltaY] * -10.0f);
}

- (void)reload
{
	if (modelViewer)
	{
		[[self openGLContext] makeCurrentContext];
		modelViewer->reload();
		[self rotationUpdate];
	}
	loading = NO;
}

- (void)reloadNeeded
{
	if (modelViewer)
	{
		[[self openGLContext] makeCurrentContext];
		if (modelViewer->getNeedsReload())
		{
			modelViewer->reload();
		}
		[[self openGLContext] makeCurrentContext];
		if (modelViewer->getNeedsRecompile())
		{
			modelViewer->recompile();
		}
		[self rotationUpdate];
	}
	loading = NO;
}

- (void)awakeFromNib
{
	if (sharedContext == nil)
	{
		[super setPixelFormat:[self customPixelFormat]];
		sharedContext = [[super openGLContext] retain];
	}
	else
	{
		[super setOpenGLContext:[[[NSOpenGLContext alloc] initWithFormat:[self customPixelFormat] shareContext:sharedContext] autorelease]];
		// We don't have to set the GL Context's view to ourself because we
		// haven't been shown yet.  That will get done automatically when our
		// window is initially shown (as far as I can tell).
		//[[self openGLContext] setView:self];
	}
	[[self openGLContext] makeCurrentContext];
	TREGLExtensions::setup();
}

- (void)prepResizeCornerTexture
{
	if (resizeCornerTextureId == 0)
	{
		glGenTextures(1, (GLuint *)&resizeCornerTextureId);
		glBindTexture(GL_TEXTURE_2D, resizeCornerTextureId);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, resizeCornerImage->getWidth(), resizeCornerImage->getHeight(), 0, GL_RGBA, GL_UNSIGNED_BYTE, resizeCornerImage->getImageData());
	}
	else
	{
		glBindTexture(GL_TEXTURE_2D, resizeCornerTextureId);
	}
	if (resizeCornerTextureId != 0)
	{
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	}
}

- (void)drawRect:(NSRect)rect
{
	if (modelViewer && modelViewer->getFilename() && (modelViewer->getNeedsReload() || modelViewer->getNeedsRecompile()))
	{
		[[self modelWindow] modelWillReload];
		loading = YES;
	}
	if (loading || !modelViewer || modelViewer->getUpdating())
	{
		[[NSColor blackColor]  set];
		NSRectFill(rect);
		return;
	}
	[[self openGLContext] makeCurrentContext];
	redrawRequested = false;
	modelViewer->update();
	if (fps != 0.0f)
	{
		modelViewer->drawFPS(fps);
	}
	if (resizeCornerImage && ![[self modelWindow] showStatusBar])
	{
		glPushAttrib(GL_COLOR_BUFFER_BIT | GL_ENABLE_BIT | GL_TEXTURE_BIT);
		[self prepResizeCornerTexture];
		glEnable(GL_TEXTURE_2D);
		modelViewer->orthoView();
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glTranslatef(rect.size.width - 16.0, 0.0f, 0.0f);
		glBegin(GL_QUADS);
		glTexCoord2f(0.0f, 0.0f);
		glVertex2f(0.0f, 0.0f);
		glTexCoord2f(1.0f, 0.0f);
		glVertex2f(16.0f, 0.0f);
		glTexCoord2f(1.0f, 1.0f);
		glVertex2f(16.0f, 16.0f);
		glTexCoord2f(0.0f, 1.0f);
		glVertex2f(0.0f, 16.0f);
		glEnd();
		glPopAttrib();
	}
	//glFinish();
//	[self updateSpinRate];
//	lastFrameMouseLocation = lastMouseLocation;
//	if (rotationSpeed > 0.0f || !fEq(modelViewer->getZoomSpeed(), 0.0f))
//	{
//		[self rotationUpdate];
//		[[self modelWindow] performSelectorOnMainThread:@selector(updateFps) withObject:nil waitUntilDone:NO];
//	}
//	else
	if (redrawRequested)
	{
		[[self modelWindow] performSelectorOnMainThread:@selector(updateFps) withObject:nil waitUntilDone:NO];
	}
	else
	{
		[[self modelWindow] performSelectorOnMainThread:@selector(clearFps) withObject:nil waitUntilDone:NO];
		//[[self modelWindow] clearFps];
	}
	//long swapInterval;
	//[[self openGLContext] getValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];
	[[self openGLContext] flushBuffer];
}

- (void)resetView:(id)sender
{
	modelViewer->resetView();
	[self rotationUpdate];
}

- (void)setFps:(float)value
{
	fps = value;
}

- (void)setViewingAngle:(int)value
{
	if (value >= LDVAngleDefault && value <= LDVAngleIso)
	{
		modelViewer->resetView((LDVAngle)value);
		[self rotationUpdate];
	}
	else
	{
		NSLog(@"Invalid viewing angle.");
	}
}

- (IBAction)zoomToFit:(id)sender
{
	modelViewer->zoomToFit();
	[self rotationUpdate];
}

- (void)modelViewerAlertCallback:(TCAlert *)alert
{
	if (alert)
	{
		//MessageBox(hWindow, alert->getMessage(), "LDView", MB_OK | MB_ICONWARNING);
	}
}

- (void)redrawAlertCallback:(TCAlert *)alert
{
	if (alert->getSender() == modelViewer)
	{
		redrawRequested = true;
		[self rotationUpdate];
	}
}

- (void)captureAlertCallback:(TCAlert *)alert
{
	if (alert->getSender() == inputHandler)
	{
		// Unnecessary?
		//captureMouse();
	}
}

- (void)releaseAlertCallback:(TCAlert *)alert
{
	if (alert->getSender() == inputHandler)
	{
		// Unnecessary?
		//releaseMouse();
	}
}

//- (void)peekMouseUpAlertCallback:(TCAlert *)alert
//{
//	if (false && alert->getSender() == inputHandler)
//	{
//		if ([[self window] nextEventMatchingMask:NSLeftMouseUpMask untilDate:nil inMode:NSDefaultRunLoopMode dequeue:NO] != nil)
//		{
//			inputHandler->setMouseUpPending(true);
//		}
//		else
//		{
//			inputHandler->setMouseUpPending(false);
//		}
//	}
//}

- (IBAction)viewMode:(id)sender
{
	[self setFlyThroughMode:[[sender cell] tagForSegment:[sender selectedSegment]] == LDInputHandler::VMFlyThrough];
}

- (void)setFlyThroughMode:(bool)flyThroughMode
{
	LDInputHandler::ViewMode newViewMode = LDInputHandler::VMExamine;

	if (flyThroughMode)
	{
		newViewMode = LDInputHandler::VMFlyThrough;
	}
	inputHandler->setViewMode(newViewMode);
	TCUserDefaults::setLongForKey(newViewMode, VIEW_MODE_KEY, false);
}

@end
