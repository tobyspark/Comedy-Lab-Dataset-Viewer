//
//  TBZDocument.m
//  Comedy Lab Dataset Viewer
//
//  Created by Toby Harris | http://tobyz.net on 13/05/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import "CLDDocument.h"
#import "CLDScene.h"

@interface CLDDocument ()

@property (weak)   CALayer          *superLayer;
@property (strong) AVPlayerView     *playerView;
@property (strong) SCNLayer         *audienceSceneLayer;
@property (strong) SCNLayer         *performerSceneLayer;
@property (strong) SCNView          *freeSceneView;

@property (strong) CLDScene*        scene;

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
    
    // TASK: Setup Video Playback
    // Do this before making layers so we can use it as source in them and sync between them
    
    NSURL *movieURL = [NSURL fileURLWithPath:@"/Users/Shared/ComedyLab/Data - Raw/Video/Performance 1 3pm Live 720P.mov"];
    AVPlayer *player = [AVPlayer playerWithURL: movieURL];
    
    // TASK: Get our 3D scene
    // Generate from CSV exported from Vicon in first instance
    // The scene could then be saved and loaded from a file bundle
    
    NSURL *csvURL = [NSURL fileURLWithPath:@"/Users/Shared/ComedyLab/Data - Raw/Motion Capture/TUESDAY 3pm 123.csv"];
    [self setScene:[CLDScene sceneWithComedyLabMocapURL:csvURL error:nil]];
    
    // TASK: Create Views and Layers
    
    [aController.window.contentView setWantsLayer:YES];
    
    [self setSuperLayer:[aController.window.contentView layer]];
    
    // Set delegate so we can handle laying out sublayers, and do the views while we're at it
    [self.superLayer setDelegate:self];
    
    // TASK: Setup views
    
    // Use AVPlayerView rather than AVPlayerLayer as this gives us UI
    [self setPlayerView:[[AVPlayerView alloc] initWithFrame:aController.window.frame]];
    [self.playerView setPlayer:player];
    [self.playerView setControlsStyle:AVPlayerViewControlsStyleInline];
    
    [aController.window.contentView addSubview:self.playerView];
    
    // Use SCNView rather than layer as this gives us UI, and we can now keep in sync using AVPlayer's periodicTimeObserver rather than the broken elegance of AVSyncronizedLayer
    [self setFreeSceneView:[[SCNView alloc] initWithFrame:aController.window.frame]];
    [self.freeSceneView setScene:self.scene];
    [self.freeSceneView setPointOfView:[self.scene.rootNode childNodeWithName:@"Camera - Orthographic" recursively:NO]];
    [self.freeSceneView setAutoenablesDefaultLighting:YES];
    [self.freeSceneView setAllowsCameraControl:YES];
    
    [aController.window.contentView addSubview:self.freeSceneView];
    
    // TASK: Setup individual layers
    
    [self setAudienceSceneLayer:[SCNLayer layer]];
    [self.audienceSceneLayer setScene:self.scene];
    [self.audienceSceneLayer setPointOfView:[self.scene.rootNode childNodeWithName:@"Camera - Audience" recursively:NO]];
    [self.audienceSceneLayer setAutoenablesDefaultLighting:YES];
    
    [self setPerformerSceneLayer:[SCNLayer layer]];
    [self.performerSceneLayer setScene:self.scene];
    [self.performerSceneLayer setPointOfView:[self.scene.rootNode childNodeWithName:@"Camera - Performer" recursively:NO]];
    [self.performerSceneLayer setAutoenablesDefaultLighting:YES];

    // TASK: Set layers into tree
    
    [self.superLayer addSublayer:self.audienceSceneLayer];
    [self.superLayer addSublayer:self.performerSceneLayer];
    
    // AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions), see early commits
    // So we use this instead, which also allows us to make freeScene a SCNView with it's built-in camera UI.
    [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.1, 600) queue:NULL usingBlock:^(CMTime time) {
        NSTimeInterval timeSecs = CMTimeGetSeconds(time);
        [self.audienceSceneLayer setCurrentTime:timeSecs];
        [self.performerSceneLayer setCurrentTime:timeSecs];
        [self.freeSceneView setCurrentTime:timeSecs];
    }];
    
    
    [player setMuted:YES]; // for development sanity
    [player seekToTime:CMTimeMakeWithSeconds([self.scene startTime], 600)];
    [player play];
}

- (IBAction) freeSceneViewAddCurrentPov:(id)sender
{
    // TASK: Capture current point-of-view and set menu item for it's recall
    
    NSValue *povValue = [NSValue valueWithCATransform3D:self.freeSceneView.pointOfView.transform];
    
    [self.freeSceneViewPovs addObject:povValue];
    
    NSString *povString = [NSString stringWithFormat:@"Camera Pos %lu", (unsigned long)[self.freeSceneViewPovs count]];
    NSString *povKey = [NSString stringWithFormat:@"%lu", (unsigned long)[self.freeSceneViewPovs count]];
    
    NSMenuItem *newPovMenuItem = [[NSMenuItem alloc] initWithTitle:povString action:@selector(freeSceneViewSetCurrentPov:) keyEquivalent:povKey];
    
    NSMenu *viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    
    [viewMenu addItem:newPovMenuItem];
}

- (IBAction) freeSceneViewSetCurrentPov:(id)sender
{
    // TASK: Recall previously captured point of view
    
    NSMenu *viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    
    // 0 = Add menuitem
    // 1 = captured POV, array index 0
    NSUInteger povIndexToRecall = [viewMenu indexOfItem:sender] - 1;
    
    NSValue *recalledPovValue = [self.freeSceneViewPovs objectAtIndex:povIndexToRecall];
    
    CABasicAnimation *povAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    povAnimation.fromValue = [NSValue valueWithCATransform3D:self.freeSceneView.pointOfView.transform];
    povAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    povAnimation.duration = 1.0;
    
    [self.freeSceneView.pointOfView setTransform:[recalledPovValue CATransform3DValue]];
    [self.freeSceneView.pointOfView addAnimation:povAnimation forKey:nil];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
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
        
        // This is a view not layer, but no-need to reinvent the wheel since switching from AVPlayerLayer to AVPlayerView.
        [self.playerView setFrame:videoRect];
        
        CGRect audienceRect = CGRectMake(videoRect.origin.x + videoRect.size.width/2.0, videoRect.origin.y, videoRect.size.width/2.0, videoRect.size.height);
        [self.audienceSceneLayer setFrame:audienceRect];
        
        CGRect performerRect = CGRectMake(videoRect.origin.x, videoRect.origin.y, videoRect.size.width/2.0, videoRect.size.height);
        [self.performerSceneLayer setFrame:performerRect];
        
        // This is a view not layer, but no-need to reinvent the wheel...
        CGRect freeRect = CGRectMake(layerRect.origin.x, layerRect.origin.y, layerRect.size.width, layerRect.size.height - videoRect.size.height);
        [self.freeSceneView setFrame:freeRect];
        
        
        // Revert to implicit animations
        [[NSAnimationContext currentContext] setDuration:cachedAnimationDuration];
    }
}

@end
