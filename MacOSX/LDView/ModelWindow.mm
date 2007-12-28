#import "ModelWindow.h"
#import "LDrawModelView.h"
#import "LDViewController.h"
#import "Preferences.h"
#import "ToolbarSegmentedControl.h"
#import "ToolbarPopUpButton.h"
#import "ErrorsAndWarnings.h"
#import "ErrorItem.h"
#import "OCLocalStrings.h"
#import "OCUserDefaults.h"
#import "SnapshotTaker.h"
#import "SaveSnapshotViewOwner.h"
#include <LDLoader/LDLError.h>
#include <LDLib/LDPreferences.h>
#include <LDLib/LDUserDefaultsKeys.h>
#include <LDLib/LDInputHandler.h>
#include <TCFoundation/TCProgressAlert.h>
#include <TCFoundation/TCStringArray.h>
#import "AlertHandler.h"

@implementation ModelWindow

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[statusBar release];
	[window release];
	[toolbarItems release];
	[defaultIdentifiers release];
	[otherIdentifiers release];
	TCObject::release(alertHandler);
	alertHandler = NULL;
	[imageFileTypes release];
	[snapshotTaker release];
	[saveSnapshotViewOwner release];
	[super dealloc];
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdentifier
  willBeInsertedIntoToolbar:(BOOL)flag
{
	return [toolbarItems objectForKey:itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
	return allIdentifiers;
}

- (NSArray *)toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
	return defaultIdentifiers;
}

- (NSToolbarItem *)addToolbarItemWithIdentifier:(NSString *)identifier label:(NSString *)label control:(NSControl **)pControl highPriority:(BOOL)highPriority isDefault:(BOOL)isDefault
{
	NSControl *&control = *pControl;
	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
	NSSize size;

	if ([control isKindOfClass:[NSSegmentedControl class]] && ![control isKindOfClass:[ToolbarSegmentedControl class]])
	{
		*pControl = [[ToolbarSegmentedControl alloc] initWithTemplate:*pControl];
	}
	size = [control frame].size;
	size.height += 1.0f;
	[item setLabel:label];
	[item setPaletteLabel:label];
	[item setToolTip:label];
	[item setTarget:self];
	[item setMinSize:size];
	[item setMaxSize:size];
	[control retain];
	[control removeFromSuperview];
	[item setView:control];
	[control release];
	if (highPriority)
	{
		[item setVisibilityPriority:NSToolbarItemVisibilityPriorityHigh];
	}
	else
	{
		[item setVisibilityPriority:NSToolbarItemVisibilityPriorityStandard];
	}
	[toolbarItems setObject:item forKey:identifier];
	if (isDefault)
	{
		[defaultIdentifiers addObject:identifier];
	}
	else
	{
		[otherIdentifiers addObject:identifier];
	}
	[allIdentifiers addObject:identifier];
	[item release];
	return item;
}

- (void)updateSegments:(NSSegmentedControl *)segments states:(NSArray *)states
{
	int i;
	int count = [states count];
	NSSegmentedCell *cell = [segments cell];
	
	for (i = 0; i < count; i++)
	{
		[cell setSelected:[[states objectAtIndex:i] boolValue] forSegment:i];
	}
}

- (void)setupSegments:(NSSegmentedControl *)segments toolTips:(NSArray *)toolTips
{
	int i;
	int count = [toolTips count];
	NSSegmentedCell *cell = [segments cell];

	for (i = 0; i < count; i++)
	{
		[cell setToolTip:[toolTips objectAtIndex:i] forSegment:i];
	}
}

- (void)updateFeatureStates
{
	LDPreferences *ldPreferences = [[controller preferences] ldPreferences];
	NSArray *states = [NSArray arrayWithObjects:
		[NSNumber numberWithBool:ldPreferences->getDrawWireframe()],
		[NSNumber numberWithBool:ldPreferences->getUseSeams()],
		[NSNumber numberWithBool:ldPreferences->getShowHighlightLines()],
		[NSNumber numberWithBool:ldPreferences->getAllowPrimitiveSubstitution()],
		[NSNumber numberWithBool:ldPreferences->getUseLighting()],
		[NSNumber numberWithBool:ldPreferences->getBfc()],
		nil];

	[self updateSegments:featuresSegments states:states];
}

