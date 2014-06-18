//
//  TBZDocument.m
//  Comedy Lab Dataset Viewer
//
//  Created by Toby Harris | http://tobyz.net on 13/05/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import "CLDDocument.h"

static NSString * const CLDSceneFileName = @"Scene.dae";
static NSString * const CLDMetadataFileName = @"Metadata.plist";
static NSString * const CLDMetadataKeyMoviePath = @"moviePath";
static NSString * const CLDMetadataKeyMocapPath = @"mocapPath";
static NSString * const CLDMetadataKeyDatasetPath = @"datasetPath";
static NSString * const CLDMetadataKeyViewPovs = @"freeViewPOVs";
static NSString * const CLDMetadataKeyVolume = @"volume";
static NSString * const CLDMetadataKeyMuted = @"muted";

@interface CLDDocument ()

@property (strong, nonatomic) SCNScene *scene;

@property (weak)   CALayer          *superLayer;
@property (strong) AVPlayer         *player;
@property (strong) AVPlayerView     *playerView;
@property (strong) AVPlayerLayer    *playerLayer;
@property (strong) CALayer          *playerMaskLayer;
@property (strong) SCNLayer         *audienceSceneLayer;
@property (strong) SCNLayer         *performerSceneLayer;
@property (strong) SCNView          *freeSceneView;

@property (strong) NSMutableArray* freeSceneViewPovs;

@end

@implementation CLDDocument

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        
        _freeSceneViewPovs = [NSMutableArray arrayWithCapacity:10];
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
    
    [self setSuperLayer:[aController.window.contentView layer]];
    
    // Set delegate so we can handle laying out sublayers, and do the views while we're at it
    [self.superLayer setDelegate:self];
    
    // TASK: Setup views
    
    // Use AVPlayerView rather than AVPlayerLayer as this gives us UI
    [self setPlayerView:[[AVPlayerView alloc] initWithFrame:aController.window.frame]];
    [self.playerView setControlsStyle:AVPlayerViewControlsStyleInline];
    [self.playerView setPlayer:self.player];
    
    [aController.window.contentView addSubview:self.playerView];
    
    // Use SCNView rather than layer as this gives us UI, and we can now keep in sync using AVPlayer's periodicTimeObserver rather than the broken elegance of AVSyncronizedLayer
    [self setFreeSceneView:[[SCNView alloc] initWithFrame:aController.window.frame]];
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

    [self setPlayerMaskLayer:[CALayer layer]];
    [self.playerMaskLayer setBackgroundColor:CGColorCreateGenericGray(0, 1)];
    [self.playerMaskLayer setOpacity:0];
    
    // TASK: Set layers into tree
    
    [self.superLayer addSublayer:self.playerLayer];
    [self.superLayer addSublayer:self.playerMaskLayer];
    [self.superLayer addSublayer:self.audienceSceneLayer];
    [self.superLayer addSublayer:self.performerSceneLayer];
    
    // TASK: Set view menu
    NSMenu *viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    [viewMenu setDelegate:self];
    
    // TASK: Get going for user
    self.scene = [SCNScene comedyLabScene];
    [self performSelectorInBackground:@selector(loadMocap) withObject:nil];
    [self performSelectorInBackground:@selector(loadDataset) withObject:nil];
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
    
    AVPlayer *player = [AVPlayer playerWithURL:self.movieURL];
    if (player)
    {
        // AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions), see early commits
        // So we use this instead, which also allows us to make freeScene a SCNView with it's built-in camera UI.
        [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.1, 600) queue:NULL usingBlock:^(CMTime time) {
            NSTimeInterval timeSecs = CMTimeGetSeconds(time);
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
        
        NSLog(@"Loaded movie: %@", self.movieURL);
    }
    else
    {
        NSLog(@"Failed to load movie: %@", self.movieURL);
    }
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
    
    CLDView *superview = (CLDView*)[self.freeSceneView superview];
    [superview setNodeToMove:[scene.rootNode childNodeWithName:@"Camera-Audience" recursively:NO]];
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
        [self.scene addWithMocapURL:self.mocapURL error:nil];
        [self movieSeekToSceneStart];
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
        [self.scene addWithDatasetURL:self.datasetURL error:nil];
        [self movieSeekToSceneStart];
    }
}

