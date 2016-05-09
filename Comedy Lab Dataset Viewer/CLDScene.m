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

#define kCLDdatumPerSubject 10

#define kCLDRowToRowSpacing 1100.0
#define kCLDRowFirstOffset 2400.0
#define kCLDSeatToSeatSpacing 900.0

#define kCLDBreathingBeltMultiplier (500.0 / 0.02)
#define kCLDHappinessMultiplier 5.0

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

static NSString * const laughStateI = @"Indeterminate";
static NSString * const laughStateN = @"Not Laughing";
static NSString * const laughStateS = @"Smiling";
static NSString * const laughStateL = @"Laughing";
static NSString * const isBeingLookedAtNPG = @"NPG";
static NSString * const isBeingLookedAtIPG = @"IPG";
static NSString * const isBeingLookedAtRPG = @"RPG";

@interface NSString (ComedyLabAdditions)

-(NSNumber*) isLaughStateNotN;
-(NSNumber*) isLaughStateNotS;
-(NSNumber*) isLaughStateNotL;

@end

@implementation NSString (ComedyLabAdditions)

-(NSNumber*) isLaughStateNotN
{
    return @(self != laughStateN);
}
-(NSNumber*) isLaughStateNotS
{
    return @(self != laughStateS);
}

-(NSNumber*) isLaughStateNotL
{
    return @(self != laughStateL);
}

@end

@implementation SCNNode (ComedyLabAdditions)

+ (instancetype) arrow
{
    // TASK: Create an arrow 500mm long.
    
    SCNNode *arrow = [SCNNode node];
    [arrow setName:@"arrow"];
    
    SCNNode *cylinder = [SCNNode nodeWithGeometry:[SCNCylinder cylinderWithRadius:20 height:420]];
    [cylinder setPosition:SCNVector3Make(0, 210, 0)];
    [arrow addChildNode:cylinder];
    
    SCNNode *cone = [SCNNode nodeWithGeometry:[SCNCone coneWithTopRadius:0 bottomRadius:40 height:80]];
    [cone setPosition:SCNVector3Make(0, 460, 0)];
    [arrow addChildNode:cone];
    
    return arrow;
}

+ (instancetype) axes
{
    SCNNode *axes = [SCNNode node];
    [axes setName:@"axes"];
    
    SCNNode *axisX = [SCNNode nodeWithGeometry:[SCNCylinder cylinderWithRadius:5 height:500]];
    SCNNode *axisY = [SCNNode nodeWithGeometry:[SCNCylinder cylinderWithRadius:5 height:100]];
    SCNNode *axisZ = [SCNNode nodeWithGeometry:[SCNCylinder cylinderWithRadius:5 height:100]];
    
    [axisX setRotation:SCNVector4Make(0, 0, 1, GLKMathDegreesToRadians(90))];
    [axisZ setRotation:SCNVector4Make(1, 0, 0, GLKMathDegreesToRadians(90))];
    
    [axisX setPosition:SCNVector3Make(250, 0, 0)];
    [axisY setPosition:SCNVector3Make(0, 50, 0)];
    [axisZ setPosition:SCNVector3Make(0, 0, 50)];
    
    SCNMaterial *red = [SCNMaterial material];
    [[red diffuse] setContents:[NSColor redColor]];
    [[axisX geometry] setMaterials:@[red]];
    
    SCNMaterial *green = [SCNMaterial material];
    [[green diffuse] setContents:[NSColor greenColor]];
    [[axisY geometry] setMaterials:@[green]];
    
    SCNMaterial *blue = [SCNMaterial material];
    [[blue diffuse] setContents:[NSColor blueColor]];
    [[axisZ geometry] setMaterials:@[blue]];
    
    [axes addChildNode:axisX];
    [axes addChildNode:axisY];
    [axes addChildNode:axisZ];
    
    return axes;
}

@end

@implementation SCNScene (ComedyLabAdditions)

