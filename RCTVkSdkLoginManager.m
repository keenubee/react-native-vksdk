#import "RCTVkSdkLoginManager.h"
#import <RCTUtils.h>
#import <RCTConvert.h>

@implementation RCTVkSdkLoginManager
{
    VKSdk *_sdkInstance;
    RCTResponseSenderBlock callback;
    
    VKShareDialogController *_shareDialogController;
    RCTResponseSenderBlock shareCallback;
}

static NSString *const ALL_USER_FIELDS = @"id,first_name,last_name,sex,bdate,city,country,photo_50,photo_100,photo_200_orig,photo_200,photo_400_orig,photo_max,photo_max_orig,online,online_mobile,lists,domain,has_mobile,contacts,connections,site,education,universities,schools,can_post,can_see_all_posts,can_see_audio,can_write_private_message,status,last_seen,common_count,relation,relatives,counters";

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (instancetype)init
{
    if ((self = [super init])) {
        NSString *VkAppID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"VkAppID"];
        NSLog(@"RCTVkSdkLoginManager starts with ID %@", VkAppID);
        
        _sdkInstance = [VKSdk initializeWithAppId:VkAppID];
        [_sdkInstance registerDelegate:self];
        [_sdkInstance setUiDelegate:self];
    }
    return self;
}

#pragma mark RN Export

RCT_EXPORT_METHOD(authorize:(RCTResponseSenderBlock)jsCallback)
{
    NSLog(@"RCTVkSdkLoginManager#authorize");
    self->callback = jsCallback;
    [self _authorize];
};

RCT_EXPORT_METHOD(logout)
{
    NSLog(@"RCTVkSdkLoginManager#logout");
    [VKSdk forceLogout];
};

RCT_EXPORT_METHOD(callMethodWithParams:(NSString *)methodName
                  andParameters:(NSDictionary *)parameters
                  andJsCallback:(RCTResponseSenderBlock)jsCallback
                  )
{
    NSLog(@"methodName: %@, params: %@", methodName, parameters);
    
    self->callback = jsCallback;
    VKRequest *request = [VKRequest requestWithMethod:methodName andParameters:parameters];
    
    [request executeWithResultBlock:^(VKResponse *response) {
        NSLog(@"Json result: %@", response.json);
        
        self->callback(@[[NSNull null], response.json]);
    } errorBlock:^(NSError * error) {
        if (error.code != VK_API_ERROR) {
            [error.vkError.request repeat];
        } else {
            NSLog(@"VK error: %@", error);
            
            NSDictionary *jsError = [self _NSError2JS:error];
            self->callback(@[jsError, [NSNull null]]);
        }
    }];
};

RCT_EXPORT_METHOD(showShareDialogWithSharingContent:(id)json callback:(RCTResponseSenderBlock)jsCallback) {
    NSLog(@"RCTVkSdkShare#show");
    
    self->shareCallback = jsCallback;
    
    VKShareDialogController *shareDialogController = [VKShareDialogController new];
    self->_shareDialogController = shareDialogController;
    
    __weak typeof(self) weakSelf = self;
    [shareDialogController setCompletionHandler:^(VKShareDialogController *dialog, VKShareDialogControllerResult result) {
        [weakSelf vkSdkShareDialogFinished:dialog withResult:result];
    }];
    
    NSDictionary *contentData = [RCTConvert NSDictionary:json];
    NSError *error;
    [self fillShareDialog:shareDialogController withContent:contentData error:&error];
    
    if (error) {
        self->shareCallback(@[@"image_load_failed", [NSNull null]]);
    }
    else {
        UIWindow *keyWindow = RCTSharedApplication().keyWindow;
        UIViewController *rootViewController = keyWindow.rootViewController;
        
        [rootViewController presentViewController:shareDialogController animated:YES completion:^{
            NSLog(@"RCTVkSdkShare#show-presented");
        }];
    }
};

RCT_EXPORT_METHOD(getFriendsListWithFields:(NSString *)userFields callback:(RCTResponseSenderBlock)jsCallback) {
    NSLog(@"RCTVkSdkFriendsList#get:%@", userFields);
    if (!jsCallback) {
        NSLog(@"RCTVkSdkFriendsList#get-nocallback");
        return;
    }
    
    VKRequest *friendsRequest = [[VKApi friends] get:@{VK_API_FIELDS : userFields ?: ALL_USER_FIELDS}];
    friendsRequest.requestTimeout = 10;
    
    [friendsRequest executeWithResultBlock:^(VKResponse *response) {
        NSLog(@"RCTVkSdkFriendsList#get-success");
        jsCallback(@[[NSNull null], response.json[@"items"]]);
    } errorBlock:^(NSError *error) {
        NSLog(@"RCTVkSdkFriendsList#get-error: %@", error);
        jsCallback(@[[self _NSError2JS:error], [NSNull null]]);
    }];
};

#pragma mark VKSdkDelegate

- (void)vkSdkAccessAuthorizationFinishedWithResult:(VKAuthorizationResult *)result {
    NSLog(@"vkSdkAccessAuthorizationFinishedWithResult %@", result);
    if (result.error) {
        NSDictionary *jsError = [self _NSError2JS:result.error];
        self->callback(@[jsError, [NSNull null]]);
        
    } else if (result.token) {
        NSDictionary *loginData = [self buildResponseData];
        self->callback(@[[NSNull null], loginData]);
        
    }
}

