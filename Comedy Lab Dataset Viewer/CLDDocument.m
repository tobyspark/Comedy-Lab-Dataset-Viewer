//
//  TBZDocument.m
//  Comedy Lab Dataset Viewer
//
//  Created by Toby Harris | http://tobyz.net on 13/05/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import "CLDDocument.h"

static NSString * const CLDPackageMovieFileName = @"movie";
static NSString * const CLDPackageMocapFileName = @"mocap.csv";
static NSString * const CLDPackageDatasetPath = @"dataset.csv";
static NSString * const CLDPackageLookingAtFileName = @"lookingAt.csv";
static NSString * const CLDPackageSceneFileName = @"Scene.dae";
static NSString * const CLDPackageMetadataFileName = @"Metadata.plist";
static NSString * const CLDMetadataKeyMoviePath = @"moviePath";
static NSString * const CLDMetadataKeyMocapPath = @"mocapPath";
static NSString * const CLDMetadataKeyDatasetPath = @"datasetPath";
static NSString * const CLDMetadataKeyLookingAtPath = @"lookingAtPath";
static NSString * const CLDMetadataKeyViewPovs = @"freeViewPOVs";
static NSString * const CLDMetadataKeyVolume = @"volume";
static NSString * const CLDMetadataKeyMuted = @"muted";
static NSString * const CLDMetadataKeyViewLightState = @"lightState";
static NSString * const CLDMetadataKeyViewLaughState = @"laughState";
static NSString * const CLDMetadataKeyViewBreathingBelt = @"breathingBelt";
static NSString * const CLDMetadataKeyViewShoreHappiness = @"happiness";
static NSString * const CLDMetadataKeyViewGaze = @"gaze";
static NSString * const CLDMetadataKeyViewLookingAt = @"lookingAt";

@interface CLDDocument ()

@property (strong, nonatomic) SCNScene *scene;

@property (weak)   CALayer          *superLayer;
@property (strong) AVPlayer         *player;
@property (strong) AVPlayerView     *playerView;
@property (strong) AVPlayerLayer    *playerLayer;
@property (strong) CALayer          *playerBlurLayer;
@property (strong) CALayer          *playerMaskLayer;
@property (strong) SCNLayer         *audienceSceneLayer;
@property (strong) SCNLayer         *performerSceneLayer;
@property (strong) CLDView          *freeSceneView;

@property (strong) NSMutableArray* freeSceneViewPovs;

@end

@implementation CLDDocument

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        
        _freeSceneViewPovs = [NSMutableArray arrayWithCapacity:10];
        
        _viewLightState = YES;
        _viewLaughState = YES;
        _viewBreathingBelt = YES;
        _viewShoreHappiness = YES;
        _viewGaze = YES;
        _viewLookingAt = YES;
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"CLDDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    
    // TASK: Make window layer backed
    
    [aController.window.contentView setWantsLayer:YES];
    [aController.window.contentView setLayerUsesCoreImageFilters:YES];
    
    [self setSuperLayer:[(NSView*)aController.window.contentView layer]];
    
    // Set delegate so we can handle laying out sublayers, and do the views while we're at it
    [self.superLayer setDelegate:self];
    
    // TASK: Setup views
    
    // Use AVPlayerView rather than AVPlayerLayer as this gives us UI
    [self setPlayerView:[[AVPlayerView alloc] initWithFrame:aController.window.frame]];
    [self.playerView setControlsStyle:AVPlayerViewControlsStyleInline];
    [self.playerView setPlayer:self.player];
    
    [aController.window.contentView addSubview:self.playerView];
    
    // Use SCNView rather than layer as this gives us UI, and we can now keep in sync using AVPlayer's periodicTimeObserver rather than the broken elegance of AVSyncronizedLayer
    [self setFreeSceneView:[[CLDView alloc] initWithFrame:aController.window.frame]];
    [self.freeSceneView setAutoenablesDefaultLighting:YES];
    [self.freeSceneView setAllowsCameraControl:YES];
    
    [aController.window.contentView addSubview:self.freeSceneView];
    
    // TASK: Setup individual layers
    
    [self setAudienceSceneLayer:[SCNLayer layer]];
    [self.audienceSceneLayer setAutoenablesDefaultLighting:YES];
    
    [self setPerformerSceneLayer:[SCNLayer layer]];
    [self.performerSceneLayer setAutoenablesDefaultLighting:YES];
    
    [self setPlayerLayer:[AVPlayerLayer layer]];
    [self.playerLayer setPlayer:self.player];

    [self setPlayerBlurLayer:[CALayer layer]];
    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    // TODO: blur size should scale with audienceRect
    [blur setDefaults];
    [self.playerBlurLayer setBackgroundFilters: @[blur]];
    [self.playerBlurLayer setMasksToBounds: YES];
    
    [self setPlayerMaskLayer:[CALayer layer]];
    [self.playerMaskLayer setBackgroundColor:CGColorCreateGenericGray(0, 1)];
    [self.playerMaskLayer setOpacity:0];
    