+ (instancetype)comedyLabScene
{
    SCNScene *scene = [SCNScene scene];
    
    [[scene rootNode] addChildNode:[SCNNode axes]];
    
    // Add in cameras. Two that were actually in experiment, to align onto video. One to use as a roving eye. Values here are eyeballed.
    // 35mm equivalent focal length for JVC GY-HM150 at max wide = 39mm.
    
    SCNCamera *audienceCamera = [SCNCamera camera];
    [audienceCamera setAutomaticallyAdjustsZRange: YES];
    float focalLength = 36;
    [audienceCamera setXFov: (180.0*35.0) / (M_PI*focalLength)];
    
    SCNNode *audienceCameraNode = [SCNNode node];
    [audienceCameraNode setName:@"Camera-Audience"];
    [audienceCameraNode setCamera:audienceCamera];
    
    // Do two-part CATransform3DRotate to ensure orientation is correct
    // Camera angle has been measured to be -
    // ~115-120deg down from vertical, ie. 60-65 up
    CATransform3D cameraOrientation = CATransform3DMakeRotation(GLKMathDegreesToRadians(-92), 0, 0, 1);
    cameraOrientation = CATransform3DRotate(cameraOrientation, GLKMathDegreesToRadians(1), 0, 1, 0);
    cameraOrientation = CATransform3DRotate(cameraOrientation, GLKMathDegreesToRadians(58), 1, 0, 0);
    [audienceCameraNode setTransform:cameraOrientation];
    
    // Now set position in world coords rather than translate.
    // Camera position has been measured to be -
    // Scaff height from floor: 3.473m
    // Camera slung below by ~15cm
    // ie. z = 3330
    [audienceCameraNode setPosition: SCNVector3Make(0, -250, 3230)];
    
    [scene.rootNode addChildNode:audienceCameraNode];
    
    SCNCamera *performerCamera = [SCNCamera camera];
    [performerCamera setAutomaticallyAdjustsZRange:YES];
    focalLength = 59;
    [performerCamera setXFov: (180.0*35.0) / (M_PI*focalLength)];
    
    SCNNode *performerCameraNode = [SCNNode node];
    [performerCameraNode setName:@"Camera-Performer"];
    [performerCameraNode setCamera:performerCamera];
    
    cameraOrientation = CATransform3DMakeRotation(GLKMathDegreesToRadians(90), 0, 0, 1);
    cameraOrientation = CATransform3DRotate(cameraOrientation, GLKMathDegreesToRadians(79), 1, 0, 0);
    [performerCameraNode setTransform:cameraOrientation];
    
    [performerCameraNode setPosition:SCNVector3Make(7500, 0, 2200)];
    
    [scene.rootNode addChildNode:performerCameraNode];
    
    SCNCamera *orthoCamera = [SCNCamera camera];
    orthoCamera.automaticallyAdjustsZRange = YES;
    orthoCamera.usesOrthographicProjection = YES;
    orthoCamera.orthographicScale = 3000;
    
    SCNNode *orthoCameraNode = [SCNNode node];
    orthoCameraNode.name = @"Camera-Orthographic";
    orthoCameraNode.position = SCNVector3Make(2000, 0, 6000);
    [orthoCameraNode setCamera:orthoCamera];
    
    [scene.rootNode addChildNode:orthoCameraNode];
    
    // Add in approximate audience positions, aka seats
    
    for (NSUInteger seat = 1; seat <= 16; ++seat)
    {
        NSString *seatName = [NSString stringWithFormat:@"Seat %02lu", (unsigned long)seat];
        NSUInteger row = (seat - 1) / 4;
        NSUInteger col = (seat - 1) % 4;
        CGFloat x = kCLDRowFirstOffset + (kCLDRowToRowSpacing * row);
        CGFloat y = -1 * ((col - 1.5) * kCLDSeatToSeatSpacing);
        
        SCNNode *seatNode = [SCNNode node];
        [seatNode setName:seatName];
        [seatNode setPosition:SCNVector3Make(x, y, 0)];
        
        SCNNode *label = [SCNNode nodeWithGeometry:[SCNText textWithString:[NSString stringWithFormat:@"%02lu", (unsigned long)seat]
                                                            extrusionDepth:10]];
        [seatNode addChildNode:label];

        [scene.rootNode addChildNode:seatNode];
        
#ifdef CLDRegister3D
        SCNNode *xLineFloor = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:kCLDRowToRowSpacing height:5 length:5 chamferRadius:0]];
        SCNNode *yLineFloor = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:5 height:kCLDSeatToSeatSpacing length:5 chamferRadius:0]];
        SCNNode *xLineMarker = [xLineFloor clone];
        SCNNode *yLineMarker = [yLineFloor clone];
        SCNNode *zLine = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:5 height:5 length:1232 chamferRadius:0]];
        xLineMarker.position = SCNVector3Make(0, 0, 1232);
        yLineMarker.position = SCNVector3Make(0, 0, 1232);
        zLine.position = SCNVector3Make(0, 0, 1232/2);
        
        [seatNode addChildNode:xLineFloor];
        [seatNode addChildNode:xLineMarker];
        [seatNode addChildNode:yLineFloor];
        [seatNode addChildNode:yLineMarker];
        [seatNode addChildNode:zLine];
#endif
    }
        
    // Add in floor, as a visual cue for setting camera

#ifndef CLDRegister3D
    for (CGFloat y = -2500; y <= 2500; y += 500)
    {
        SCNNode *line = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:6000 height:5 length:5 chamferRadius:0]];
        line.position = SCNVector3Make(3000, y, 0);
        [scene.rootNode addChildNode:line];
    }
    for (CGFloat x = 0; x <= 6000; x += 500)
    {
        SCNNode *line = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:5 height:500 length:5 chamferRadius:0]];
        line.position = SCNVector3Make(x, 0, 0);
        [scene.rootNode addChildNode:line];
    }