- (void)preferencesDidUpdate:(NSNotification *)notification
{
	[self updateFeatureStates];
}

- (void)setupFeatures
{
	NSArray *toolTips = [NSArray arrayWithObjects:
		@"Enable/Disable Wireframe",
		@"Enable/Disable Seams",
		@"Enable/Disable Edges",
		@"Enable/Disable Primitive Substitution",
		@"Enable/Disable Lighting",
		@"Enable/Disable BFC",
		nil];
	featuresSegments = [[ToolbarSegmentedControl alloc] initWithTemplate:featuresSegments];
	[self setupSegments:featuresSegments toolTips:toolTips];
	[self updateFeatureStates];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesDidUpdate:) name:LDPreferencesDidUpdateNotification object:nil];
}

- (void)setExamineLatLong:(bool)value
{
	LDrawModelViewer::ExamineMode examineMode = LDrawModelViewer::EMFree;
	
	if (value)
	{
		examineMode = LDrawModelViewer::EMLatLong;
	}
	[modelView modelViewer]->setExamineMode(examineMode);
	TCUserDefaults::setLongForKey(examineMode, EXAMINE_MODE_KEY, false);
}

- (void)setFlyThroughMode:(bool)value
{
	flyThroughMode = value;
	[modelView setFlyThroughMode:flyThroughMode];
	if (flyThroughMode)
	{
		[viewModeSegments selectSegmentWithTag:LDInputHandler::VMFlyThrough];
	}
	else
	{
		[viewModeSegments selectSegmentWithTag:LDInputHandler::VMExamine];
	}
}

- (void)setupViewMode
{
	NSArray *toolTips = [NSArray arrayWithObjects:
		@"Examine Mode",
		@"Fly-through Mode",
		nil];
	viewModeSegments = [[ToolbarSegmentedControl alloc] initWithTemplate:viewModeSegments];
	[self setupSegments:viewModeSegments toolTips:toolTips];
	[self setFlyThroughMode:TCUserDefaults::longForKey(VIEW_MODE_KEY, LDInputHandler::VMExamine, false) == LDInputHandler::VMFlyThrough];
	[modelView setFlyThroughMode:flyThroughMode];
	examineLatLong = TCUserDefaults::longForKey(EXAMINE_MODE_KEY, LDrawModelViewer::EMFree, false) == LDrawModelViewer::EMLatLong;
	[self setExamineLatLong:examineLatLong];
}

- (void)setupToolbarItems
{
	toolbarItems = [[NSMutableDictionary alloc] init];
	defaultIdentifiers = [[NSMutableArray alloc] init];
	otherIdentifiers = [[NSMutableArray alloc] init];
	allIdentifiers = [[NSMutableArray alloc] init];

	[[viewPopUp itemAtIndex:0] setImage:[NSImage imageNamed:@"toolbar_view"]];
	viewPopUp = [[ToolbarPopUpButton alloc] initWithTemplate:viewPopUp];
	[self setupFeatures];
	[self setupViewMode];
	[self addToolbarItemWithIdentifier:@"OpenFile" label:[OCLocalStrings get:@"OpenFile"] control:&openButton highPriority:NO isDefault:YES];
	[self addToolbarItemWithIdentifier:@"SaveSnapshot" label:[OCLocalStrings get:@"SaveSnapshot"] control:&snapshotButton highPriority:NO isDefault:YES];
	[self addToolbarItemWithIdentifier:@"Reload" label:[OCLocalStrings get:@"Reload"] control:&reloadButton highPriority:NO isDefault:YES];
	// ToDo: Localize
	[self addToolbarItemWithIdentifier:@"Actions" label:@"Actions" control:&actionsSegments highPriority:NO isDefault:NO];
	// ToDo: Localize
	[self addToolbarItemWithIdentifier:@"Features" label:@"Features" control:&featuresSegments highPriority:NO isDefault:YES];
	[self addToolbarItemWithIdentifier:@"View" label:[OCLocalStrings get:@"SelectView"] control:&viewPopUp highPriority:NO isDefault:YES];
	[defaultIdentifiers addObject:NSToolbarFlexibleSpaceItemIdentifier];	
	[self addToolbarItemWithIdentifier:@"Prefs" label:[OCLocalStrings get:@"Preferences"] control:&prefsSegments highPriority:YES isDefault:YES];
	// ToDo: Localize
	[self addToolbarItemWithIdentifier:@"ViewMode" label:@"View Mode" control:&viewModeSegments highPriority:NO isDefault:NO];
	[[actionsSegments cell] setToolTip: [OCLocalStrings get:@"OpenFile"] forSegment:0];
	[[actionsSegments cell] setToolTip: [OCLocalStrings get:@"SaveSnapshot"] forSegment:1];
	[[actionsSegments cell] setToolTip: [OCLocalStrings get:@"Reload"] forSegment:2];
	[allIdentifiers addObjectsFromArray:[NSArray arrayWithObjects:
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarPrintItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil]];
	//[defaultIdentifiers addObject:NSToolbarCustomizeToolbarItemIdentifier];
}