#ifdef CLDRegister3D
    const char* path = [[[NSBundle mainBundle] pathForResource:@"CLDRegister3D Audience video frame guides" ofType:@"png"] cStringUsingEncoding:NSUTF8StringEncoding];
    CGDataProviderRef dataProvider = CGDataProviderCreateWithFilename(path);
    CGImageRef image = CGImageCreateWithPNGDataProvider(dataProvider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    [self.playerMaskLayer setContents:CFBridgingRelease(image)];
#endif
    
    // TASK: Set layers into tree
    
    [self.superLayer addSublayer:self.playerLayer];
    [self.superLayer addSublayer:self.playerBlurLayer];
    [self.superLayer addSublayer:self.playerMaskLayer];
    [self.superLayer addSublayer:self.audienceSceneLayer];
    [self.superLayer addSublayer:self.performerSceneLayer];
    
    // TASK: Set view menu
    NSMenu *viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    [viewMenu setDelegate:self];
    
    // TASK: Get going for user
    
    self.scene = [SCNScene comedyLabScene];
    if ([self.freeSceneViewPovs count] < 3)
    {
        [self setFreeSceneViewPovs:[[self.scene standardCameraPositions] mutableCopy]];
    }
    
    [self performSelectorInBackground:@selector(loadMocap) withObject:nil];
    [self performSelectorInBackground:@selector(loadDataset) withObject:nil];
    [self performSelectorInBackground:@selector(loadLookingAt) withObject:nil];
    
    [self loadMovie];
    
    [self.player play];
}

- (IBAction) chooseMovie:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setTitle:@"Select video"];
    [openPanel setAllowedFileTypes:@[@"public.movie"]];
    [openPanel setAllowsMultipleSelection:NO];
    
    NSWindowController* wc = self.windowControllers[0];
    
    [openPanel beginSheetModalForWindow:wc.window completionHandler:^(NSInteger result) {
        self.movieURL = [openPanel URLs][0];
        [self loadMovie];
    }];
}

- (IBAction) chooseMocapData:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setTitle:@"Select Mocap Data CSV"];
    [openPanel setAllowedFileTypes:@[@"public.comma-separated-values-text"]];
    [openPanel setAllowsMultipleSelection:NO];
    
    NSWindowController* wc = self.windowControllers[0];
    
    [openPanel beginSheetModalForWindow:wc.window completionHandler:^(NSInteger result) {
        self.mocapURL = [openPanel URLs][0];
        [self loadMocap];
    }];
}

- (IBAction) chooseAnalysisDataset:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setTitle:@"Select Analysis Dataset CSV"];
    [openPanel setAllowedFileTypes:@[@"public.comma-separated-values-text"]];
    [openPanel setAllowsMultipleSelection:NO];
    
    NSWindowController* wc = self.windowControllers[0];
    
    [openPanel beginSheetModalForWindow:wc.window completionHandler:^(NSInteger result) {
        self.datasetURL = [openPanel URLs][0];
        [self loadDataset];
    }];
}

- (IBAction) chooseLookingAtData:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setTitle:@"Select LookingAt Data CSV"];
    [openPanel setAllowedFileTypes:@[@"public.comma-separated-values-text"]];
    [openPanel setAllowsMultipleSelection:NO];
    
    NSWindowController* wc = self.windowControllers[0];
    
    [openPanel beginSheetModalForWindow:wc.window completionHandler:^(NSInteger result) {
        self.lookingAtURL = [openPanel URLs][0];
        [self loadLookingAt];
    }];
}