#endif
    
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
    
    // CSV header format is 'Time' then 'subject/parameter', parameters are x,y,z,rx,ry,rz,ra,gx,gy,gz
    // x,y,z = position
    // rx, ry, rz, ra = rotation as axis-angle
    // gx, gy, gz = gaze direction
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
    CGFloat finalTime = [finalTimeString doubleValue];
    
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
    NSMutableArray *subjectGazeDirectionArray = [NSMutableArray arrayWithCapacity:subjects];
    for (NSUInteger i = 0; i < subjects; i++)
    {
        subjectPositionArray[i] = [NSMutableArray arrayWithCapacity:numberOfLines];
        subjectRotationArray[i] = [NSMutableArray arrayWithCapacity:numberOfLines];
        subjectGazeDirectionArray[i] = [NSMutableArray arrayWithCapacity:numberOfLines];
    }
    
    CGFloat startTime = 0.0;
    
    // Setup scanner
    
    NSMutableCharacterSet* characterSet = [NSMutableCharacterSet characterSetWithCharactersInString:@","];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];

    [scanner setCharactersToBeSkipped:characterSet];
    
    // Scan through data
    
    BOOL newline = true;
    CGFloat datum;
    CGFloat data[kCLDdatumPerSubject];
    NSUInteger i = 0;
    NSUInteger subject = 0;
    NSUInteger dataColumn = 0;
    while ([scanner scanDouble:&datum])
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
                
                // Axis-Angle from Vicon .V file: need to negate the angle to apply to an object in this world
                subjectRotationArray[subject][i] = [NSValue valueWithSCNVector4:SCNVector4Make(data[3], data[4], data[5], -data[6])];
                
                // Gaze direction vector is [gx, gy, gz], ie. data[3,4,5]
                // Arrows have direction vector [0, 1, 0] ie. SCNCylinder draws up y-axis)
                
                subjectGazeDirectionArray[subject][i] = [NSValue valueWithSCNVector4:rotateArrowToVec(data[7], data[8], data[9])];
                
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
        
        // Add in head position node and gaze arrow
        {
            SCNNode *subjectNode = [SCNNode node];
            [subjectNode setName:columnHeader];
        
        #ifdef DEBUG
            SCNNode* subjectRotationNode = [SCNNode node];
            [subjectRotationNode setName:@"mocap"];
            [subjectRotationNode addChildNode:[SCNNode axes]];
            [subjectNode addChildNode:subjectRotationNode];
        #endif
            
            SCNNode* subjectGazeNode = [SCNNode node];
            [subjectGazeNode setName:@"gaze"];
            [subjectGazeNode addChildNode:[SCNNode arrow]];
            [subjectNode addChildNode:subjectGazeNode];
            
            CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
            positionAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
            positionAnimation.duration = finalTime;
            positionAnimation.removedOnCompletion = NO;
            positionAnimation.keyTimes = timeArray;
            positionAnimation.calculationMode = kCAAnimationDiscrete;
            positionAnimation.values = subjectPositionArray[i];
            positionAnimation.usesSceneTimeBase = YES; // HACK: AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions).
            [subjectNode addAnimation:positionAnimation forKey:@"fingers crossed for positions"];
            
        #ifdef DEBUG
            CAKeyframeAnimation *mocapRotationAnimation = [CAKeyframeAnimation animationWithKeyPath:@"rotation"];
            mocapRotationAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
            mocapRotationAnimation.duration = finalTime;
            mocapRotationAnimation.removedOnCompletion = NO;
            mocapRotationAnimation.keyTimes = timeArray;
            mocapRotationAnimation.calculationMode = kCAAnimationDiscrete;
            mocapRotationAnimation.values = subjectRotationArray[i];
            mocapRotationAnimation.usesSceneTimeBase = YES; // HACK: AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions).
            [subjectRotationNode addAnimation:mocapRotationAnimation forKey:@"fingers crossed for mocap rotations"];
        #endif
            
            CAKeyframeAnimation *gazeRotationAnimation = [CAKeyframeAnimation animationWithKeyPath:@"rotation"];
            gazeRotationAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
            gazeRotationAnimation.duration = finalTime;
            gazeRotationAnimation.removedOnCompletion = NO;
            gazeRotationAnimation.keyTimes = timeArray;
            gazeRotationAnimation.calculationMode = kCAAnimationDiscrete;
            gazeRotationAnimation.values = subjectGazeDirectionArray[i];
            gazeRotationAnimation.usesSceneTimeBase = YES; // HACK: AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions).
            [subjectGazeNode addAnimation:gazeRotationAnimation forKey:@"fingers crossed for gaze rotations"];
            
            [self.rootNode addChildNode:subjectNode];
        }
        // Add in guide lines for subjects
        {
            SCNNode *subjectNode = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:5 height:5 length:1000 chamferRadius:0]];
            [subjectNode setName:columnHeader];
            
            NSMutableArray *positionArray = [NSMutableArray arrayWithCapacity:[subjectPositionArray[i] count]];
            [subjectPositionArray[i] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                SCNVector3 xyz = [obj SCNVector3Value];
                SCNVector3 pos = SCNVector3Make(xyz.x, xyz.y, 500);
                [positionArray addObject:[NSValue valueWithSCNVector3:pos]];
            }];
            
            CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
            positionAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
            positionAnimation.duration = finalTime;
            positionAnimation.removedOnCompletion = NO;
            positionAnimation.keyTimes = timeArray;
            positionAnimation.calculationMode = kCAAnimationDiscrete;
            positionAnimation.values = positionArray;
            positionAnimation.usesSceneTimeBase = YES; // HACK: AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions).
            [subjectNode addAnimation:positionAnimation forKey:@"fingers crossed for positions"];
            
            [self.rootNode addChildNode:subjectNode];
        }
    }

    if ([[self attributeForKey:SCNSceneStartTimeAttributeKey] doubleValue] < 0.0001 || startTime < [[self attributeForKey:SCNSceneStartTimeAttributeKey] doubleValue])
    {
        [self setAttribute:@(startTime) forKey:SCNSceneStartTimeAttributeKey];
    }
    if (finalTime > [[self attributeForKey:SCNSceneEndTimeAttributeKey] doubleValue])
    {
        [self setAttribute:@(finalTime) forKey:SCNSceneEndTimeAttributeKey];
    }
    
    return YES;
}


