//
//  CLDView.m
//  Comedy Lab Dataset Viewer
//
//  Created by TBZ.PhD on 12/06/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import "CLDView.h"
#import <GLKit/GLKit.h>

#define kCLDCameraNodeName @"Camera-Audience"
#define kCLDSubjectNodeName @"Audience_01"

@implementation CLDView

#pragma mark Key handlers - Subject gaze

-(IBAction)moveDown:(id)sender
{
    [self nudgeSubjectNodeAroundZ:0 aroundX:-1];
}

-(IBAction)moveUp:(id)sender
{
    [self nudgeSubjectNodeAroundZ:0 aroundX:1];
}

-(IBAction)moveLeft:(id)sender
{
    [self nudgeSubjectNodeAroundZ:-1 aroundX:0];
}

-(IBAction)moveRight:(id)sender
{
    [self nudgeSubjectNodeAroundZ:1 aroundX:0];
}

#pragma mark Key handlers - Config

-(void)keyDown:(NSEvent *)theEvent
{
    // Set our nodes to manipulate
    if (!self.cameraNode)
    {
        [self setCameraNode:[[self.scene rootNode] childNodeWithName:kCLDCameraNodeName recursively:NO]];
    }
    if (!self.subjectNode)
    {
        NSArray *audienceNodes = [[self.scene rootNode] childNodesPassingTest:^BOOL(SCNNode *child, BOOL *stop) {
            // Each audience is two nodes, one with arrow child node and one just as guide line.
            return ([[child name] hasPrefix:@"Audience"] && [[child childNodes] count] > 0);
        }];
        
        NSMutableArray* subjectNodeDicts = [NSMutableArray arrayWithCapacity:[audienceNodes count] + 1];
        for (SCNNode* node in audienceNodes)
        {
            [subjectNodeDicts addObject:[@{@"node": node, @"zRot": @0, @"xRot": @0} mutableCopy]];
        }
        [subjectNodeDicts addObject:[@{@"node": [[self.scene rootNode] childNodeWithName:@"Performer" recursively:NO], @"zRot": @0, @"xRot": @0} mutableCopy]];
        
        [self setSubjectNodes:[subjectNodeDicts copy]];
        [self setSubjectNode:self.subjectNodes[0][@"node"]];
    }
    
    if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"/"])
    {
        NSUInteger i = [[self.subjectNodes valueForKey:@"node"] indexOfObject:self.subjectNode];
        i++;
        if (i >= [self.subjectNodes count]) i = 0;
        [self setSubjectNode:self.subjectNodes[i][@"node"]];
        NSLog(@"subjectNode: %@", [self.subjectNode name]);
    }
    
    // set offsets for perf3, 15m00
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@","])
    {
        NSUInteger i = 0;
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:86 aroundX:6];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:213 aroundX:-23];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:169 aroundX:-7];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:98 aroundX:8];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:-95 aroundX:-47];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:89 aroundX:-3];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:111 aroundX:4];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:-85 aroundX:106];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:-9 aroundX:2];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:-20 aroundX:-8];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:29 aroundX:14];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:-34 aroundX:-45];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:-49 aroundX:-6];
    }
    
    // Log out subject gaze with space. These are offsets as per ComedyLab Vicon Exporter
    
    else if (!([theEvent modifierFlags] & NSAlternateKeyMask) && [[theEvent charactersIgnoringModifiers] isEqualTo:@" "])
    {
        // Get align info out of app and back into MatLab Vicon Exporter.
        // We have rotation as axis-angle and need rotation matrix.
        // Easiest way is to use MatLab's vrrotvec2mat function rather than convert here
        // So this, alas, writes some MatLab code to the console.
        NSLog(@"%% Time %.01f for %@", [self currentTime], [[[self.subjectNodes valueForKey:@"node"] valueForKey:@"name"] componentsJoinedByString:@", "]);
        for (NSUInteger i = 0; i < [self.subjectNodes count]; ++i)
        {
            SCNNode* node = self.subjectNodes[i][@"node"];
            SCNVector4 r = [[node childNodeWithName:@"arrowRotateOffset" recursively:YES] rotation];
            // m = vrrotvec2mat(r) returns a matrix representation of the rotation defined by the axis-angle rotation vector, r.
            // The rotation vector, r, is a row vector of four elements, where the first three elements specify the rotation axis, and the last element defines the angle.
            NSString *matlabLine = [NSString stringWithFormat:@"offsets{%lu} = vrrotvec2mat([%f, %f, %f, %f])", (unsigned long)i+1, r.x, r.y, r.z, r.w];
            printf("%s\n", [matlabLine cStringUsingEncoding:NSASCIIStringEncoding]);
            
            /*
             CATransform3D t = node.transform;
             NSLog(@"%@ at %.01f = [%f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f]",
             [node name], [self currentTime],
             t.m11, t.m12, t.m13, t.m14,
             t.m21, t.m22, t.m23, t.m24,
             t.m31, t.m32, t.m33, t.m34,
             t.m41, t.m42, t.m43, t.m44);
             */
        }
    }
    
    #pragma mark Key handlers - Camera registration
    
    // Rotate with alt-numpad as arrows
    else if (([theEvent modifierFlags] & NSAlternateKeyMask) && [[theEvent charactersIgnoringModifiers] isEqualToString:@"4"])
    {
        [self nudgeCameraNodeAroundZ:-1 aroundY:0 aroundX:0];
    }
    else if (([theEvent modifierFlags] & NSAlternateKeyMask) && [[theEvent charactersIgnoringModifiers] isEqualToString:@"6"])
    {
        [self nudgeCameraNodeAroundZ:1 aroundY:0 aroundX:0];
    }
    else if (([theEvent modifierFlags] & NSAlternateKeyMask) && [[theEvent charactersIgnoringModifiers] isEqualToString:@"2"])
    {
        [self nudgeCameraNodeAroundZ:0 aroundY:0 aroundX:1];
    }
    else if (([theEvent modifierFlags] & NSAlternateKeyMask) && [[theEvent charactersIgnoringModifiers] isEqualToString:@"8"])
    {
        [self nudgeCameraNodeAroundZ:0 aroundY:0 aroundX:-1];
    }
    else if (([theEvent modifierFlags] & NSAlternateKeyMask) && [[theEvent charactersIgnoringModifiers] isEqualToString:@"0"])
    {
        [self nudgeCameraNodeAroundZ:0 aroundY:-1 aroundX:0];
    }
    else if (([theEvent modifierFlags] & NSAlternateKeyMask) && [[theEvent charactersIgnoringModifiers] isEqualToString:@"5"])
    {
        [self nudgeCameraNodeAroundZ:0 aroundY:1 aroundX:0];
    }
    // Position with numpad as arrows
    else if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"4"])
    {
        [self nudgeCameraNodeAlongX:0 alongY:-100 alongZ:0];
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"6"])
    {
        [self nudgeCameraNodeAlongX:0 alongY:100 alongZ:0];
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"2"])
    {
        [self nudgeCameraNodeAlongX:100 alongY:0 alongZ:0];
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"8"])
    {
        [self nudgeCameraNodeAlongX:-100 alongY:0 alongZ:0];
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"0"])
    {
        [self nudgeCameraNodeAlongX:0 alongY:0 alongZ:100];
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"5"])
    {
        [self nudgeCameraNodeAlongX:0 alongY:0 alongZ:-100];
    }
    // Field of view with numpad 7,9
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"7"])
    {
        [self nudgeCameraFocalLength:+1];
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"9"])
    {
        [self nudgeCameraFocalLength:-1];
    }
    // Log camera parameters with alt-space
    else if (([theEvent modifierFlags] & NSAlternateKeyMask) && [[theEvent charactersIgnoringModifiers] isEqualTo:@" "])
    {
        NSLog(@"Camera: %@", [self.cameraNode name]);
        // Log via calling nudge methods with no nudge amount
        [self nudgeCameraFocalLength:0];
        [self nudgeCameraNodeAlongX:0 alongY:0 alongZ:0];
        [self nudgeCameraNodeAroundZ:0 aroundY:0 aroundX:0];
    }
    
