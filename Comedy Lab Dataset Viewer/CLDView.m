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

- (void) setPovOrtho
{
    self.pointOfView = [self.scene.rootNode childNodeWithName:@"Camera-Orthographic" recursively:NO];
}

- (void) setPovWithPersonNode:(SCNNode *)person
{
    // Need to create a child of gaze node
    // - rotated such that -z (viewing axis) aligns with gaze +y (see [SCNNode Arrow])
    // - ~150mm below (hat peak -> eyelevel)
    
    SCNNode* camera = [person childNodeWithName:@"camera" recursively:YES];
    if (!camera)
    {
        camera = [SCNNode node];
        camera.name = @"camera";
        camera.position = SCNVector3Make(0, 0, -150);
        camera.rotation = SCNVector4Make(1, 0, 0, GLKMathDegreesToRadians(90));
        camera.camera = [SCNCamera camera];
        camera.camera.automaticallyAdjustsZRange = YES;
        [[person childNodeWithName:@"gaze" recursively:NO] addChildNode:camera];
    }
    
    self.pointOfView = camera;
    
    #ifdef DEBUG
    {
        SCNNode* test = [[self.scene rootNode] childNodeWithName:@"gazeTest" recursively:YES];
        if (test)
        {
            [test removeFromParentNode];
        }
    
        if (self.coneAngle < 1) self.coneAngle = 43;
        if (self.cylinderRadius < 1) self.cylinderRadius = 700;
    
        test = [SCNNode node];
        [test setName:@"gazeTest"];
    
        SCNNode* testGeomNode = [SCNNode node];
        [testGeomNode setName:@"gazeGeom"];
        [testGeomNode setPosition:SCNVector3Make(0, 3000, 0)];
        [test addChildNode:testGeomNode];
        [self updateGazeGeom];
        
        SCNLight *light = [SCNLight light];
        light.type = SCNLightTypeOmni;
        light.color = [NSColor colorWithWhite:0.5 alpha:1.0];
        [test setLight:light];
        
        [test setOpacity:0.9];
        [[person childNodeWithName:@"gaze" recursively:NO] addChildNode:test];
    }
    #endif
}

#ifdef DEBUG
- (void) updateGazeGeom
{
    SCNNode* test = [[self.scene rootNode] childNodeWithName:@"gazeGeom" recursively:YES];
    if (test)
    {
        if (self.isCone)
        {
            double viewAngle = GLKMathDegreesToRadians(self.coneAngle);
            [test setGeometry:[SCNCone coneWithTopRadius:tan(viewAngle/2) * 6000 bottomRadius:0 height:6000]];
        }
        else
        {
            [test setGeometry:[SCNTube tubeWithInnerRadius:self.cylinderRadius-1 outerRadius:self.cylinderRadius height:6000]];
        }
    }
}
#endif

// Only have tweakage when running in debug mode (ie. direct from Xcode).
#ifdef DEBUG

#pragma mark Key handlers - Subject gaze

-(IBAction)moveDown:(id)sender
{
    [self nudgeSubjectNodeAroundZ:0 aroundX:-1 aroundY:0];
}

-(IBAction)moveUp:(id)sender
{
    [self nudgeSubjectNodeAroundZ:0 aroundX:1 aroundY:0];
}

-(IBAction)moveLeft:(id)sender
{
    [self nudgeSubjectNodeAroundZ:-1 aroundX:0 aroundY:0];
}

-(IBAction)moveRight:(id)sender
{
    [self nudgeSubjectNodeAroundZ:1 aroundX:0 aroundY:0];
}

-(void)scrollPageUp:(id)sender
{
    [self nudgeSubjectNodeAroundZ:0 aroundX:0  aroundY:1];
}

