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
@property (strong) AVPlayerLayer    *playerLayer;
@property (strong) SCNLayer         *audienceSceneLayer;
@property (strong) SCNLayer         *performerSceneLayer;
@property (strong) SCNLayer         *freeSceneLayer;

@property (strong) SCNScene*        scene;

@end

@implementation CLDDocument

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
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
    
    // TASK: Setup container layer and sync layer
    // Set delegate so we can handle laying out sublayers
    
    [aController.window.contentView setWantsLayer:YES];
    
    self.superLayer = [aController.window.contentView layer];
    self.superLayer.delegate = self;
    AVSynchronizedLayer *syncLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:player.currentItem];
    
    // TASK: Get our 3D scene
    // Generate from CSV exported from Vicon in first instance
    // The scene could then be saved and loaded from a file bundle
    
    NSURL *csvURL = [NSURL fileURLWithPath:@"/Users/Shared/ComedyLab/Data - Raw/Motion Capture/TUESDAY 3pm 123.csv"];
    [self setScene:[CLDScene sceneWithComedyLabMocapURL:csvURL error:nil]];
    
    // TASK: Setup individual layers
    
    [self setPlayerLayer:[AVPlayerLayer playerLayerWithPlayer:player]];
    
    [self setAudienceSceneLayer:[SCNLayer layer]];
    [self.audienceSceneLayer setScene:self.scene];
    [self.audienceSceneLayer setPointOfView:[self.scene.rootNode childNodeWithName:@"Camera - Audience" recursively:NO]];
    [self.audienceSceneLayer setAutoenablesDefaultLighting:YES];
    
    [self setPerformerSceneLayer:[SCNLayer layer]];
    [self.performerSceneLayer setScene:self.scene];
    [self.performerSceneLayer setPointOfView:[self.scene.rootNode childNodeWithName:@"Camera - Performer" recursively:NO]];
    [self.performerSceneLayer setAutoenablesDefaultLighting:YES];
    
    [self setFreeSceneLayer:[SCNLayer layer]];
    [self.freeSceneLayer setScene:self.scene];
    [self.freeSceneLayer setPointOfView:[self.scene.rootNode childNodeWithName:@"Camera - Orthographic" recursively:NO]];
    [self.freeSceneLayer setAutoenablesDefaultLighting:YES];
    
    // TASK: Set layers into tree
    
    // FIXME: WHYBUGGERMAN I can't get AVPlayer and CAAnimation (SceneKitAdditions) to sync via AVSynchronizedLayer
    [syncLayer addSublayer:self.audienceSceneLayer];
    [syncLayer addSublayer:self.performerSceneLayer];
    [syncLayer addSublayer:self.freeSceneLayer];
    [self.superLayer addSublayer:self.playerLayer];
    [self.superLayer addSublayer:syncLayer];
    
    [self.debugView setScene:self.scene];
    [self.debugView setShowsStatistics:YES];
    
    [player setMuted:YES]; // for development sanity
    [player seekToTime:CMTimeMakeWithSeconds(464, 600)];
    [player play];
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
        CGRect layerRect = self.superLayer.bounds;
        //NSLog(@"layerRect %f, %f, %f, %f", layerRect.origin.x, layerRect.origin.y, layerRect.size.width, layerRect.size.height);
        
        // We know video aspect is 2x16:9 = 32x9. This should be pulled from the video itself, but where's naturalSize on AVPlayerLayer? The computed videoRect would make things get a bit circular.
        CGFloat videoAspect = 32.0/9.0;
        
        CGFloat videoFittedWidth = layerRect.size.width;
        CGFloat videoFittedHeight = videoFittedWidth/videoAspect;
        CGFloat videoTopAlign = layerRect.origin.y + layerRect.size.height - videoFittedHeight;
        CGRect videoRect = CGRectMake(layerRect.origin.x, videoTopAlign, videoFittedWidth, videoFittedHeight);
        
        [self.playerLayer setFrame:videoRect];
        
        CGRect audienceRect = CGRectMake(videoRect.origin.x + videoRect.size.width/2.0, videoRect.origin.y, videoRect.size.width/2.0, videoRect.size.height);
        [self.audienceSceneLayer setFrame:audienceRect];
        
        CGRect performerRect = CGRectMake(videoRect.origin.x, videoRect.origin.y, videoRect.size.width/2.0, videoRect.size.height);
        [self.performerSceneLayer setFrame:performerRect];
        
        CGRect freeRect = CGRectMake(layerRect.origin.x, layerRect.origin.y, layerRect.size.width, layerRect.size.height - videoRect.size.height);
        [self.freeSceneLayer setFrame:freeRect];
    }
}

@end