- (BOOL)addWithDatasetURL:(NSURL *)url error:(NSError **)error
{
    NSString *fileString = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
    
    if (!fileString)
    {
        NSLog(@"Abort import - Dataset URL: %@", url);
        return NO;
    }
    
    // TASK: Parse CSV file exported from ComedyLab Stats Exporter
    // Exporter: https://github.com/tobyspark/ComedyLab/tree/master/Stats%20Exporter
    // Dataset file: https://github.com/tobyspark/ComedyLab/blob/master/Data%20-%20For%20analysis/Comedy%20Lab%204Jun%20Performance%201%20Data.txt
    
    // Columns as per StatsConfig.json, ie. https://github.com/tobyspark/ComedyLab/blob/master/Stats%20Exporter/Perf%203%20Data/Performance%203%20StatsConfig.json
    // "fields": ["Light State While", "Laugh State", "Breathing Belt", "Happy", "Sad", "Surprised", "Angry", "MouthOpen", "Distance from Performer", "Angle from Performer", "Movement", "isLookingAt", "isBeingLookedAtByPerformer", "isBeingLookedAtByAudienceMember"]

    NSScanner *scanner = [NSScanner scannerWithString:fileString];
    
    // Count number of lines
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/TextLayout/Tasks/CountLines.html
    NSUInteger numberOfLines, index, lastIndex = 0, stringLength = [fileString length];
    for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++)
    {
        lastIndex = index;
        index = NSMaxRange([fileString lineRangeForRange:NSMakeRange(index, 0)]);
    }
    
    // Find first and last time entry
    NSString *line = nil;
    [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&line]; // header
    [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&line]; // first entry
    
    NSArray *entries = [line componentsSeparatedByString:@", "];
    CGFloat startTime = [entries[1] doubleValue];
    if (startTime < 0.0001)
    {
        // our dataset's data (as opposed to video) starts a few minutes in
        // doubleValue will return 0 on a non-number string
        NSLog(@"Start time value zero or could not be parsed");
        return NO;
    }
    if ([[self attributeForKey:SCNSceneStartTimeAttributeKey] doubleValue] < 0.0001 || startTime < [[self attributeForKey:SCNSceneStartTimeAttributeKey] doubleValue])
    {
        [self setAttribute:@(startTime) forKey:SCNSceneStartTimeAttributeKey];
    }
    
    [scanner setScanLocation:lastIndex];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&line];
    
    entries = [line componentsSeparatedByString:@", "];
    CGFloat endTime = [entries[1] doubleValue];
    if (endTime < 0.0001)
    {
        NSLog(@"Final time value zero or could not be parsed");
        return NO;
    }
    
    if (endTime > [[self attributeForKey:SCNSceneEndTimeAttributeKey] doubleValue])
    {
        [self setAttribute:@(endTime) forKey:SCNSceneEndTimeAttributeKey];
    }
    
    [scanner setScanLocation:0];
    
    // Start scan proper
    
    NSArray *headerExpectedItems = @[@"AudienceID", @"TimeStamp", @"Light State While", @"Laugh State", @"Breathing Belt", @"Happy", @"Sad", @"Surprised", @"Angry", @"MouthOpen", @"Distance from Performer", @"Angle from Performer", @"Movement", @"isLookingAtPerformer", @"isLookingAtAudience", @"isBeingLookedAtByPerformer", @"isBeingLookedAtByAudienceMember", @"isLookingAtVPScreen"];
    
    // Parse header row
    NSString *header = nil;
    [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&header];
    
    NSArray *headerItems = [header componentsSeparatedByString:@", "];
    
    if (![headerItems isEqual:headerExpectedItems])
    {
        // Remove VPScreen measure and re-compare
        headerExpectedItems = [headerExpectedItems subarrayWithRange:NSMakeRange(0, [headerExpectedItems count]-1)];
        if (![headerItems isEqual:headerExpectedItems])
        {
            NSLog(@"Headers not as expected");
            NSLog(@"Expected: %@", headerExpectedItems);
            NSLog(@"Found: %@", headerItems);
            return NO;
        }
    }
    
    // TASK: Parse data
    
    // CSV data *has* spaces, no missing values.
    
    // Create arrays to hold position and rotation over time for all subjects
    
    CGFloat stepTime = 0.1;
    NSUInteger timeStampCount = ((endTime - startTime) / stepTime) + 1;
    
    NSMutableArray *timeArray = [NSMutableArray arrayWithCapacity:timeStampCount];
    for (NSUInteger i = 0; i < timeStampCount; ++i)
    {
        [timeArray addObject:@(startTime + i*stepTime)];
    }
    
    NSValue * const lightStateLit = [NSValue valueWithSCNVector3:SCNVector3Make(1, 1, 1)];
    NSValue * const lightStateUnlit = [NSValue valueWithSCNVector3:SCNVector3Make(0.1, 0.1, 0.1)];
    NSValue * const SCNVec3Zero = [NSValue valueWithSCNVector3:SCNVector3Make(0, 0, 0)];
    
    NSMutableDictionary *audienceData = [NSMutableDictionary dictionaryWithCapacity:16];
    
    NSDictionary* (^subjectDataWithName)(NSString*) = ^NSDictionary*(NSString* name)
    {
        NSMutableDictionary *subjectData = [NSMutableDictionary dictionaryWithCapacity:10];
        
        // Pre-populate data dict
        
        [subjectData setObject:[NSMutableArray arrayWithCapacity:timeStampCount] forKey:@"lightState"];
        [subjectData setObject:[NSMutableArray arrayWithCapacity:timeStampCount] forKey:@"breathingBelt"];
        [subjectData setObject:[NSMutableArray arrayWithCapacity:timeStampCount] forKey:@"happiness"];
        
        for (NSString* key in subjectData)
        {
            NSMutableArray *array = [subjectData objectForKey:key];
            for (NSUInteger i = 0; i < timeStampCount; ++i)
            {
                [array addObject:SCNVec3Zero];
            }
        }
        
        [subjectData setObject:[NSMutableArray arrayWithCapacity:timeStampCount] forKey:@"laughState"];
        {
            NSMutableArray *array = [subjectData objectForKey:@"laughState"];
            for (NSUInteger i = 0; i < timeStampCount; ++i)
            {
                [array addObject:laughStateI];
            }
        }
        
        [subjectData setObject:[NSMutableArray arrayWithCapacity:timeStampCount] forKey:@"isBeingLookedAt"];
        {
            NSMutableArray *array = [subjectData objectForKey:@"isBeingLookedAt"];
            for (NSUInteger i = 0; i < timeStampCount; ++i)
            {
                [array addObject:isBeingLookedAtNPG];
            }
        }
        
        // Find mocap and seat nodes
        
        NSString* subjectNodeName = [name stringByReplacingOccurrencesOfString:@"Audience " withString:@"Audience_"];
        NSString* seatNodeName = [name stringByReplacingOccurrencesOfString:@"Audience " withString:@"Seat "];;
        
        NSArray *subjectNodes = [[self rootNode] childNodesPassingTest:^BOOL(SCNNode *child, BOOL *stop) {
            return [[child name] isEqualToString:subjectNodeName] && [[child childNodes] count] > 0;
        }];
        
        
        NSArray *seatNodes = [[self rootNode] childNodesPassingTest:^BOOL(SCNNode *child, BOOL *stop) {
            return [[child name] isEqualToString:seatNodeName];
        }];
        
        // Add in associated nodes
        
        if ([seatNodes count] == 1)
        {
            [subjectData setObject:seatNodes[0] forKey:@"seatNode"];
        }
        else
        {
            NSLog(@"%lu Seat node(s) found for %@, aborting", [seatNodes count], name);
            return nil;
        }
        
        if ([subjectNodes count] == 1)
        {
            [subjectData setObject:subjectNodes[0] forKey:@"subjectNode"];
        }
        else
        {
            NSLog(@"%lu Mocap node(s) found for %@, using seat node instead", [subjectNodes count], name);
            [subjectData setObject:seatNodes[0] forKey:@"subjectNode"];
        }
        
        return subjectData;
    };
    
    // Setup scanner
    
    // Can't scan through directly as some numerical values are 'n/a', so take line and split into array
    NSCharacterSet *newLine = [NSCharacterSet newlineCharacterSet];
    
    while ([scanner scanUpToCharactersFromSet:newLine intoString:&line])
    {
        NSArray *entries = [line componentsSeparatedByString:@", "];
        
        // Subject, #0
        
        NSString *subjectName = entries[0];
        
        NSDictionary *subjectData = [audienceData objectForKey:subjectName];
        if (!subjectData)
        {
            subjectData = subjectDataWithName(subjectName);
            [audienceData setObject:subjectData forKey:subjectName];
        }
        
        // TimeStamp, #1
        
        CGFloat time = [entries[1] doubleValue];
        NSUInteger timeIndex = round(((time - startTime) / stepTime));
        //NSLog(@"time %@ gets via index %@", entries[1], timeArray[timeIndex]);
        
        // Light State, #2
        {
            NSValue* value;
            if ([entries[2] hasPrefix:@"Lit"]) value = lightStateLit;
            else if ([entries[2] hasPrefix:@"Unlit"]) value = lightStateUnlit;
            if (value)
            {
                NSMutableArray *array = [subjectData objectForKey:@"lightState"];
                [array replaceObjectAtIndex:timeIndex withObject:value];
            }
        }
        
        // Laugh State, #3
        {
            NSString* value;
            if ([entries[3] isEqualToString:laughStateN]) value = laughStateN;
            else if ([entries[3] isEqualToString:laughStateS]) value = laughStateS;
            else if ([entries[3] isEqualToString:laughStateL]) value = laughStateL;
            if (value)
            {
                NSMutableArray *array = [subjectData objectForKey:@"laughState"];
                [array replaceObjectAtIndex:timeIndex withObject:value];
            }
        }
        
        
        // Breathing Belt, #4
        {
            NSMutableArray *array = [subjectData objectForKey:@"breathingBelt"];
            NSString *entryString = entries[4];
            if (![entryString isEqualToString:@"n/a"])
            {
                CGFloat entry = [entryString doubleValue];
                NSValue *value = [NSValue valueWithSCNVector3:SCNVector3Make(1, 1, fabs(entry*kCLDBreathingBeltMultiplier))];
                [array replaceObjectAtIndex:timeIndex withObject:value];
            }
        }
        
        // Happiness, #5
        {
            NSMutableArray *array = [subjectData objectForKey:@"happiness"];
            NSString *entryString = entries[5];
            if (![entryString isEqualToString:@"n/a"])
            {
                CGFloat entry = [entryString doubleValue];
                NSValue *value = [NSValue valueWithSCNVector3:SCNVector3Make(1, 1, entry*kCLDHappinessMultiplier)];
                [array replaceObjectAtIndex:timeIndex withObject:value];
            }
        }
        
        // isBeingLookedAtByPerformer, #15
        {
            NSMutableArray *array = [subjectData objectForKey:@"isBeingLookedAt"];
            NSString *entryString = entries[15];
            if (![entryString isEqualToString:@"n/a"])
            {
                NSNumber* value = [NSNumber numberWithBool:![entryString boolValue]]; // Controls 'hidden' not 'visible'!
                [array replaceObjectAtIndex:timeIndex withObject:value];
            }
        }
    }
    
    // Add in subjects: an arrow with position and rotation set over time.
    SCNGeometry *box = [SCNBox boxWithWidth:40 height:40 length:1 chamferRadius:0];
    SCNGeometry *geoN = [SCNText textWithString:@"N" extrusionDepth:1];
    SCNGeometry *geoS = [SCNText textWithString:@"S" extrusionDepth:1];
    SCNGeometry *geoL = [SCNText textWithString:@"L" extrusionDepth:1];
    
    for (NSString* subjectName in audienceData)
    {
        NSDictionary *subjectData = [audienceData objectForKey:subjectName];
        
        // Light State
        {
            NSArray *array = [subjectData objectForKey:@"lightState"];
            
            CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"scale"];
            animation.beginTime = AVCoreAnimationBeginTimeAtZero;
            animation.duration = endTime;
            animation.removedOnCompletion = NO;
            animation.keyTimes = timeArray;
            animation.calculationMode = kCAAnimationDiscrete;
            animation.values = array;
            animation.usesSceneTimeBase = YES;
            
            SCNNode *lightStateNode = [SCNNode nodeWithGeometry:[SCNCylinder cylinderWithRadius:500 height:1]];
            [lightStateNode setName:@"lightState"];
            [lightStateNode setRotation:SCNVector4Make(1, 0, 0, GLKMathDegreesToRadians(90))];
            [lightStateNode addAnimation:animation forKey:@"fingers crossed for lightState"];
            [[subjectData objectForKey:@"seatNode"] addChildNode:lightStateNode];
        }
        
        // Laugh State
        {
            SCNNode *laughStateNode = [SCNNode node];
            [laughStateNode setName:@"laughState"];
            CATransform3D transform = CATransform3DMakeRotation(GLKMathDegreesToRadians(90), 1, 0, 0);
            transform = CATransform3DRotate(transform, GLKMathDegreesToRadians(90), 0, -1, 0);
            [laughStateNode setTransform:transform];
            [laughStateNode setScale:SCNVector3Make(4, 4, 40)];
            [laughStateNode setPosition:SCNVector3Make(0, 200, -40)];
            [[subjectData objectForKey:@"seatNode"] addChildNode:laughStateNode];
            {
                NSArray *array = [subjectData objectForKey:@"laughState"];
                
                CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"hidden"];
                animation.beginTime = AVCoreAnimationBeginTimeAtZero;
                animation.duration = endTime;
                animation.removedOnCompletion = NO;
                animation.keyTimes = timeArray;
                animation.calculationMode = kCAAnimationDiscrete;
                animation.values = [array valueForKey:@"isLaughStateNotN"];
                animation.usesSceneTimeBase = YES;
                
                SCNNode *node = [SCNNode nodeWithGeometry:geoN];
                [node addAnimation:animation forKey:@"fingers crossed for geoN"];
                [laughStateNode addChildNode:node];
            }
            {
                NSArray *array = [subjectData objectForKey:@"laughState"];
                
                CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"hidden"];
                animation.beginTime = AVCoreAnimationBeginTimeAtZero;
                animation.duration = endTime;
                animation.removedOnCompletion = NO;
                animation.keyTimes = timeArray;
                animation.calculationMode = kCAAnimationDiscrete;
                animation.values = [array valueForKey:@"isLaughStateNotS"];
                animation.usesSceneTimeBase = YES;
                
                SCNNode *node = [SCNNode nodeWithGeometry:geoS];
                [node addAnimation:animation forKey:@"fingers crossed for geoS"];
                [laughStateNode addChildNode:node];
            }
            {
                NSArray *array = [subjectData objectForKey:@"laughState"];
                
                CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"hidden"];
                animation.beginTime = AVCoreAnimationBeginTimeAtZero;
                animation.duration = endTime;
                animation.removedOnCompletion = NO;
                animation.keyTimes = timeArray;
                animation.calculationMode = kCAAnimationDiscrete;
                animation.values = [array valueForKey:@"isLaughStateNotL"];
                animation.usesSceneTimeBase = YES;
                
                SCNNode *node = [SCNNode nodeWithGeometry:geoL];
                [node addAnimation:animation forKey:@"fingers crossed for geoL"];
                [laughStateNode addChildNode:node];
            }
        }
        
        // Breathing Belts
        {
            NSArray *array = [subjectData objectForKey:@"breathingBelt"];
            
            CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"scale"];
            animation.beginTime = AVCoreAnimationBeginTimeAtZero;
            animation.duration = endTime;
            animation.removedOnCompletion = NO;
            animation.keyTimes = timeArray;
            animation.calculationMode = kCAAnimationDiscrete;
            animation.values = array;
            animation.usesSceneTimeBase = YES;
            
            SCNNode *node = [SCNNode nodeWithGeometry:box];
            [node setName:@"breathingBelt"];
            [node setPosition:SCNVector3Make(0, -60, 0.5)];
            [node setPivot:CATransform3DMakeTranslation(0, 0, -0.5)];
            [node addAnimation:animation forKey:@"fingers crossed for breathingBelt"];
            [[subjectData objectForKey:@"seatNode"] addChildNode:node];
        }
        
        // Happiness
        {
            NSArray *array = [subjectData objectForKey:@"happiness"];
            
            CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"scale"];
            animation.beginTime = AVCoreAnimationBeginTimeAtZero;
            animation.duration = endTime;
            animation.removedOnCompletion = NO;
            animation.keyTimes = timeArray;
            animation.calculationMode = kCAAnimationDiscrete;
            animation.values = array;
            animation.usesSceneTimeBase = YES;
            
            SCNNode *node = [SCNNode nodeWithGeometry:box];
            [node setName:@"happiness"];
            [node setPosition:SCNVector3Make(0, -120, 0.5)];
            [node setPivot:CATransform3DMakeTranslation(0, 0, -0.5)];
            [node addAnimation:animation forKey:@"fingers crossed for happiness"];
            [[subjectData objectForKey:@"seatNode"] addChildNode:node];
        }
        
        // isBeingLookedAt
        {
            NSArray *array = [subjectData objectForKey:@"isBeingLookedAt"];
            
            CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"hidden"];
            animation.beginTime = AVCoreAnimationBeginTimeAtZero;
            animation.duration = endTime;
            animation.removedOnCompletion = NO;
            animation.keyTimes = timeArray;
            animation.calculationMode = kCAAnimationDiscrete;
            animation.values = array;
            animation.usesSceneTimeBase = YES;
            
            SCNNode *node = [SCNNode nodeWithGeometry:[SCNSphere sphereWithRadius:50]];
            [node addAnimation:animation forKey:@"fingers crossed for isBeingLookedAt"];
            [[[subjectData objectForKey:@"subjectNode"] childNodeWithName:@"gaze" recursively:NO] addChildNode:node];
        }
    }

    return YES;
}