- (void)vkSdkUserAuthorizationFailed:(VKError *)error {
    NSLog(@"vkSdkUserAuthorizationFailed %@", error);
}

#pragma mark VKSdkUIDelegate

-(void) vkSdkNeedCaptchaEnter:(VKError*) captchaError
{
    NSLog(@"vkSdkNeedCaptchaEnter %@", captchaError);
    VKCaptchaViewController * vc = [VKCaptchaViewController captchaControllerWithError:captchaError];
    
    UIWindow *keyWindow = RCTSharedApplication().keyWindow;
    UIViewController *rootViewController = keyWindow.rootViewController;
    
    [vc presentIn:rootViewController];
}

- (void)vkSdkShouldPresentViewController:(UIViewController *)controller {
    NSLog(@"vkSdkShouldPresentViewController");
    UIWindow *keyWindow = RCTSharedApplication().keyWindow;
    UIViewController *rootViewController = keyWindow.rootViewController;
    
    [rootViewController presentViewController:controller animated:YES completion:nil];
}

#pragma mark VKShareDialogController callback

- (void)vkSdkShareDialogFinished:(VKShareDialogController *)dialog withResult:(VKShareDialogControllerResult)result {
    NSLog(@"vkSdkShareDialogFinished %ld", (long)result);
    if (self->shareCallback) {
        if (result == VKShareDialogControllerResultCancelled) {
            self->shareCallback(@[@"cancelled", [NSNull null]]);
            
        } else if (result == VKShareDialogControllerResultDone) {
            self->shareCallback(@[[NSNull null], @"done"]);
        }
    }
    [dialog dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - helpers

- (void)_authorize
{
    NSArray *SCOPE = @[VK_PER_FRIENDS, VK_PER_EMAIL, VK_PER_GROUPS, VK_PER_WALL, VK_PER_PHOTOS];
    [VKSdk wakeUpSession:SCOPE completeBlock:^(VKAuthorizationState state, NSError *error) {
        if (state == VKAuthorizationAuthorized) {
            // VKAuthorizationAuthorized - means a previous session is okay, and you can continue working with user data.
            NSLog(@"VKSdk wakeUpSession result VKAuthorizationAuthorized");
            NSDictionary *loginData = [self buildResponseData];
            self->callback(@[[NSNull null], loginData]);
            
        } else if (state == VKAuthorizationInitialized) {
            // VKAuthorizationInitialized – means the SDK is ready to work, and you can authorize user with `+authorize:` method. Probably, an old session has expired, and we wiped it out. *This is not an error.*
            
            NSLog(@"VKSdk wakeUpSession result VKAuthorizationInitialized");
            [VKSdk authorize:SCOPE];
            
        } else if (state == VKAuthorizationError) {
            // VKAuthorizationError - means some error happened when we tried to check the authorization. Probably, the internet connection has a bad quality. You have to try again later.
            
            NSLog(@"VKSdk wakeUpSession result VKAuthorizationError");
            self->callback(@[@"VKAuthorizationError", [NSNull null]]);
            
        } else if (error) {
            NSLog(@"VKSdk wakeUpSession error %@", error);
            NSDictionary *jsError = [self _NSError2JS:error];
            self->callback(@[jsError, [NSNull null]]);
        }
    }];
}

- (NSDictionary *)buildCredentials {
    NSDictionary *credentials = nil;
    VKAccessToken *token = [VKSdk accessToken];
    
    if (token) {
        credentials = @{
                        @"token" : token.accessToken,
                        @"userId" : token.userId,
                        @"permissions" : token.permissions,
                        @"email" : token.email
                        };
    }
    
    return credentials;
}

- (NSDictionary *)buildResponseData {
    NSDictionary *responseData = @{
                                   @"credentials": [self buildCredentials]
                                   };
    
    return responseData;
}

- (NSDictionary *)_NSError2JS:(NSError *)error {
    NSDictionary *jsError = @{
                              @"code" : [NSNumber numberWithLong:error.code],
                              @"domain" : error.domain,
                              @"description" : error.localizedDescription
                              };
    
    return jsError;
}

- (void)fillShareDialog:(VKShareDialogController *)shareDialog withContent:(NSDictionary *)content error:(NSError **)error {
    NSString *text = [RCTConvert NSString:content[@"text"]];
    if (text) {
        shareDialog.text = text;
    }
    
    NSURL *linkURL = [RCTConvert NSURL:content[@"linkURL"]];
    NSString *linkTitle = [RCTConvert NSString:content[@"linkTitle"]];
    if (linkURL) {
        shareDialog.shareLink = [[VKShareLink alloc] initWithTitle:linkTitle link:linkURL];
    }
    
    NSURL *imageURL = [RCTConvert NSURL:content[@"imageURL"]];
    if (imageURL) {
        NSLog(@"RCTVkSdkShare#downloadimage:%@", imageURL);
        
        NSError* downloadError;
        NSMutableURLRequest* urlRequest = [NSMutableURLRequest requestWithURL:imageURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:15];
        NSData *imageData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:nil error:&downloadError];
        
        if (downloadError) {
            NSLog(@"RCTVkSdkShare#downloadimage-failed:%@", downloadError);
            *error = downloadError;
        }
        else {
            NSLog(@"RCTVkSdkShare#downloadimage-downloaded");
            shareDialog.uploadImages = @[[VKUploadImage uploadImageWithImage:[UIImage imageWithData:imageData] andParams:[VKImageParameters jpegImageWithQuality:1.0]]];
        }
    }
}

@end