- (void) loadMovie
{
    if (!self.playerView)
    {
        NSLog(@"Cannot load movie if playerView not initialised");
        return;
    }
    
    if (!self.movieURL)
    {
        NSLog(@"No movie to load");
        return;
    }
    
    NSURL *url = [[self fileURL] URLByAppendingPathComponent:CLDPackageMovieFileName];
    // We should really check if AVPlayerItem status is AVPlayerItemStatusFailed
    // But that is asynchronos and it would be over the top for this app to handle that.
    if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]])
    {
        url = self.movieURL;
    }
    
    NSLog(@"Loading movie: %@", url);

    AVPlayer *player = [AVPlayer playerWithURL:url];
    __weak __typeof(AVPlayer) *weakPlayer = player;
    // AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions), see early commits
    // So we use this instead, which also allows us to make freeScene a SCNView with it's built-in camera UI.
    [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.1, 600) queue:NULL usingBlock:^(CMTime time) {
        NSTimeInterval timeSecs = CMTimeGetSeconds(time);
        
        if (self.loop)
        {
            if (timeSecs > [[self.scene attributeForKey:SCNSceneEndTimeAttributeKey] doubleValue])
            {
                timeSecs = [[self.scene attributeForKey:SCNSceneStartTimeAttributeKey] doubleValue];
                [weakPlayer seekToTime:CMTimeMakeWithSeconds(timeSecs, 600)];
            }
        }
        
    #ifdef DEBUG
        timeSecs += self.freeSceneView.timeOffset;
    #endif
        
        [self.audienceSceneLayer setCurrentTime:timeSecs];
        [self.performerSceneLayer setCurrentTime:timeSecs];
        [self.freeSceneView setCurrentTime:timeSecs];
    }];
    
    [self movieSeekToSceneStart];
    
    [player setVolume:self.movieVolume];
    
    self.player = player;
    
    // These should KVO or somesuch...
    [self.playerView setPlayer:self.player];
    [self.playerLayer setPlayer:self.player];
}

- (void) movieSeekToSceneStart
{
    NSTimeInterval startTime = [[self.scene attributeForKey:SCNSceneStartTimeAttributeKey] doubleValue];
    NSTimeInterval currentTime = CMTimeGetSeconds([self.player currentTime]);
    
    if (currentTime < startTime)
    {
        [self.player seekToTime:CMTimeMakeWithSeconds(startTime, 600)];
    }
}

- (void) setScene:(SCNScene *)scene
{
    _scene = scene;
    
    [self.freeSceneView setScene:scene];
    [self.freeSceneView setPointOfView:[scene.rootNode childNodeWithName:@"Camera-Orthographic" recursively:NO]];
    
    [self.audienceSceneLayer setScene:scene];
    [self.audienceSceneLayer setPointOfView:[scene.rootNode childNodeWithName:@"Camera-Audience" recursively:NO]];
    
    [self.performerSceneLayer setScene:scene];
    [self.performerSceneLayer setPointOfView:[scene.rootNode childNodeWithName:@"Camera-Performer" recursively:NO]];
}

- (void) loadMocap
{
    if (!self.scene)
    {
        NSLog(@"Cannot load mocap data if scene not initialised");
        return;
    }
    @synchronized(self.scene)
    {
        BOOL success = [self.scene addWithMocapURL:[[self fileURL] URLByAppendingPathComponent:CLDPackageMocapFileName] error:nil];
        if (!success) [self.scene addWithMocapURL:self.mocapURL error:nil];
        
        [self movieSeekToSceneStart];
        [self toggleDataView:nil];
    }
}

- (void) loadDataset
{
    if (!self.scene)
    {
        NSLog(@"Cannot load analytic dataset if scene not initialised");
        return;
    }
    
    @synchronized(self.scene)
    {
        BOOL success = [self.scene addWithDatasetURL:[[self fileURL] URLByAppendingPathComponent:CLDPackageDatasetPath] error:nil];
        if (!success) [self.scene addWithDatasetURL:self.datasetURL error:nil];

        [self movieSeekToSceneStart];
        [self toggleDataView:nil];
    }
}

