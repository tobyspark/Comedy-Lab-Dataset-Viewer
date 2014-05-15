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

#define kCLDdatumPerSubject 6

@implementation CLDScene

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

+ (SCNScene *)sceneWithComedyLabMocapURL:(NSURL *)url error:(NSError **)error
{
    SCNScene *scene = nil;
    
    NSString *fileString = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];

    if (fileString)
    {
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
            return nil;
        }
        
        // Parse header row
        NSString *header = nil;
        [scanner setScanLocation:0];
        [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&header];
        
        NSArray *headerItems = [header componentsSeparatedByString:@","];
        
        if (![headerItems[0] isEqualToString:@"Time"])
        {
            NSLog(@"First header column not 'Time', aborting");
            return nil;
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
            }
            else
            {
                data[dataColumn] = datum;
                
                dataColumn++;
                
                // Move onto next subject
                if (dataColumn >= kCLDdatumPerSubject)
                {
                    subjectPositionArray[subject][i] = [NSValue valueWithSCNVector3:SCNVector3Make(data[0], data[1], data[2])];
                    
                    // FIXME: Euler to Angle-Axis, this is placeholder
                    subjectRotationArray[subject][i] = [NSValue valueWithSCNVector4:SCNVector4Make(data[3], data[4], data[5], M_PI_2)];
                    
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
        
        // TASK: Construct scene
        
        // Create empty scene
        
        scene = [SCNScene scene];

        // Add in cameras. Two that were actually in experiment, to align onto video. One to use as a roving eye. Values here are eyeballed.
        
        SCNCamera *audienceCamera = [SCNCamera camera];
        audienceCamera.automaticallyAdjustsZRange = YES;
        
        SCNNode *audienceCameraNode = [SCNNode node];
        audienceCameraNode.name = @"Camera - Audience";
        audienceCameraNode.position = SCNVector3Make(0, 0, 3000); // a guess for now
        audienceCameraNode.rotation = SCNVector4Make(1, 0, 0, GLKMathDegreesToRadians(30));
        [audienceCameraNode setCamera:audienceCamera];
        
        [scene.rootNode addChildNode:audienceCameraNode];
        
        SCNCamera *performerCamera = [SCNCamera camera];
        performerCamera.automaticallyAdjustsZRange = YES;
        
        SCNNode *performerCameraNode = [SCNNode node];
        performerCameraNode.name = @"Camera - Performer";
        performerCameraNode.position = SCNVector3Make(6000, 0, 2000); // a guess for now
        performerCameraNode.rotation = SCNVector4Make(1, 0, 0, GLKMathDegreesToRadians(30));
        [performerCameraNode setCamera:performerCamera];
        
        [scene.rootNode addChildNode:performerCameraNode];
        
        SCNCamera *orthoCamera = [SCNCamera camera];
        orthoCamera.automaticallyAdjustsZRange = YES;
        orthoCamera.usesOrthographicProjection = YES;
        orthoCamera.orthographicScale = 3000;
        
        SCNNode *orthoCameraNode = [SCNNode node];
        orthoCameraNode.name = @"Camera - Orthographic";
        orthoCameraNode.position = SCNVector3Make(2000, 0, 2000); // a guess for now
        orthoCameraNode.rotation = SCNVector4Make(0, 0, 1, GLKMathDegreesToRadians(90));
        [orthoCameraNode setCamera:orthoCamera];
        
        [scene.rootNode addChildNode:orthoCameraNode];
        
        // Add in subjects: an arrow with position and rotation set over time.
        
        for (NSUInteger i = 0; i < subjects; i++)
        {
            NSString *columnHeader = headerItems[1 + i*kCLDdatumPerSubject];
            columnHeader = [columnHeader componentsSeparatedByString:@"/"][0];
            columnHeader = [columnHeader componentsSeparatedByString:@"_Hat"][0];
            
            SCNNode *subjectNode = [SCNNode node];
            [subjectNode setName:columnHeader];
            [subjectNode addChildNode:[CLDScene arrow]];
            
            CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
            positionAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
            positionAnimation.duration = finalTime;
            positionAnimation.removedOnCompletion = NO;
            positionAnimation.keyTimes = timeArray;
            positionAnimation.calculationMode = kCAAnimationDiscrete;
            positionAnimation.values = subjectPositionArray[i];
            positionAnimation.usesSceneTimeBase = YES; // HACK: AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions).
            [subjectNode addAnimation:positionAnimation forKey:@"fingers crossed for positions"];
            
            // Not added until a) position animation working and b) rotation is fixed from euler to angle-axis
            CAKeyframeAnimation *rotationAnimation = [CAKeyframeAnimation animationWithKeyPath:@"rotation"];
            rotationAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
            rotationAnimation.duration = finalTime;
            rotationAnimation.removedOnCompletion = NO;
            rotationAnimation.keyTimes = timeArray;
            rotationAnimation.calculationMode = kCAAnimationDiscrete;
            rotationAnimation.values = subjectRotationArray[i];
            rotationAnimation.usesSceneTimeBase = YES; // HACK: AVSynchronizedLayer doesn't work properly with CAAnimation (SceneKit Additions).
            //[subjectNode addAnimation:rotationAnimation forKey:@"fingers crossed for rotations"];
            
            [scene.rootNode addChildNode:subjectNode];
        }
    }
    
    return scene;
}

@end