- (void) setCameraNodePosition:(SCNNode *)cameraNode withData:(NSData *)data
{
    CATransform3D recalledTransform;
    [data getBytes:&recalledTransform range:NSMakeRange(0, sizeof(CATransform3D))];
    double recalledScale;
    [data getBytes:&recalledScale range:NSMakeRange(sizeof(CATransform3D), sizeof(double))];
    
    [cameraNode setTransform:recalledTransform];
    [cameraNode.camera setOrthographicScale:recalledScale];
}

- (NSData *)positionDataWithCameraNode:(SCNNode *)cameraNode
{
    // Use NSData as [NSValue CATransform3DValue] can't be archived by NSDictionary or NSKeyedArchiver
    // And it turns out we need to bundle orthoScale along with the transform also

    CATransform3D transform = cameraNode.transform;
    NSMutableData *povData = [NSMutableData dataWithBytes:&transform length:sizeof(CATransform3D)];
    double orthographicScale = cameraNode.camera.orthographicScale;
    [povData appendBytes:&orthographicScale length:sizeof(double)];
    
    return [povData copy];
}

- (NSArray *)standardCameraPositions
{
    // Extents
    // x: 0:6000
    // y: -2500:2500
    // z: 0:2000
    
    NSMutableArray *cameraPositions = [NSMutableArray arrayWithCapacity:3];
    
    SCNNode *orthoCameraNode = [self.rootNode childNodeWithName:@"Camera-Orthographic" recursively:NO];
    
    // Push
    CATransform3D transform = orthoCameraNode.transform;
    double scale = orthoCameraNode.camera.orthographicScale;
    
    // Set Top
    orthoCameraNode.position = SCNVector3Make(2000, 0, 6000);
    orthoCameraNode.rotation = SCNVector4Make(0, 0, 0, 0);
    orthoCameraNode.camera.orthographicScale = 3000;
    
    [cameraPositions addObject:[self positionDataWithCameraNode:orthoCameraNode]];
    
    // Set Side
    orthoCameraNode.position = SCNVector3Make(3000, -6000, 1000);
    orthoCameraNode.rotation = SCNVector4Make(1, 0, 0, GLKMathDegreesToRadians(90));
    orthoCameraNode.camera.orthographicScale = 2000;
    
    [cameraPositions addObject:[self positionDataWithCameraNode:orthoCameraNode]];
    
    // Set Front
    CATransform3D rotTransform = CATransform3DMakeRotation(GLKMathDegreesToRadians(-90), 0, 1, 0);
    rotTransform = CATransform3DRotate(rotTransform, GLKMathDegreesToRadians(-90), 0, 0, 1);
    orthoCameraNode.transform = rotTransform;
    orthoCameraNode.position = SCNVector3Make(-6000, 0, 1000);
    orthoCameraNode.camera.orthographicScale = 2000;
    
    [cameraPositions addObject:[self positionDataWithCameraNode:orthoCameraNode]];
    
    // Pop
    orthoCameraNode.transform = transform;
    orthoCameraNode.camera.orthographicScale = scale;
    
    return [cameraPositions copy];
}

- (NSArray *)personNodes
{
    // This should be a property added to during import of mocap data, but I'd written this in the course of [SCNView setCameraWithPersonNode:] so here this is instead
    
    // Node structure of a person
    // Performer / Audience_XX (position)
    // -> gaze (rotation)
    //    -> arrow
    
    return [self.rootNode childNodesPassingTest:^BOOL(SCNNode *child, BOOL *stop)
                    {
                        if ([[child name] hasPrefix:@"Audience"] || [[child name] isEqual:@"Performer"])
                        {
                            if ([child childNodeWithName:@"gaze" recursively:NO])
                            {
                                return YES;
                            }
                        }
                        return NO;
                    }];
}

@end