- (void) loadLookingAt
{
    if (!self.scene)
    {
        NSLog(@"Cannot load lookingAt data if scene not initialised");
        return;
    }
    
    @synchronized(self.scene)
    {
        BOOL success = [self.scene addWithLookingAtURL:[[self fileURL] URLByAppendingPathComponent:CLDPackageLookingAtFileName] error:nil];
        if (!success) [self.scene addWithLookingAtURL:self.lookingAtURL error:nil];
        
        [self movieSeekToSceneStart];
        [self toggleDataView:nil];
    }
}

- (IBAction) freeSceneViewAddCurrentPov:(id)sender
{
    // TASK: Capture current point-of-view and set menu item for it's recall
    
    NSData *povData = [self.scene positionDataWithCameraNode:self.freeSceneView.pointOfView];
    
    [self.freeSceneViewPovs addObject:povData];
}

- (IBAction) freeSceneViewSetCurrentPov:(id)sender
{
    // TASK: Recall previously captured point of view
    
    NSData *recalledPovData = [sender representedObject];
    
    // Use implicit animation as CABasicAnimation strangely won't work
    // But this requires setting duration back to zero for the freeView camera to work
    [SCNTransaction begin];
    
    [SCNTransaction setAnimationDuration:1];
    
    [SCNTransaction setCompletionBlock:^{
        [SCNTransaction setAnimationDuration:0];
    }];
    
    [self.freeSceneView setPovOrtho];
    [self.scene setCameraNodePosition:self.freeSceneView.pointOfView withData:recalledPovData];
    
    [SCNTransaction commit];
}

- (IBAction) freeSceneViewSetPovToFirstPerson:(id)sender
{
    NSLog(@"sender: %@", sender);
    [self.freeSceneView setPovWithPersonNode:[sender representedObject]];
}

- (IBAction) toggleAudienceMask:(id)sender
{
    // We move the audience camera a bit to get a better view when we're just looking at the 3D scene.
    // Audience camera node is at x=0 (what are the chances).
    // Should do this more elegantly, but hey. This app is tied to the dataset.
    SCNNode *audienceCameraNode = [[self.scene rootNode] childNodeWithName:@"Camera-Audience" recursively:NO];
    SCNVector3 position = [audienceCameraNode position];
    
    if ([sender state] == NSOnState)
    {
        [self.playerMaskLayer setOpacity:0];
        
        [SCNTransaction begin];
        [SCNTransaction setAnimationDuration:0.25];
        
        [audienceCameraNode setPosition:SCNVector3Make(0, position.y, position.z)];
        
        [SCNTransaction setCompletionBlock:^{
            [SCNTransaction setAnimationDuration:0];
        }];
        [SCNTransaction commit];
    }
    else
    {
        [self.playerMaskLayer setOpacity:1];
        
        [SCNTransaction begin];
        [SCNTransaction setAnimationDuration:1];
        
        [audienceCameraNode setPosition:SCNVector3Make(-1000, position.y, position.z)];
    
        [SCNTransaction setCompletionBlock:^{
            [SCNTransaction setAnimationDuration:0];
        }];
        [SCNTransaction commit];
    }
}