#pragma mark Key handlers - temporal sync
    
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"-"])
    {
        self.timeOffset -= 0.1;
        
        NSLog(@"timeOffset: %f", self.timeOffset);
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"+"] || [[theEvent charactersIgnoringModifiers] isEqualTo:@"="])
    {
        self.timeOffset += 0.1;
        NSLog(@"timeOffset: %f", self.timeOffset);
    }
    
    // Pass onto 'moveUp/Down/Left/Right' methods
    else
    {
        [self interpretKeyEvents:@[theEvent]];
    }
}

# pragma mark Nudge methods

- (void)nudgeSubjectNodeAroundZ:(CGFloat)dz aroundX:(CGFloat)dx
{
    // Rotate in this order makes most sense for setting gaze
    
    NSUInteger i = [[self.subjectNodes valueForKey:@"node"] indexOfObject:self.subjectNode];
    
    // We have to apply the static offset rotation after applying the animated rotation
    SCNNode *node = [self.subjectNode childNodeWithName:@"arrowRotateOffset" recursively:YES];
    
    CGFloat z = [self.subjectNodes[i][@"zRot"] doubleValue];
    CGFloat x = [self.subjectNodes[i][@"xRot"] doubleValue];
    
    z += dz;
    x += dx;
    
    CATransform3D transform = CATransform3DMakeRotation(GLKMathDegreesToRadians(z), 0, 0, 1);
    transform = CATransform3DRotate(transform, GLKMathDegreesToRadians(x), 1, 0, 0);
    
    [node setTransform:transform];
    
    self.subjectNodes[i][@"zRot"] = @(z);
    self.subjectNodes[i][@"xRot"] = @(x);
    
    NSLog(@"Subject %@ xRot: %f zRot: %f", [self.subjectNode name], x, z);
}

