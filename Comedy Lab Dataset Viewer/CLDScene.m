//
//  CLDScene.m
//  Comedy Lab Dataset Viewer
//
//  Created by Toby Harris | http://tobyz.net on 14/05/2014.
//  Copyright (c) 2014 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import "CLDScene.h"

#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>
#import "linmath.h"

#define kCLDdatumPerSubject 6

static inline void rotationFromVecToVec(vec4 angleAxisVec, vec3 fromVec, vec3 toVec)
{
    vec3 startVec = {fromVec[0], fromVec[1], fromVec[2]};
    vec3 endVecBeforeNorm = {toVec[0], toVec[1], toVec[2]};
    vec3 endVec;
    vec3_norm(endVec, endVecBeforeNorm);
    
    // Cross-product gives axis of rotation
    vec3 axis, normAxis;
    vec3_mul_cross(axis, startVec, endVec);
    vec3_norm(normAxis, axis);
    angleAxisVec[0] = normAxis[0];
    angleAxisVec[1] = normAxis[1];
    angleAxisVec[2] = normAxis[2];
    
    // acos of dot-product gives angle of rotation
    float dot = vec3_mul_inner(startVec, endVec);
    angleAxisVec[3] = acosf(dot);
}

static inline SCNVector4 rotateArrowToVec(float x, float y, float z)
{
    // Arrows have direction vector [0, 1, 0] ie. SCNCylinder draws up y-axis)
    // To point arrow in SceneKit need angle-axis rotation from [0,1,0] to [x, y, z]
    
    vec3 arrow = {0, 1, 0};
    vec3 toVec = {x, y, z};
    vec4 angleAxis;
    rotationFromVecToVec(angleAxis, arrow, toVec);
    
    return SCNVector4Make(angleAxis[0], angleAxis[1], angleAxis[2], angleAxis[3]);
}

static inline SCNVector4 rotateCameraToVec(float x, float y, float z)
{
    // Camera have direction vector [0, 0, -1] ie. SCNCamera looks along neg z axis
    
    vec3 camera = {0, 0, -1};
    vec3 toVec = {x, y, z};
    vec4 angleAxis;
    rotationFromVecToVec(angleAxis, camera, toVec);
    
    return SCNVector4Make(angleAxis[0], angleAxis[1], angleAxis[2], angleAxis[3]);
}

@implementation SCNNode (ComedyLabAdditions)

+ (SCNNode *) arrow
{
    // TASK: Create an arrow 500mm long.
    
    SCNNode *arrow = [SCNNode node];
    
    SCNNode *cylinder = [SCNNode nodeWithGeometry:[SCNCylinder cylinderWithRadius:20 height:420]];
    [cylinder setPosition:SCNVector3Make(0, 210, 0)];
    [arrow addChildNode:cylinder];
    
    SCNNode *cone = [SCNNode nodeWithGeometry:[SCNCone coneWithTopRadius:0 bottomRadius:40 height:80]];
    [cone setPosition:SCNVector3Make(0, 460, 0)];
    [arrow addChildNode:cone];
    
    return arrow;
}

@end

@implementation SCNScene (ComedyLabAdditions)