- (void)setupToolbar
{
	[self setupToolbarItems];
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"LDViewToolbar"];
	[toolbar setDelegate:self];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setSizeMode:NSToolbarSizeModeSmall];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
}

- (BOOL)showStatusBar:(BOOL)show
{
	BOOL changed = NO;
	
	if (show)
	{
		if (![statusBar superview])
		{
			NSRect modelViewFrame1 = [modelView frame];
			float height = [statusBar frame].size.height;
			
			modelViewFrame1.size.height -= height;
			modelViewFrame1.origin.y += height;
			[modelView setFrame:modelViewFrame1];
			[[window contentView] addSubview:statusBar];
			changed = YES;
		}
	}
	else
	{
		if ([statusBar superview])
		{
			NSRect modelViewFrame2 = [modelView frame];
			float height = [statusBar frame].size.height;
			
			modelViewFrame2.size.height += height;
			modelViewFrame2.origin.y -= height;
			[statusBar removeFromSuperview];
			[modelView setFrame:modelViewFrame2];
			changed = YES;
		}
	}
	return changed;
}

- (void)awakeFromNib
{
	showStatusBar = [OCUserDefaults longForKey:@"StatusBar" defaultValue:1 sessionSpecific:NO];
	[self showStatusBar:showStatusBar];
	[self setupToolbar];
	[window setToolbar:toolbar];
	[statusBar retain];
	progressAdjust = [progressMessage frame].origin.x - [progress frame].origin.x;
	[window setNextResponder:controller];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(errorFilterChange:) name:LDErrorFilterChange object:nil];
	imageFileTypes = [[NSArray alloc] initWithObjects:@"png", @"bmp", nil];
}

- (id)initWithController:(LDViewController *)value
{
	if ((self = [super init]) != nil)
	{
		controller = value;
		[NSBundle loadNibNamed:@"ModelWindow.nib" owner:self];
		alertHandler = new AlertHandler(self);
	}
	return self;
}

- (void)enableToolbarItems:(BOOL)enabled
{
	NSEnumerator *enumerator = [allIdentifiers objectEnumerator];
	
	while (NSString *identifier = [enumerator nextObject])
	{
		NSToolbarItem *item = [toolbarItems objectForKey:identifier];
		NSControl *control = (NSControl *)[item view];

		if (control == actionsSegments)
		{
			[actionsSegments setEnabled:enabled forSegment:1];
			[actionsSegments setEnabled:enabled forSegment:2];
		}
		else if ([control isKindOfClass:[NSControl class]])
		{
			[control setEnabled:enabled];
		}
	}
}

- (ErrorItem *)filteredRootErrorItem
{
	if (unfilteredRootErrorItem && !filteredRootErrorItem)
	{
		filteredRootErrorItem = [[[ErrorsAndWarnings sharedInstance] filteredRootErrorItem:unfilteredRootErrorItem] retain];
	}
	return filteredRootErrorItem;
}

- (BOOL)openModel:(NSString *)filename
{
	[unfilteredRootErrorItem release];
	unfilteredRootErrorItem = nil;
	[filteredRootErrorItem release];
	filteredRootErrorItem = nil;
	[window setTitleWithRepresentedFilename:filename];
	[window makeKeyAndOrderFront:self];
	if ([modelView openModel:filename])
	{
		[self enableToolbarItems:YES];
		if ([[ErrorsAndWarnings sharedInstance] isVisible])
		{
			[[ErrorsAndWarnings sharedInstance] update:self];
		}
		return YES;
	}
	else
	{
		return NO;
	}
}

