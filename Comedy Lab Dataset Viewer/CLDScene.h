//
//  CLDScene.h
//  Comedy Lab Dataset Viewer
//
//  Created by Toby Harris | http://tobyz.net on 14/05/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import <SceneKit/SceneKit.h>

@interface CLDScene : SCNScene
@property NSTimeInterval startTime;
@property NSTimeInterval finishTime;

+ (SCNNode *) arrow;

+ (instancetype)sceneWithComedyLabMocapURL:(NSURL *)url error:(NSError **)error;

@end
