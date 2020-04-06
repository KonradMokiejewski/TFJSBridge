//
//  ViewController.h
//  TFJSBridge
//
//  Created by Konrad Mokiejewski on 18/03/2020.
//  Copyright © 2020 Konrad Mokiejewski. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

typedef enum{
    PostTypePrepareModel = 1,
    PostTypeGetPredisctions = 2
} PostType;

@interface ViewController : UIViewController<UIImagePickerControllerDelegate, UINavigationControllerDelegate,WKNavigationDelegate,WKScriptMessageHandler>{
    WKWebView* _webView;
}
@property (weak, nonatomic) IBOutlet UILabel *predictionsCountLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UIButton *photoButton;
- (IBAction)takePhoto:(id)sender;
@end