+ (instancetype)comedyLabScene
{
    SCNScene *scene = [SCNScene scene];
    
    // Add in cameras. Two that were actually in experiment, to align onto video. One to use as a roving eye. Values here are eyeballed.
    
    SCNCamera *audienceCamera = [SCNCamera camera];
    [audienceCamera setAutomaticallyAdjustsZRange: YES];
    [audienceCamera setXFov: (180.0*35.0) / (M_PI*39)]; // 35mm equivalent focal length for JVC GY-HM150 at max wide = 39mm
    
    CATransform3D audienceTransform = CATransform3DMakeRotation(GLKMathDegreesToRadians(-90), 0, 0, 1);
    audienceTransform = CATransform3DRotate(audienceTransform, GLKMathDegreesToRadians(100), 1, 0, 0);
    audienceTransform = CATransform3DTranslate(audienceTransform, -1000, 0, 3000);
    
    SCNNode *audienceCameraNode = [SCNNode node];
    [audienceCameraNode setName:@"Camera-Audience"];
    [audienceCameraNode setCamera:audienceCamera];
    [audienceCameraNode setTransform:audienceTransform];
    
    [scene.rootNode addChildNode:audienceCameraNode];
    
    SCNCamera *performerCamera = [SCNCamera camera];
    [performerCamera setAutomaticallyAdjustsZRange:YES];
    //[performerCamera setXFov:90];
    
    CATransform3D performerTransform = CATransform3DMakeRotation(GLKMathDegreesToRadians(-90), 0, 0, 1);
    //performerTransform = CATransform3DRotate(performerTransform, GLKMathDegreesToRadians(90), 1, 0, 0);
    //performerTransform = CATransform3DTranslate(performerTransform, 6000, 0, 2000);
    
    SCNNode *performerCameraNode = [SCNNode node];
    [performerCameraNode setName:@"Camera-Performer"];
    [performerCameraNode setCamera:performerCamera];
    [performerCameraNode setTransform:performerTransform];
    
    [scene.rootNode addChildNode:performerCameraNode];
    
    SCNCamera *orthoCamera = [SCNCamera camera];
    orthoCamera.automaticallyAdjustsZRange = YES;
    orthoCamera.usesOrthographicProjection = YES;
    orthoCamera.orthographicScale = 3000;
    
    SCNNode *orthoCameraNode = [SCNNode node];
    orthoCameraNode.name = @"Camera-Orthographic";
    orthoCameraNode.position = SCNVector3Make(2000, 0, 2000); // a guess for now
    [orthoCameraNode setCamera:orthoCamera];
    
    [scene.rootNode addChildNode:orthoCameraNode];
    
    // Add in floor, as a visual cue for setting camera
    SCNNode *floor = [SCNNode nodeWithGeometry:[SCNPlane planeWithWidth:6000 height:4000]];
    floor.position = SCNVector3Make(3000, 0, 0);
    [scene.rootNode addChildNode:floor];
    
    // Add in a light.
    // Use diffuse rather than spot as we want to see the arrows, but set it approx where spotlight is so arrows light vaugely as per scene.
    SCNLight *light = [SCNLight light];
    light.type = SCNLightTypeOmni;
    SCNNode *lightNode = [SCNNode node];
    lightNode.position = SCNVector3Make(-1000, 0, 4000);
    [lightNode setLight:light];
    [scene.rootNode addChildNode:lightNode];
    
    return scene;
}

