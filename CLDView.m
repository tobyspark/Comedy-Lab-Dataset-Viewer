//
//  CLDView.m
//  Comedy Lab Dataset Viewer
//
//  Created by TBZ.PhD on 12/06/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import "CLDView.h"
#import <GLKit/GLKit.h>

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

-(void)keyDown:(NSEvent *)theEvent
{
    static float cameraAngle = 55;
    
    if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"a"])
    {
        double focalLength = (180*35 / self.nodeToMove.camera.xFov) / M_PI;
        focalLength += 1;
        self.nodeToMove.camera.xFov = (180.0*35.0) / (M_PI*focalLength);
        NSLog(@"%f", focalLength);
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"z"])
    {
        double focalLength = (180*35 / self.nodeToMove.camera.xFov) / M_PI;
        focalLength -= 1;
        self.nodeToMove.camera.xFov = (180.0*35.0) / (M_PI*focalLength);
        NSLog(@"%f", focalLength);
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"s"])
    {
        cameraAngle += 1;
        
        SCNVector3 pos = self.nodeToMove.position;
        self.nodeToMove.position = SCNVector3Make(0, 0, 0);
        
        CATransform3D cameraOrientation = CATransform3DMakeRotation(GLKMathDegreesToRadians(-90), 0, 0, 1);
        cameraOrientation = CATransform3DRotate(cameraOrientation, GLKMathDegreesToRadians(cameraAngle), 1, 0, 0);
        self.nodeToMove.transform = cameraOrientation;
        self.nodeToMove.position = pos;
        
        NSLog(@"%f", cameraAngle);
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"x"])
    {
        cameraAngle -= 1;
        
        SCNVector3 pos = self.nodeToMove.position;
        self.nodeToMove.position = SCNVector3Make(0, 0, 0);
        
        CATransform3D cameraOrientation = CATransform3DMakeRotation(GLKMathDegreesToRadians(-90), 0, 0, 1);
        cameraOrientation = CATransform3DRotate(cameraOrientation, GLKMathDegreesToRadians(cameraAngle), 1, 0, 0);
        self.nodeToMove.transform = cameraOrientation;
        self.nodeToMove.position = pos;
        
        NSLog(@"%f", cameraAngle);
    }
    else
    {
        [self interpretKeyEvents:@[theEvent]];
    }
}

@end