- (IBAction) toggleDataView:(id)sender
{
    if ([[sender title] isEqualToString:@"Light state"])
    {
        self.viewLightState = !self.viewLightState;
    }
    else if ([[sender title] isEqualToString:@"Laugh state"])
    {
        self.viewLaughState = !self.viewLaughState;
    }
    else if ([[sender title] isEqualToString:@"Chest expansion"])
    {
        self.viewBreathingBelt = !self.viewBreathingBelt;
    }
    else if ([[sender title] isEqualToString:@"SHORE happiness"])
    {
        self.viewShoreHappiness = !self.viewShoreHappiness;
    }
    else if ([[sender title] isEqualToString:@"Head pose"])
    {
        self.viewGaze = !self.viewGaze;
    }
    else if ([[sender title] isEqualToString:@"Oriented-to"])
    {
        self.viewLookingAt = !self.viewLookingAt;
    }
    
    [self.scene.rootNode childNodesPassingTest:^BOOL(SCNNode *child, BOOL *stop) {
        if ([[child name] hasPrefix:@"lightState"])
        {
            [child setHidden:!self.viewLightState];
        }
        else if ([[child name] hasPrefix:@"laughState"])
        {
            [child setHidden:!self.viewLaughState];
        }
        else if ([[child name] hasPrefix:@"breathingBelt"])
        {
            [child setHidden:!self.viewBreathingBelt];
        }
        else if ([[child name] hasPrefix:@"happiness"])
        {
            [child setHidden:!self.viewShoreHappiness];
        }
        else if ([[child name] hasPrefix:@"gaze"])
        {
            [child setHidden:!self.viewGaze];
        }
        else if ([[child name] hasPrefix:@"lookingAt"])
        {
            [child setHidden:!self.viewLookingAt];
        }
        return NO;
    }];
}

- (IBAction) toggleLoop:(id)sender
{
    self.loop = !self.loop;
}

#pragma mark - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu
{
    // CLDDocument is delegate only for the view menu
    NSMenu *viewMenu = menu;
    
    [[viewMenu itemWithTitle:@"Hide audience"] setState:self.playerMaskLayer.opacity == 1.0 ? NSOnState : NSOffState];
    
    [[viewMenu itemWithTitle:@"Loop"] setState:self.loop];
    
    [[viewMenu itemWithTitle:@"Light state"] setState:self.viewLightState];
    [[viewMenu itemWithTitle:@"Laugh state"] setState:self.viewLaughState];
    [[viewMenu itemWithTitle:@"Chest expansion"] setState:self.viewBreathingBelt];
    [[viewMenu itemWithTitle:@"SHORE happiness"] setState:self.viewShoreHappiness];
    [[viewMenu itemWithTitle:@"Head pose"] setState:self.viewGaze];
    [[viewMenu itemWithTitle:@"Oriented-to"] setState:self.viewLookingAt];
    
    NSMenu* firstPersonMenu = [[NSMenu alloc] initWithTitle:@""];
    for (SCNNode* node in [self.scene personNodes])
    {
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:node.name action:@selector(freeSceneViewSetPovToFirstPerson:) keyEquivalent:@""];
        [item setRepresentedObject:node];
        [firstPersonMenu addItem:item];
    }
    [viewMenu setSubmenu:firstPersonMenu forItem:[menu itemWithTitle:@"Perspective"]];
    
    NSUInteger startIndexForPovs = [[menu itemArray] indexOfObject:[menu itemWithTitle:@"Add ortho"]] + 1;
    NSUInteger povsCount = [self.freeSceneViewPovs count];
    NSUInteger menuitemsCount = [[viewMenu itemArray] count] - startIndexForPovs;
    
    while (povsCount < menuitemsCount)
    {
        [viewMenu removeItemAtIndex:menuitemsCount + startIndexForPovs - 1];
        menuitemsCount--;
    }
    
    while (povsCount > menuitemsCount)
    {
        NSString *povString = [NSString stringWithFormat:@"Camera Pos %lu", (unsigned long)menuitemsCount + 1];
        NSString *povKey = [NSString stringWithFormat:@"%lu", (unsigned long)menuitemsCount + 1];
        
        NSMenuItem *newPovMenuItem = [[NSMenuItem alloc] initWithTitle:povString action:@selector(freeSceneViewSetCurrentPov:) keyEquivalent:povKey];
        [newPovMenuItem setRepresentedObject:self.freeSceneViewPovs[menuitemsCount]];
        
        [viewMenu addItem:newPovMenuItem];
        menuitemsCount++;
    }
}

