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
    // 35mm equivalent focal length for JVC GY-HM150 at max wide = 39mm.
    
    SCNCamera *audienceCamera = [SCNCamera camera];
    [audienceCamera setAutomaticallyAdjustsZRange: YES];
    float focalLength = 40;
    [audienceCamera setXFov: (180.0*35.0) / (M_PI*focalLength)];
    
    SCNNode *audienceCameraNode = [SCNNode node];
    [audienceCameraNode setName:@"Camera-Audience"];
    [audienceCameraNode setCamera:audienceCamera];
    
    // Do two-part CATransform3DRotate to ensure orientation is correct
    CATransform3D cameraOrientation = CATransform3DMakeRotation(GLKMathDegreesToRadians(-90), 0, 0, 1);
    cameraOrientation = CATransform3DRotate(cameraOrientation, GLKMathDegreesToRadians(55), 1, 0, 0);
    [audienceCameraNode setTransform:cameraOrientation];
    
    // Now set position in world coords rather than translate.
    [audienceCameraNode setPosition: SCNVector3Make(-800, -400, 4200)];
    
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
    
    // Add in floor, as a visual cue for setting camera
    
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
    for (NSUInteger i = 0; i < subjects; i++)
    {
        subjectPositionArray[i] = [NSMutableArray arrayWithCapacity:numberOfLines];
        subjectRotationArray[i] = [NSMutableArray arrayWithCapacity:numberOfLines];
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
    
    // Add in guide lines for subjects
    for (NSUInteger i = 0; i < subjects; i++)
    {
        SCNNode *subjectNode = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:5 height:5 length:1000 chamferRadius:0]];
        
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
    
    [self setAttribute:@(startTime) forKey:SCNSceneStartTimeAttributeKey];
    [self setAttribute:@(finalTime) forKey:SCNSceneEndTimeAttributeKey];
    
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

    if ([[self attributeForKey:SCNSceneEndTimeAttributeKey] doubleValue] < 1.0)
    {
        NSLog(@"Loading dataset when mocap data not loaded. Aborting.");
    }
    
    NSArray *headerExpectedItems = @[@"AudienceID", @"TimeStamp", @"Light State While", @"Laugh State", @"Breathing Belt", @"Happy", @"Sad", @"Surprised", @"Angry", @"MouthOpen", @"Distance from Performer", @"Angle from Performer", @"Movement", @"isLookingAt", @"isBeingLookedAtByPerformer", @"isBeingLookedAtByAudienceMember"];
    
    NSScanner *scanner = [NSScanner scannerWithString:fileString];
    
    // Parse header row
    NSString *header = nil;
    [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&header];
    
    NSArray *headerItems = [header componentsSeparatedByString:@", "];
    
    if (![headerItems isEqual:headerExpectedItems])
    {
        NSLog(@"Headers not as expected");
        NSLog(@"Expected: %@", headerExpectedItems);
        NSLog(@"Found: %@", headerItems);
        return NO;
    }
    
    // TASK: Parse data
    
    // CSV data *has* spaces, no missing values.
    
    // Create arrays to hold position and rotation over time for all subjects
    
    CGFloat startTime = [[self attributeForKey:SCNSceneStartTimeAttributeKey] doubleValue];
    CGFloat endTime = [[self attributeForKey:SCNSceneEndTimeAttributeKey] doubleValue];
    CGFloat stepTime = 0.1;
    NSUInteger timeStampCount = (endTime - startTime) / stepTime;
    
    NSMutableArray *timeArray = [NSMutableArray arrayWithCapacity:timeStampCount];
    for (NSUInteger i = 0; i < timeStampCount; ++i)
    {
        [timeArray addObject:@(startTime + i*stepTime)];
    }
    
    NSArray *audienceNodes = [[self rootNode] childNodesPassingTest:^BOOL(SCNNode *child, BOOL *stop) {
        return [[child name] hasPrefix:@"Audience"];
    }];
    
    NSMutableDictionary *audienceData = [NSMutableDictionary dictionaryWithCapacity:[audienceNodes count]];
    for (SCNNode *node in audienceNodes)
    {
        NSMutableDictionary *subjectData = [NSMutableDictionary dictionaryWithCapacity:10];
        [subjectData setObject:[NSMutableArray arrayWithCapacity:timeStampCount] forKey:@"lightState"];
        [subjectData setObject:[NSMutableArray arrayWithCapacity:timeStampCount] forKey:@"laughState"];
        [subjectData setObject:[NSMutableArray arrayWithCapacity:timeStampCount] forKey:@"breathingBelt"];
        [subjectData setObject:[NSMutableArray arrayWithCapacity:timeStampCount] forKey:@"happiness"];
        
        for (NSString* key in subjectData)
        {
            NSMutableArray *array = [subjectData objectForKey:key];
            for (NSUInteger i = 0; i < timeStampCount; ++i)
            {
                [array addObject:[NSNull null]];
            }
        }
        
        NSString *nameWithoutSpace = [[node name] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
        [audienceData setObject:subjectData forKey:nameWithoutSpace];
    }

    // Setup scanner
    
    
    NSString * const lightStateLit = @"Lit";
    NSString * const lightStateUnlit = @"Unl";
    NSString * const lightStateUnknown = @"";
    
    NSMutableSet *missingSubjects = [NSMutableSet setWithCapacity:[audienceData count]];
    
    // Can't scan through directly as some numerical values are 'n/a', so take line and split into array
    NSString *line = nil;
    NSCharacterSet *newLine = [NSCharacterSet newlineCharacterSet];
    
    while ([scanner scanUpToCharactersFromSet:newLine intoString:&line])
    {
        NSArray *entries = [line componentsSeparatedByString:@", "];
        
        NSString *subject = entries[0];
        CGFloat time = [entries[1] doubleValue];
        NSUInteger timeIndex = round(((time - startTime) / stepTime));
        //NSLog(@"time %@ gets via index %@", entries[1], timeArray[timeIndex]);
        
        NSString* lightState;
        if ([entries[2] hasPrefix:lightStateLit]) lightState = lightStateLit;
        else if ([entries[2] hasPrefix: lightStateUnlit]) lightState = lightStateUnlit;
        else lightState = lightStateUnknown;
        
        
        NSDictionary *subjectData = [audienceData objectForKey:subject];
        if (!subjectData)
        {
            [missingSubjects addObject:subject];
            continue;
        }
        
        NSMutableArray *lightStateArray = [subjectData objectForKey:@"lightState"];
        [lightStateArray replaceObjectAtIndex:timeIndex withObject:lightState];
    }
    
    if ([missingSubjects count] > 0)
    {
        NSLog(@"Data omitted: scene missing subjects: %@", missingSubjects);
    }

    return YES;
}

@end
