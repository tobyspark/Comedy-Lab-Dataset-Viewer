//
//  CLDView.m
//  Comedy Lab Dataset Viewer
//
//  Created by TBZ.PhD on 12/06/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import "CLDView.h"

@implementation CLDView

-(IBAction)moveDown:(id)sender
{
    SCNVector3 steppedPos = SCNVector3Make(self.nodeToMove.position.x - 100,
                                           self.nodeToMove.position.y,
                                           self.nodeToMove.position.z);
    
    self.nodeToMove.position = steppedPos;
    NSLog(@"%f, %f, %f", self.nodeToMove.position.x, self.nodeToMove.position.y, self.nodeToMove.position.z);
}

-(IBAction)moveUp:(id)sender
{
    SCNVector3 steppedPos = SCNVector3Make(self.nodeToMove.position.x + 100,
                                           self.nodeToMove.position.y,
                                           self.nodeToMove.position.z);
    
    self.nodeToMove.position = steppedPos;
    NSLog(@"%f, %f, %f", self.nodeToMove.position.x, self.nodeToMove.position.y, self.nodeToMove.position.z);
}

-(IBAction)moveLeft:(id)sender
{
    SCNVector3 steppedPos = SCNVector3Make(self.nodeToMove.position.x,
                                           self.nodeToMove.position.y,
                                           self.nodeToMove.position.z  - 100);
    
    self.nodeToMove.position = steppedPos;
    NSLog(@"%f, %f, %f", self.nodeToMove.position.x, self.nodeToMove.position.y, self.nodeToMove.position.z);
}

-(IBAction)moveRight:(id)sender
{
    SCNVector3 steppedPos = SCNVector3Make(self.nodeToMove.position.x,
                                           self.nodeToMove.position.y,
                                           self.nodeToMove.position.z  + 100);
    self.nodeToMove.position = steppedPos;
    NSLog(@"%f, %f, %f", self.nodeToMove.position.x, self.nodeToMove.position.y, self.nodeToMove.position.z);
}

@end