- (BOOL)addWithMocapURL:(NSURL *)url error:(NSError **)error
{

    NSString *fileString = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];

    if (!fileString)
    {
        NSLog(@"Abort import - Mocap URL: %@", url);
        return NO;
    }
    
    // TASK: Parse CSV file exported from Vicon .V files via MATLAB
    // https://github.com/tobyspark/ComedyLab/tree/master/Vicon%20Exporter
    
    // CSV header format is 'Time' then 'subject/parameter', parameters are x,y,z,gx,gy,gz
    // ie. Time,Performer_Hat/x,Performer_Hat/y,Performer_Hat/z,Performer_Hat/gx,Performer_Hat/gy,Performer_Hat/gz,Audience_01_Hat/x,Audience_01_Hat/y,Audience_01_Hat/z,Audience_01_Hat/gx,Audience_01_Hat/gy,Audience_01_Hat/gz,Audience_02/x...
    
    NSScanner *scanner = [NSScanner scannerWithString:fileString];
    
    // Count number of lines
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/TextLayout/Tasks/CountLines.html
    NSUInteger numberOfLines, index, lastIndex = 0, stringLength = [fileString length];
    for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++)
    {
        lastIndex = index;
        index = NSMaxRange([fileString lineRangeForRange:NSMakeRange(index, 0)]);
    }
    
    // Find final time entry
    NSString *finalTimeString = nil;
    [scanner setScanLocation:lastIndex];
    [scanner scanUpToString:@"," intoString:&finalTimeString];
    float finalTime = [finalTimeString floatValue];
    
    if (finalTime < 0.0001)
    {
        NSLog(@"Final time value zero or could not be parsed");
        return NO;
    }
    
    // Parse header row
    NSString *header = nil;
    [scanner setScanLocation:0];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&header];
    
    NSArray *headerItems = [header componentsSeparatedByString:@","];
    
    if (![headerItems[0] isEqualToString:@"Time"])
    {
        NSLog(@"First header column not 'Time', aborting");
        return NO;
    }
    
    NSUInteger dataColumns = [headerItems count] - 1;
    NSUInteger subjects = dataColumns / kCLDdatumPerSubject;
    
    // TASK: Parse data
    
    // CSV data has no spaces, no missing values.
    
    // Create arrays to hold position and rotation over time for all subjects

    NSMutableArray *timeArray = [NSMutableArray arrayWithCapacity:numberOfLines];
    NSMutableArray *subjectPositionArray = [NSMutableArray arrayWithCapacity:subjects];
    NSMutableArray *subjectRotationArray = [NSMutableArray arrayWithCapacity:subjects];
    for (NSUInteger i = 0; i < subjects; i++)
    {
        subjectPositionArray[i] = [NSMutableArray arrayWithCapacity:numberOfLines];
        subjectRotationArray[i] = [NSMutableArray arrayWithCapacity:numberOfLines];
    }
    
    float startTime = 0.0;
    
    // Setup scanner
    
    NSMutableCharacterSet* characterSet = [NSMutableCharacterSet characterSetWithCharactersInString:@","];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];

    [scanner setCharactersToBeSkipped:characterSet];
    
    // Scan through data
    
    BOOL newline = true;
    float datum;
    float data[kCLDdatumPerSubject];
    NSUInteger i = 0;
    NSUInteger subject = 0;
    NSUInteger dataColumn = 0;
    while ([scanner scanFloat:&datum])
    {
        if (newline)
        {
            NSLog(@"Time: %f, %f", datum, datum / finalTime);
            timeArray[i] = @(datum / finalTime);
            newline = NO;
            
            if (i == 0)
            {
                startTime = datum;
            }
        }
        else
        {
            data[dataColumn] = datum;
            
            dataColumn++;
            
            // Move onto next subject
            if (dataColumn >= kCLDdatumPerSubject)
            {
                subjectPositionArray[subject][i] = [NSValue valueWithSCNVector3:SCNVector3Make(data[0], data[1], data[2])];
                
                // Gaze direction vector is [gx, gy, gz], ie. data[3,4,5]
                // Arrows have direction vector [0, 1, 0] ie. SCNCylinder draws up y-axis)
                
                
                subjectRotationArray[subject][i] = [NSValue valueWithSCNVector4:rotateArrowToVec(data[3], data[4], data[5])];
                
                dataColumn = 0;
                subject++;
            }
            
            // Move onto next time
            if (subject >= subjects)
            {
                newline = YES;
                subject = 0;
                i++;
            }
        }
    }
    
    // Add in subjects: an arrow with position and rotation set over time.
    
    for (NSUInteger i = 0; i < subjects; i++)
    {
        NSString *columnHeader = headerItems[1 + i*kCLDdatumPerSubject];
        columnHeader = [columnHeader componentsSeparatedByString:@"/"][0];
        columnHeader = [columnHeader componentsSeparatedByString:@"_Hat"][0];
        
        SCNNode *subjectNode = [SCNNode node];
        [subjectNode setName:columnHeader];
        [subjectNode addChildNode:[SCNNode arrow]];
        
        CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        positionAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
        positionAnimation.duration = finalTime;
        positionAnimation.removedOnCompletion = NO;
        positionAnimation.keyTimes = timeArray;
        positionAnimation.calculationMode = kCAAnimationDiscrete;
        positionAnimation.values = subjectPositionArray[i];
        positionAnimation.usesSceneTimeBase = YES; // HACK: AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions).
        [subjectNode addAnimation:positionAnimation forKey:@"fingers crossed for positions"];
        
        CAKeyframeAnimation *rotationAnimation = [CAKeyframeAnimation animationWithKeyPath:@"rotation"];
        rotationAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
        rotationAnimation.duration = finalTime;
        rotationAnimation.removedOnCompletion = NO;
        rotationAnimation.keyTimes = timeArray;
        rotationAnimation.calculationMode = kCAAnimationDiscrete;
        rotationAnimation.values = subjectRotationArray[i];
        rotationAnimation.usesSceneTimeBase = YES; // HACK: AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions).
        [subjectNode addAnimation:rotationAnimation forKey:@"fingers crossed for rotations"];
        
        [self.rootNode addChildNode:subjectNode];
    }
    
    [self setAttribute:@(startTime) forKey:SCNSceneStartTimeAttributeKey];
    [self setAttribute:@(finalTime) forKey:SCNSceneEndTimeAttributeKey];
    
    return YES;
}

@end
