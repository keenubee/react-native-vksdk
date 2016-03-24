# react-native-vksdk

A wrapper around the [iOS VK (VKontakte) SDK](https://github.com/VKCOM/vk-ios-sdk) for React Native apps.

## Setup

### Wrapper settings

1). Install NPM package
```
npm install --save git+ssh://git@github.com:kohver/react-native-vksdk.git
```
Now jump to `/ios` folder.

2). Add to your `Podfile` (create it by `pod init`, if necessary)
```
pod 'VK-ios-sdk', :path => '../node_modules/react-native-vksdk/vk-ios-sdk'
```
then type `pod install`

3). Add `VkAppID` key to Info.plist
![image](/docs/plist.png)

4). Drag'n'drop `RCTVkSdkLoginManager.h` and `RCTVkSdkLoginManager.m` to your Libraries (without coping files, just click "Finish" button).
![image](/docs/add.png)

### Native VK SDK settings

1). Add import in `AppDelegate.h`
```diff
  ...
  #import <UIKit/UIKit.h>
+ #import <VKSdk.h>
  ...
```

2). Put this code to `AppDelegate.m`

```Objective-C
//iOS 9 workflow
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options {
    [VKSdk processOpenURL:url fromApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]];
    return YES;
}

//iOS 8 and lower
-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    [VKSdk processOpenURL:url fromApplication:sourceApplication];
    return YES;
}
```

Note: if you already have FaceBook SDK added and one of this methods returns `[FBSDKDelegate ...]` you can handle it:

```Objective-C
-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {

    [[FBSDKApplicationDelegate sharedInstance] application:application openURL:url sourceApplication:sourceApplication annotation:annotation];
    [VKSdk processOpenURL:url fromApplication:sourceApplication];
    return YES;
}
```

3). Add this to your Info.plist:

```
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>vk</string>
    <string>vk-share</string>
    <string>vkauthorize</string>
</array>
```

4). Setup URL schema of Your Application
    
To authorize via VK App you need to setup a url-schema for your application, which looks like vk+APP_ID (e.g. `vk1234567`).
There is [nice Twitter tutorial](https://dev.twitter.com/cards/mobile/url-schemes)

5). Run your app in xcode. Done!

## Usage

```js
var Vk = require('react-native-vksdk');

// authorize and get token
Vk.authorize()
    .then((result) => {
        // your code here
    }, (error) => {
        // your code here
    });
    
// logout
Vk.logout();
    
```
