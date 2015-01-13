//
//  CLDScene.h
//  Comedy Lab Dataset Viewer
//
//  Created by Toby Harris | http://tobyz.net on 14/05/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import <SceneKit/SceneKit.h>

@interface SCNNode (ComedyLabAdditions)

+ (instancetype) arrow;
+ (instancetype) axes;

@end

@interface SCNScene (ComedyLabAdditions)

+ (instancetype)comedyLabScene;

- (BOOL)addWithMocapURL:(NSURL *)url error:(NSError **)error;

- (BOOL)addWithDatasetURL:(NSURL *)url error:(NSError **)error;

- (void) setCameraNodePosition:(SCNNode *)cameraNode withData:(NSData *)data;

- (NSData *)positionDataWithCameraNode:(SCNNode *)cameraNode;

- (NSArray *)standardCameraPositions;

- (NSArray *)personNodes;

@end