- (LDrawModelView *)modelView
{
	return modelView;
}

- (void)addErrorItem:(ErrorItem *)parent string:(NSString *)string error:(LDLError *)error
{
	[parent addChild:[[[ErrorItem alloc] initWithString:string error:error includeIcon:NO] autorelease]];
}

- (void)ldlErrorCallback:(LDLError *)error
{
	TCStringArray *extraInfo = error->getExtraInfo();
	NSString *lineString;

	if (!unfilteredRootErrorItem)
	{
		unfilteredRootErrorItem = [[ErrorItem alloc] init];
	}
	ErrorItem *errorItem = [unfilteredRootErrorItem addChild:[[[ErrorItem alloc] initWithString:[NSString stringWithCString:error->getMessage() encoding:NSASCIIStringEncoding] error:error includeIcon:YES] autorelease]];
	if (error->getFilename())
	{
		lineString = [NSString stringWithFormat:@"%@%s", [OCLocalStrings get:@"ErrorTreeFilePrefix"], error->getFilename()];
	}
	else
	{
		lineString = [OCLocalStrings get:@"ErrorTreeUnknownFile"];
	}
	[self addErrorItem:errorItem string:lineString error:error];
	if (error->getFileLine())
	{
		int lineNumber = error->getLineNumber();
		
		if (lineNumber > 0)
		{
			lineString = [NSString stringWithFormat:[OCLocalStrings get:@"ErrorTreeLine#"], lineNumber];
		}
		else
		{
			lineString = [OCLocalStrings get:@"ErrorTreeUnknownLine#"];
		}
	}
	else
	{
		lineString = [OCLocalStrings get:@"ErrorTreeUnknownLine"];
	}
	[self addErrorItem:errorItem string:lineString error:error];
	if (extraInfo)
	{
		for (int i = 0; i < extraInfo->getCount(); i++)
		{
			[self addErrorItem:errorItem string:[NSString stringWithCString:extraInfo->stringAtIndex(i) encoding:NSASCIIStringEncoding] error:error];
		}
	}
}

- (void)adjustProgressMessageSize:(float)amount
{
	NSRect frame = [progressMessage frame];
	frame.origin.x -= amount;
	frame.size.width += amount;
	[progressMessage setFrame:frame];
}

- (void)progressAlertCallback:(TCProgressAlert *)alert
{
	if ([NSOpenGLContext currentContext] != [modelView openGLContext])
	{
		// This alert is coming from a different model viewer.
		[self showStatusBar:showStatusBar];
		return;
	}
	static NSDate *lastProgressUpdate = NULL;
	float alertProgress = alert->getProgress();
	NSString *alertMessage = [NSString stringWithCString:alert->getMessage()
		encoding:NSASCIIStringEncoding];
	BOOL forceUpdate = NO;
	BOOL updated = NO;

	if ([self showStatusBar:YES])
	{
		[window display];
	}
	if (![alertMessage isEqualToString:[progressMessage stringValue]])
	{
		[progressMessage setStringValue:alertMessage];
		forceUpdate = YES;
	}
	if (alertProgress >= 0.0f && alertProgress <= 1.0f)
	{
		// Don't update the progress more than 5 times per second, or loading
		// the model can take a REALLY long time.
		if (alertProgress == 1.0f || lastProgressUpdate == NULL ||
			[lastProgressUpdate timeIntervalSinceNow] < -0.2)
		{
			[window makeFirstResponder:progress];
			if ([progress isHidden])
			{
				[progress setHidden:NO];
				[self adjustProgressMessageSize: -progressAdjust]; 
			}
			[progress setDoubleValue:alertProgress];
			[statusBar display];
			updated = YES;
			[lastProgressUpdate release];
			lastProgressUpdate = [[NSDate alloc] init];
		}
	}
	else if (alertProgress == 2.0f)
	{
		[progress setDoubleValue:1.0];
		if (![progress isHidden])
		{
			[progress setHidden:YES];
			[self adjustProgressMessageSize: progressAdjust]; 
		}
		[self showStatusBar:showStatusBar];
	}
	if (forceUpdate && !updated)
	{
		[statusBar display];
	}
}

- (void)modelViewerAlertCallback:(TCAlert *)alert
{
	[modelView modelViewerAlertCallback:alert];
}