#pragma mark - Package Support

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    NSURL *sceneURL = [absoluteURL URLByAppendingPathComponent:CLDPackageSceneFileName];
    NSURL *metadataURL = [absoluteURL URLByAppendingPathComponent:CLDPackageMetadataFileName];
    BOOL sceneSuccess, metadataSuccess;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtURL:absoluteURL withIntermediateDirectories:NO attributes:nil error:nil];
    
    // TASK: Metadata
    
    NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithCapacity:5];
    
    NSString *moviePath = [self.movieURL path];
    if (moviePath) [metadata setObject:moviePath forKey:CLDMetadataKeyMoviePath];
    
    NSString *mocapPath = [self.mocapURL path];
    if (mocapPath) [metadata setObject:mocapPath forKey:CLDMetadataKeyMocapPath];
    
    NSString *datasetPath = [self.datasetURL path];
    if (datasetPath) [metadata setObject:datasetPath forKey:CLDMetadataKeyDatasetPath];

    NSString *lookingAtPath = [self.lookingAtURL path];
    if (lookingAtPath) [metadata setObject:lookingAtPath forKey:CLDMetadataKeyLookingAtPath];
    
    NSNumber *movieVolume = [NSNumber numberWithFloat:[self.player volume]];
    [metadata setObject:movieVolume forKey:CLDMetadataKeyVolume];
    
    NSNumber *movieMuted = [NSNumber numberWithBool:[self.player isMuted]];
    [metadata setObject:movieMuted forKey:CLDMetadataKeyMuted];
    
    [metadata setObject:self.freeSceneViewPovs forKey:CLDMetadataKeyViewPovs];
    
    NSNumber *viewLightState = [NSNumber numberWithBool:self.viewLightState];
    [metadata setObject:viewLightState forKey:CLDMetadataKeyViewLightState];
    
    NSNumber *viewLaughState = [NSNumber numberWithBool:self.viewLaughState];
    [metadata setObject:viewLaughState forKey:CLDMetadataKeyViewLaughState];
    
    NSNumber *viewBreathingBelt = [NSNumber numberWithBool:self.viewBreathingBelt];
    [metadata setObject:viewBreathingBelt forKey:CLDMetadataKeyViewBreathingBelt];
    
    NSNumber *viewShoreHappiness = [NSNumber numberWithBool:self.viewShoreHappiness];
    [metadata setObject:viewShoreHappiness forKey:CLDMetadataKeyViewShoreHappiness];
    
    NSNumber *viewGaze = [NSNumber numberWithBool:self.viewGaze];
    [metadata setObject:viewGaze forKey:CLDMetadataKeyViewGaze];

    NSNumber *viewLookingAt = [NSNumber numberWithBool:self.viewLookingAt];
    [metadata setObject:viewLookingAt forKey:CLDMetadataKeyViewLookingAt];
    
    metadataSuccess = [metadata writeToURL:metadataURL atomically:YES];
    
    // TASK: Scene
    NSLog(@"nodes out: %@", [self.scene.rootNode childNodes]);
    sceneSuccess = [self.scene writeToURL:sceneURL
                                  options:nil
                                 delegate:nil
                          progressHandler:^(float totalProgress, NSError *error, BOOL *stop)
        {
            NSLog(@"Writing scene progress: %f", totalProgress);
        }];
    
    return metadataSuccess && sceneSuccess;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    NSURL *metadataURL = [absoluteURL URLByAppendingPathComponent:CLDPackageMetadataFileName];
    BOOL metadataSuccess;
    
    NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfURL:metadataURL];
    metadataSuccess = (metadata != nil);
    if (metadataSuccess)
    {
        NSNumber *movieVolume = [metadata objectForKey:CLDMetadataKeyVolume];
        if (movieVolume) self.movieVolume = [movieVolume floatValue];
        
        NSNumber *movieMuted = [metadata objectForKey:CLDMetadataKeyMuted];
        if (movieMuted) self.movieMuted = [movieVolume boolValue];
        
        NSString *moviePath = [metadata objectForKey:CLDMetadataKeyMoviePath];
        if (moviePath) self.movieURL = [NSURL fileURLWithPath:moviePath];
        
        NSString *mocapPath = [metadata objectForKey:CLDMetadataKeyMocapPath];
        if (mocapPath) self.mocapURL = [NSURL fileURLWithPath:mocapPath];
        
        NSString *datasetPath = [metadata objectForKey:CLDMetadataKeyDatasetPath];
        if (datasetPath) self.datasetURL = [NSURL fileURLWithPath:datasetPath];

        NSString *lookingAtPath = [metadata objectForKey:CLDMetadataKeyLookingAtPath];
        if (lookingAtPath) self.lookingAtURL = [NSURL fileURLWithPath:lookingAtPath];
        
        NSNumber *viewLightState = [metadata objectForKey:CLDMetadataKeyViewLightState];
        if (viewLightState) self.viewLightState = [viewLightState boolValue];
        
        NSNumber *viewLaughState = [metadata objectForKey:CLDMetadataKeyViewLaughState];
        if (viewLaughState) self.viewLaughState = [viewLaughState boolValue];
        
        NSNumber *viewBreathingBelt = [metadata objectForKey:CLDMetadataKeyViewBreathingBelt];
        if (viewBreathingBelt) self.viewBreathingBelt = [viewBreathingBelt boolValue];
        
        NSNumber *viewShoreHappiness = [metadata objectForKey:CLDMetadataKeyViewShoreHappiness];
        if (viewShoreHappiness) self.viewShoreHappiness = [viewShoreHappiness boolValue];
        
        NSNumber *viewGaze = [metadata objectForKey:CLDMetadataKeyViewGaze];
        if (viewGaze) self.viewGaze = [viewGaze boolValue];

        NSNumber *viewLookingAt = [metadata objectForKey:CLDMetadataKeyViewLookingAt];
        if (viewLookingAt) self.viewLookingAt = [viewLookingAt boolValue];
        
        self.freeSceneViewPovs = [[metadata objectForKey:CLDMetadataKeyViewPovs] mutableCopy];
    }
    
    return metadataSuccess;
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

