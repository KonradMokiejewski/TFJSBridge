//
//  ViewController.m
//  TFJSBridge
//
//  Created by Konrad Mokiejewski on 18/03/2020.
//  Copyright © 2020 Konrad Mokiejewski. All rights reserved.
//

#import "ViewController.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController (){
    BOOL _modelReady;
    NSString* _tmpPicturePath;
    CGSize _pictureSize;
    NSUInteger _imgNo;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    /*photo from https://www.pexels.com */
    self.imageView.image = [UIImage imageNamed: @"horse.jpg"];
    _pictureSize = CGSizeMake(1280, 1919);
    
    // Do any additional setup after loading the view.
    NSString* jsSourcePath = [[NSBundle mainBundle] pathForResource:@"bridge"
                                                               ofType:@"js"];
    WKUserScript* userScript = [[WKUserScript alloc] initWithSource:jsSourcePath injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    WKUserContentController* userContentController = [[WKUserContentController alloc] init];
    [userContentController addUserScript:userScript];
    [userContentController addScriptMessageHandler:self name:@"TFJSBridge"];
    WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
    configuration.userContentController = userContentController;
    [configuration.preferences setValue:@YES forKey:@"allowFileAccessFromFileURLs"];
    
    CGRect rect = CGRectZero;
    _webView = [[WKWebView alloc] initWithFrame:rect configuration:configuration];
    
    _webView.navigationDelegate = self;
    
    NSString* htmlIndexPath = [[NSBundle mainBundle] pathForResource:@"index"
                                                            ofType:@"html"];
    NSURL* htmlIndexURL = [NSURL fileURLWithPath:htmlIndexPath];
    [_webView loadFileURL:htmlIndexURL allowingReadAccessToURL:htmlIndexURL];
    [self.view addSubview:_webView];
    
    self.predictionsCountLabel.text = @"";
}

- (IBAction)detect:(id)sender {
    [self detectRequest];
}

-(void)sendTakenPictureToHtml{
    //set image to html
    NSString* script = [NSString stringWithFormat:@"document.getElementById('img').src =\"%@\";",_tmpPicturePath];
    [_webView evaluateJavaScript:script completionHandler:^(id handle, NSError * error) {
        NSLog(@"error:%@",error.description);
    }];
}

-(void)detectRequest{
    if (_modelReady){
        NSString* script = @"runDetection();";
        [_webView evaluateJavaScript:script completionHandler:^(id handle, NSError * error) {
            NSLog(@"error:%@",error.description);
        }];
    }
    else{
        NSLog(@"Model is not ready");
    }
}

- (IBAction)takePhoto:(id)sender {
    UIImagePickerController* pickerController = [UIImagePickerController new];
    pickerController.delegate = self;
    pickerController.allowsEditing = YES;
    pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    [self presentViewController:pickerController animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)pickerController didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *chosenImage = info[UIImagePickerControllerEditedImage];
    self.imageView.image  = chosenImage;
    [pickerController dismissViewControllerAnimated:YES completion:NULL];
    //save picture to file
    NSData* imgData = UIImageJPEGRepresentation(chosenImage,1);
    _imgNo++;
    _tmpPicturePath = [[NSString alloc] initWithFormat:@"%@%@%lu.%@",NSTemporaryDirectory(),@"photoTaken",(unsigned long)_imgNo,@"jpg"];
    _pictureSize =chosenImage.size;
    NSURL* url = [[NSURL alloc] initFileURLWithPath:_tmpPicturePath];
    NSError* error = nil;
    [imgData writeToURL:url options:NSDataWritingAtomic error:&error];
    [self sendTakenPictureToHtml];
    self.imageView.layer.sublayers = nil;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)pickerController {
    [pickerController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message{
    
    NSArray* array = (NSArray*)message.body;
    PostType postType = ((NSNumber*)array[0]).intValue;
    switch (postType) {
        case PostTypePrepareModel:{
            NSDictionary* postTypeResult = (NSDictionary*)array[1];
            NSString* actionStatus = [postTypeResult objectForKey:@"status"];
            if ([actionStatus isEqualToString:@"ok"]){
                _modelReady = YES;
            }
        }
            break;
        case PostTypeGetPredisctions:{
            NSArray* predictions = array[1];
            [self handlePredictions:predictions];
        }
            break;
        default:
            break;
    }
}

-(void)handlePredictions:(NSArray*)predictions{
    for (NSDictionary* element in predictions) {
        NSArray* boundingBox = [element objectForKey:@"bbox"];
        NSString* className = [element objectForKey:@"class"];
        float score = [[element objectForKey:@"score"] floatValue];
        float xmin = [((NSString*)boundingBox[0]) floatValue]/_pictureSize.width;
        float ymin = [((NSString*)boundingBox[1]) floatValue]/_pictureSize.height;
        float width = [((NSString*)boundingBox[2]) floatValue]/_pictureSize.width;
        float height = [((NSString*)boundingBox[3]) floatValue]/_pictureSize.height;
        CGRect bboxRect = CGRectMake(xmin, ymin, width, height);
        NSString* description = [[NSString stringWithFormat:@"%@, %i",className,(int)(score*100)] stringByAppendingString:@"%"];
        [self drawRect:bboxRect text:description];
    }
    self.predictionsCountLabel.text = [NSString stringWithFormat:@"%lu objects detected",(unsigned long)predictions.count];
}

-(void) drawRect:(CGRect)boundingBox text:(NSString*)description{
    CGRect source =  AVMakeRectWithAspectRatioInsideRect(self.imageView.image.size, self.imageView.bounds);
    CGSize size = CGSizeMake(boundingBox.size.width * source.size.width,
                             boundingBox.size.height * source.size.height);
    CGPoint origin = CGPointMake(boundingBox.origin.x * source.size.width + source.origin.x,
                                 boundingBox.origin.y * source.size.height + source.origin.y);
    CAShapeLayer *outline = [CAShapeLayer layer];
    outline.frame = CGRectMake(origin.x, origin.y, size.width, size.height);
    outline.borderColor = [UIColor yellowColor].CGColor;
    outline.borderWidth = 1;
    
    [self.imageView.layer addSublayer:outline];
    
    CATextLayer*  label = [CATextLayer layer];
    label.fontSize = 12;
    label.allowsEdgeAntialiasing = true;
    label.alignmentMode = kCAAlignmentCenter;
    label.foregroundColor = [UIColor yellowColor].CGColor;
    label.string = description;
    label.frame = outline.frame;
    
    [self.imageView.layer addSublayer:label];
}

@end