- (IBAction) freeSceneViewAddCurrentPov:(id)sender
{
    // TASK: Capture current point-of-view and set menu item for it's recall
    
    CATransform3D transform = self.freeSceneView.pointOfView.transform;
    NSData *povData = [NSData dataWithBytes:&transform length:sizeof(CATransform3D)];
    
    [self.freeSceneViewPovs addObject:povData];
}

- (IBAction) freeSceneViewSetCurrentPov:(id)sender
{
    // TASK: Recall previously captured point of view
    
    NSMenu *viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    
    // 0 = Add menuitem
    // 1 = captured POV, array index 0
    NSUInteger povIndexToRecall = [viewMenu indexOfItem:sender] - 1;
    
    // Use NSData as [NSValue CATransform3DValue] can't be archived by NSDictionary or NSKeyedArchiver
    NSData *recalledPovData = [self.freeSceneViewPovs objectAtIndex:povIndexToRecall];
    CATransform3D recalledTransform;
    [recalledPovData getBytes:&recalledTransform length:sizeof(CATransform3D)];
    
    CABasicAnimation *povAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    povAnimation.fromValue = [NSValue valueWithCATransform3D:self.freeSceneView.pointOfView.transform];
    povAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    povAnimation.duration = 1.0;
    
    [self.freeSceneView.pointOfView setTransform:recalledTransform];
    [self.freeSceneView.pointOfView addAnimation:povAnimation forKey:nil];
}

- (IBAction) toggleAudienceMask:(id)sender
{
    if ([sender state] == NSOnState)
    {
        [self.playerMaskLayer setOpacity:0];
    }
    else
    {
        [self.playerMaskLayer setOpacity:1];
    }
}

#pragma mark - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu
{
    // CLDDocument is delegate only for the view menu
    NSMenu *viewMenu = menu;
    
    [[viewMenu itemWithTitle:@"Hide audience"] setState:self.playerMaskLayer.opacity == 1.0 ? NSOnState : NSOffState];
    
    NSUInteger startIndexForPovs = 3;
    NSUInteger povsCount = [self.freeSceneViewPovs count];
    NSUInteger menuitemsCount = [[viewMenu itemArray] count] - startIndexForPovs;
    
    while (povsCount < menuitemsCount)
    {
        [viewMenu removeItemAtIndex:menuitemsCount];
        menuitemsCount--;
    }
    
    while (povsCount > menuitemsCount)
    {
        NSString *povString = [NSString stringWithFormat:@"Camera Pos %lu", (unsigned long)menuitemsCount + startIndexForPovs];
        NSString *povKey = [NSString stringWithFormat:@"%lu", (unsigned long)menuitemsCount + startIndexForPovs];
        
        NSMenuItem *newPovMenuItem = [[NSMenuItem alloc] initWithTitle:povString action:@selector(freeSceneViewSetCurrentPov:) keyEquivalent:povKey];
        
        [viewMenu addItem:newPovMenuItem];
        menuitemsCount++;
    }
}

#pragma mark - Package Support

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    NSURL *sceneURL = [absoluteURL URLByAppendingPathComponent:CLDSceneFileName];
    NSURL *metadataURL = [absoluteURL URLByAppendingPathComponent:CLDMetadataFileName];
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
    
    NSNumber *movieVolume = [NSNumber numberWithFloat:[self.player volume]];
    [metadata setObject:movieVolume forKey:CLDMetadataKeyVolume];
    
    NSNumber *movieMuted = [NSNumber numberWithBool:[self.player isMuted]];
    [metadata setObject:movieMuted forKey:CLDMetadataKeyMuted];
    
    [metadata setObject:self.freeSceneViewPovs forKey:CLDMetadataKeyViewPovs];
    
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
    NSURL *metadataURL = [absoluteURL URLByAppendingPathComponent:CLDMetadataFileName];
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
        
        self.freeSceneViewPovs = [metadata objectForKey:CLDMetadataKeyViewPovs];
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