#pragma mark CALayoutManager Delegate

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
    // TASK: Fit the video to the top of the window and lay out two camera views of the 3D scene on top of their corresponding video regions, and put the freeview 3D scene in the remaining space below.
    if (layer == self.superLayer)
    {
        // Stop implicit animations
        NSTimeInterval cachedAnimationDuration = [[NSAnimationContext currentContext] duration];
        [[NSAnimationContext currentContext] setDuration:0];
        
        CGRect layerRect = self.superLayer.bounds;
        //NSLog(@"layerRect %f, %f, %f, %f", layerRect.origin.x, layerRect.origin.y, layerRect.size.width, layerRect.size.height);
        
        // We know video aspect is 2x16:9 = 32x9. This should be pulled from the video itself, but where's naturalSize on AVPlayerLayer? The computed videoRect would make things get a bit circular.
        CGFloat videoAspect = 32.0/9.0;
        
        CGFloat videoFittedWidth = layerRect.size.width;
        CGFloat videoFittedHeight = videoFittedWidth/videoAspect;
        CGFloat videoTopAlign = layerRect.origin.y + layerRect.size.height - videoFittedHeight;
        CGRect videoRect = CGRectMake(layerRect.origin.x, videoTopAlign, videoFittedWidth, videoFittedHeight);
        
        CGRect audienceRect = CGRectMake(videoRect.origin.x + videoRect.size.width/2.0, videoRect.origin.y, videoRect.size.width/2.0, videoRect.size.height);
        CGRect performerRect = CGRectMake(videoRect.origin.x, videoRect.origin.y, videoRect.size.width/2.0, videoRect.size.height);
        
        [self.playerLayer setFrame:videoRect];
        [self.playerBlurLayer setFrame:audienceRect];
        [self.playerMaskLayer setFrame:audienceRect];
        [self.audienceSceneLayer setFrame:audienceRect];
        [self.performerSceneLayer setFrame:performerRect];
        
        // This is a view not layer, but no-need to reinvent the wheel...
        CGFloat controlsHeight = 23;
        CGRect controlsRect = CGRectMake(layerRect.origin.x, layerRect.origin.y, layerRect.size.width, controlsHeight);
        CGRect freeRect = CGRectMake(layerRect.origin.x, layerRect.origin.y + controlsHeight, layerRect.size.width, layerRect.size.height - videoRect.size.height);
        
        [self.playerView setFrame:controlsRect];
        [self.freeSceneView setFrame:freeRect];
        
        
        // Revert to implicit animations
        [[NSAnimationContext currentContext] setDuration:cachedAnimationDuration];
    }
}

@end
