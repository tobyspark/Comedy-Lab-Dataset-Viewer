//
//  CLDView.h
//  Comedy Lab Dataset Viewer
//
//  Created by TBZ.PhD on 12/06/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>

@interface CLDView : NSView
@property (weak) SCNNode *nodeToMove;
@end