- (void)nudgeCameraNodeAroundZ:(CGFloat)dz aroundY:(CGFloat)dy aroundX:(CGFloat)dx
{
    // Rotate in this order makes most sense for setting camera
    
    static CGFloat z = -90;
    static CGFloat y = 0;
    static CGFloat x = 60;
    
    x += dx;
    z += dz;
    y += dy;
    
    // Store position and set to zero position for rotation
    SCNVector3 pos = self.cameraNode.position;
    self.cameraNode.position = SCNVector3Make(0, 0, 0);
    
    CATransform3D transform = CATransform3DMakeRotation(GLKMathDegreesToRadians(z), 0, 0, 1);
    transform = CATransform3DRotate(transform, GLKMathDegreesToRadians(y), 0, 1, 0);
    transform = CATransform3DRotate(transform, GLKMathDegreesToRadians(x), 1, 0, 0);
    
    self.cameraNode.transform = transform;
    
    // Restore position
    self.cameraNode.position = pos;
    
    NSLog(@"Rotation: %f, %f, %f", x, y, z);
}

- (void)nudgeCameraNodeAlongX:(CGFloat)dx alongY:(CGFloat)dy alongZ:(CGFloat)dz
{
    SCNVector3 steppedPos = SCNVector3Make(self.cameraNode.position.x + dx,
                                           self.cameraNode.position.y + dy,
                                           self.cameraNode.position.z + dz);

    self.cameraNode.position = steppedPos;
    NSLog(@"Position: %f, %f, %f", self.cameraNode.position.x, self.cameraNode.position.y, self.cameraNode.position.z);
}

- (void)nudgeCameraFocalLength:(CGFloat)df
{
    double focalLength = (180*35 / self.cameraNode.camera.xFov) / M_PI;
    focalLength += df;
    self.cameraNode.camera.xFov = (180.0*35.0) / (M_PI*focalLength);
    NSLog(@"Focal length: %f", focalLength);
}

@end