-(void)scrollPageDown:(id)sender
{
    [self nudgeSubjectNodeAroundZ:0 aroundX:0  aroundY:-1];
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
        SCNNode *performerNode = [[self.scene rootNode] childNodeWithName:@"Performer" recursively:NO];
        if (performerNode)
        {
            [subjectNodeDicts addObject:[@{@"node": performerNode, @"zRot": @0, @"xRot": @0, @"yRot": @0} mutableCopy]];
        }
        
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
        [self nudgeSubjectNodeAroundZ:-78 aroundX:-19 aroundY:15];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:39 aroundX:-3 aroundY:11];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:7 aroundX:193 aroundY:8];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:-75 aroundX:6 aroundY:29];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:261 aroundX:-182 aroundY:10];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:-82 aroundX:2 aroundY:31];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:286 aroundX:5 aroundY:28];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:259 aroundX:-179 aroundY:8];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:178 aroundX:0 aroundY:-5];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:165 aroundX:-1 aroundY:7];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:135 aroundX:161 aroundY:4];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:151 aroundX:-2 aroundY:34];
        
        [self setSubjectNode:self.subjectNodes[i++][@"node"]];
        [self nudgeSubjectNodeAroundZ:-62 aroundX:9 aroundY:32];
    }
    
    // Log out subject gaze with space. These are offsets as per ComedyLab Vicon Exporter
    
    else if (!([theEvent modifierFlags] & NSAlternateKeyMask) && [[theEvent charactersIgnoringModifiers] isEqualTo:@" "])
    {
        // First, Log the time and offset as we have set them
        NSLog(@"%% Time %.01f for %@", [self currentTime], [[[self.subjectNodes valueForKey:@"node"] valueForKey:@"name"] componentsJoinedByString:@", "]);
        for (NSUInteger i = 0; i < [self.subjectNodes count]; ++i)
        {
            self.subjectNode = self.subjectNodes[i][@"node"];
            [self nudgeSubjectNodeAroundZ:0 aroundX:0 aroundY:0]; // Log
        }
        
        // Now write MATLAB code to console which will generate correct offsets from this viewer's modelling with SceneKit
        for (NSUInteger i = 0; i < [self.subjectNodes count]; ++i)
        {
            // Vicon Exporter calculates gaze vector as
            // gaze = [1 0 0] * rm * subjectOffsets{subjectIndex};
            // rm = Rotation matrix from World to Mocap = Rwm
            // subjectOffsets = rotation matrix from Mocap to Offset (ie Gaze) = Rmo
            
            // In this viewer, we model a hierarchy of
            // Origin Node -> Audience Node -> Mocap Node -> Offset Node, rendered as axes.
            // The Mocap node is rotated with Rmw (ie. rm') to comply with reality.
            // Aha. This is because in this viewer we are rotating the coordinate space not a point as per exporter
            
            // By manually rotating the offset node so it's axes register with the head pose in video, we should be able to export a rotation matrix
            // We need to get Rmo as rotation of point
            // Rmo as rotation of point = Rom as rotation of coordinate space
            
            // In this viewer, we have
            // Note i. these are rotations of coordinate space
            // Note ii. we're doing this by taking 3x3 rotation matrix out of 4x4 translation matrix
            // [mocapNode worldTransform] = Rwm
            // [offsetNode transform] = Rmo
            // [offsetNode worldTransform] = Rwo
            
            // We want Rom as rotation of coordinate space
            // Therefore Offset = Rom = Rmo' = [offsetNode transform]'
            
            // CATransform3D is however transposed from rotation matrix in MATLAB.
            // Therefore Offset = [offsetNode transform]
            
            SCNNode* node = self.subjectNodes[i][@"node"];
            SCNNode* mocapNode = [node childNodeWithName:@"mocap" recursively:YES];
            SCNNode* offsetNode = [mocapNode childNodeWithName:@"axes" recursively:YES];
            
            // mocapNode has rotation animation applied to it. Use presentation node to get rendered position.
            mocapNode = [mocapNode presentationNode];
            
            CATransform3D Rom = [offsetNode transform];
            
            printf("offsets{%lu} = [%f, %f, %f; %f, %f, %f; %f, %f, %f];\n",
                   (unsigned long)i+1,
                   Rom.m11, Rom.m12, Rom.m13,
                   Rom.m21, Rom.m22, Rom.m23,
                   Rom.m31, Rom.m32, Rom.m33
                   );
            
            // BUT! For this to actually work, this requires Vicon Exporter to be
            // [1 0 0] * subjectOffsets{subjectIndex} * rm;
            // note matrix multiplication order
            
            // Isn't 3D maths fun.
            // "The interpretation of a rotation matrix can be subject to many ambiguities."
            // http://en.wikipedia.org/wiki/Rotation_matrix#Ambiguities
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
    
    #pragma mark Key handlers - hit test

    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"q"])
    {
        self.isCone = YES;
        self.coneAngle -= 1;
        
        [self updateGazeGeom];
        
        NSLog(@"cone angle: %f", self.coneAngle);
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"w"])
    {
        self.isCone = YES;
        self.coneAngle += 1;
        
        [self updateGazeGeom];
        
        NSLog(@"cone angle: %f", self.coneAngle);
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"a"])
    {
        self.isCone = NO;
        self.cylinderRadius -= 10;
        
        [self updateGazeGeom];
        
        NSLog(@"cylinderRadius: %f", self.cylinderRadius);
    }
    else if ([[theEvent charactersIgnoringModifiers] isEqualTo:@"s"])
    {
        self.isCone = NO;
        self.cylinderRadius += 10;
        
        [self updateGazeGeom];
        
        NSLog(@"cylinderRadius: %f", self.cylinderRadius);
    }
    
    // Pass onto 'moveUp/Down/Left/Right' methods
    else
    {
        [self interpretKeyEvents:@[theEvent]];
    }
}

# pragma mark Nudge methods

- (void)nudgeSubjectNodeAroundZ:(CGFloat)dz aroundX:(CGFloat)dx aroundY:(CGFloat)dy
{
    // Rotate in this order makes most sense for setting gaze
    
    NSUInteger i = [[self.subjectNodes valueForKey:@"node"] indexOfObject:self.subjectNode];
    
    // We have to apply the static offset rotation after applying the animated rotation
    SCNNode *node = [[self.subjectNode childNodeWithName:@"mocap" recursively:NO] childNodeWithName:@"axes" recursively:NO];
    
    CGFloat z = [self.subjectNodes[i][@"zRot"] doubleValue];
    CGFloat x = [self.subjectNodes[i][@"xRot"] doubleValue];
    CGFloat y = [self.subjectNodes[i][@"yRot"] doubleValue];
    
    z += dz;
    x += dx;
    y += dy;
    
    CATransform3D transform = CATransform3DMakeRotation(GLKMathDegreesToRadians(z), 0, 0, 1);
    transform = CATransform3DRotate(transform, GLKMathDegreesToRadians(x), 1, 0, 0);
    transform = CATransform3DRotate(transform, GLKMathDegreesToRadians(y), 0, 1, 0);
    
    [node setTransform:transform];
    
    self.subjectNodes[i][@"zRot"] = @(z);
    self.subjectNodes[i][@"xRot"] = @(x);
    self.subjectNodes[i][@"yRot"] = @(y);
    
    NSLog(@"Subject %@ xRot: %f yRot:%f zRot: %f", [self.subjectNode name], x, y, z);
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

#endif

@end