- (void)redrawAlertCallback:(TCAlert *)alert
{
	[modelView redrawAlertCallback:alert];
}

- (void)captureAlertCallback:(TCAlert *)alert
{
	[modelView captureAlertCallback:alert];
}

- (void)releaseAlertCallback:(TCAlert *)alert
{
	[modelView releaseAlertCallback:alert];
}

//- (void)peekMouseUpAlertCallback:(TCAlert *)alert
//{
//	[modelView peekMouseUpAlertCallback:alert];
//}

- (void)reloadNeeded
{
	[window makeKeyWindow];
	[modelView reloadNeeded];
}

- (void)modelWillReload
{
	[self performSelectorOnMainThread:@selector(reloadNeeded) withObject:nil waitUntilDone:NO];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	if ([aNotification object] == window)
	{
		[self autorelease];
	}
}

- (void)showFps
{
	[modelView setFps:0.0f];
	if ([[controller preferences] ldPreferences]->getShowFps() && [modelView modelViewer]->getMainTREModel())
	{
		if (showStatusBar)
		{
			if (fps > 0.0f)
			{
				[progressMessage setStringValue:[NSString stringWithFormat:[OCLocalStrings get:@"FPSFormat"], fps]];
			}
			else
			{
				[progressMessage setStringValue:[OCLocalStrings get:@"FPSSpinPrompt"]];
			}
		}
		else
		{
			[modelView setFps:fps];
		}
	}
	else
	{
		[progressMessage setStringValue:@""];
	}
}

- (void)updateFps
{
	if (fpsReferenceDate)
	{
		NSTimeInterval interval = -[fpsReferenceDate timeIntervalSinceNow];
		
		if (interval >= 0.25)
		{
			[fpsReferenceDate release];
			fpsReferenceDate = [[NSDate alloc] init];
			fps = 1.0 / interval * fpsFrameCount;
			fpsFrameCount = 1;
		}
		else
		{
			fpsFrameCount++;
		}
	}
	else
	{
		fpsReferenceDate = [[NSDate alloc] init];
	}
	[self showFps];
}

- (void)clearFps
{
	[fpsReferenceDate release];
	fpsReferenceDate = nil;
	fps = 0.0f;
	fpsFrameCount = 1;
	[self showFps];
}

- (void)setShowStatusBar:(BOOL)value
{
	showStatusBar = value;
	[self showStatusBar:showStatusBar];
}

- (BOOL)showStatusBar
{
	return showStatusBar;
}

- (void)show
{
	[window makeKeyAndOrderFront:self];
}

- (NSWindow *)window
{
	return window;
}

- (NSToolbar *)toolbar
{
	return toolbar;
}

- (IBAction)open:(id)sender
{
	[controller openModel:sender];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSSize viewSize = [modelView frame].size;
		int width = (int)viewSize.width;
		int height = (int)viewSize.height;		
		
		if (!snapshotTaker)
		{
			snapshotTaker = [[SnapshotTaker alloc] initWithModelViewer:[modelView modelViewer] sharedContext:[modelView openGLContext]];
		}
		[snapshotTaker setImageType:[saveSnapshotViewOwner imageType]];
		[snapshotTaker setTrySaveAlpha:[saveSnapshotViewOwner transparentBackground]];
		[snapshotTaker setAutoCrop:[saveSnapshotViewOwner autocrop]];
		[(NSSavePanel *)contextInfo orderOut:self];
		[snapshotTaker saveFile:[sheet filename] width:[saveSnapshotViewOwner width:width] height:[saveSnapshotViewOwner height:height] zoomToFit:[saveSnapshotViewOwner zoomToFit]];
		[saveSnapshotViewOwner saveSettings];
	}
	[saveSnapshotViewOwner setSavePanel:nil];
}

- (IBAction)saveSnapshot:(id)sender
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	NSString *modelFilename = [window representedFilename];
	NSString *modelPath = [modelFilename stringByDeletingLastPathComponent];
	NSString *defaultFilename = [[modelFilename lastPathComponent] stringByDeletingPathExtension];

	if (!saveSnapshotViewOwner)
	{
		saveSnapshotViewOwner = [[SaveSnapshotViewOwner alloc] init];
	}
	[saveSnapshotViewOwner setSavePanel:savePanel];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel beginSheetForDirectory:modelPath file:defaultFilename modalForWindow:window modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:savePanel];
}

