//
//  CLDView.h
//  Comedy Lab Dataset Viewer
//
//  Created by TBZ.PhD on 12/06/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>

@interface CLDView : SCNView

- (void) setPovOrtho;
- (void) setPovWithPersonNode:(SCNNode *)person;

#ifdef DEBUG
@property (weak) SCNNode *cameraNode;
@property (weak) SCNNode *subjectNode;
@property (strong) NSArray *subjectNodes;
@property NSTimeInterval timeOffset;
#endif

@end