- (IBAction)reload:(id)sender
{
	[modelView reload];
}

- (IBAction)actions:(id)sender
{
	switch ([[sender cell] tagForSegment:[sender selectedSegment]])
	{
		case 0:
			[self open:sender];
			break;
		case 1:
			[self saveSnapshot:sender];
			break;
		case 2:
			[self reload:sender];
			break;
		default:
			NSLog(@"Unknown action.\n");
			break;
	}
}

- (void)toggleFeature:(SEL)selector sender:(id)sender
{
	// I know it looks wrong that were asking if the selectedSegment
	// is selected.  However, selectedSegment just returns the segment
	// the user just clicked on.  It's not necessarily actually selected.
	[[controller preferences] performSelector:selector withObject:sender];
}

- (IBAction)features:(id)sender
{
	switch ([[sender cell] tagForSegment:[sender selectedSegment]])
	{
		case 0:
			[self toggleFeature:@selector(takeWireframeFrom:) sender:sender];
			break;
		case 1:
			[self toggleFeature:@selector(takeSeamsFrom:) sender:sender];
			break;
		case 2:
			[self toggleFeature:@selector(takeEdgesFrom:) sender:sender];
			break;
		case 3:
			[self toggleFeature:@selector(takePrimSubFrom:) sender:sender];
			break;
		case 4:
			[self toggleFeature:@selector(takeLightingFrom:) sender:sender];
			break;
		case 5:
			[self toggleFeature:@selector(takeBfcFrom:) sender:sender];
			break;
		default:
			NSLog(@"Unknown feature.\n");
			break;
	}
}

- (IBAction)viewingAngle:(id)sender
{
	[modelView setViewingAngle:[sender tag]];
}

- (IBAction)saveViewingAngle:(id)sender
{
	[[controller preferences] saveViewingAngle:self];
}

- (IBAction)preferences:(id)sender
{
	[controller preferences:sender];
}

- (IBAction)alwaysOnTop:(id)sender
{
	if ([window level] == NSNormalWindowLevel)
	{
		[window setLevel:NSPopUpMenuWindowLevel];
	}
	else
	{
		[window setLevel:NSNormalWindowLevel];
	}
}

- (IBAction)toggleStatusBar:(id)sender
{
	[self setShowStatusBar:!showStatusBar];
	//[controller updateStatusBarMenuItem];
	[OCUserDefaults setLong:showStatusBar forKey:@"StatusBar" sessionSpecific:NO];
}

- (IBAction)customizeToolbar:(id)sender
{
	[toolbar runCustomizationPalette:sender];
}

- (IBAction)viewMode:(id)sender
{
	[modelView viewMode:sender];
}

- (IBAction)zoomToFit:(id)sender
{
	[modelView zoomToFit:sender];
}

- (IBAction)errorsAndWarnings:(id)sender
{
	[[ErrorsAndWarnings sharedInstance] update:self];
	[[ErrorsAndWarnings sharedInstance] show:self];
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	if ([[ErrorsAndWarnings sharedInstance] isVisible])
	{
		[[ErrorsAndWarnings sharedInstance] update:self];
	}
}

- (void)errorFilterChange:(NSNotification *)aNotification
{
	[filteredRootErrorItem release];
	filteredRootErrorItem = nil;
	[[ErrorsAndWarnings sharedInstance] update:self];
}

- (LDViewController *)controller
{
	return controller;
}

- (void)lightVectorChanged:(TCAlert *)alert
{
	[modelView modelViewer]->setLightVector([[controller preferences] ldPreferences]->getLightVector());
	[modelView rotationUpdate];
	[[controller preferences] lightVectorChanged:alert];
}

- (IBAction)latLongRotation:(id)sender
{
	examineLatLong = !examineLatLong;
	[self setExamineLatLong:examineLatLong];
}

- (IBAction)examineMode:(id)sender
{
	[self setFlyThroughMode:false];
}

- (IBAction)flyThroughMode:(id)sender
{
	[self setFlyThroughMode:true];
}

- (bool)examineLatLong
{
	return examineLatLong;
}

- (bool)flyThroughMode
{
	return flyThroughMode;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
	return [controller validateMenuItem:menuItem];
}

@end
