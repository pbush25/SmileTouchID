//
//  SmileAuthenticator.m
//  TouchID
//
//  Created by ryu-ushin on 5/25/15.
//  Copyright (c) 2015 rain. All rights reserved.
//

#import "SmileAuthenticator.h"

#define kPasswordLength 4
#define kTouchIDIcon @"smile_Touch_ID"

static NSString *kDefaultReason = @"Unlock to access";
static NSString *kKeyChainObjectKey = @"v_Data";
static NSString *kStoryBoardName = @"SmileSettingVC";
static NSString *kSmileSettingNaviID = @"smileSettingsNavi";

@interface SmileAuthenticator()

@property (nonatomic, assign) LAPolicy policy;
@property (nonatomic, strong) LAContext * context;

@end


@implementation SmileAuthenticator{
    BOOL _isAuthenticated;
    BOOL _didReturnFromBackground;
    BOOL _isShowLogin;
}

#pragma mark -getter

-(NSInteger)passcodeDigit{
    if (!_passcodeDigit || _passcodeDigit < 0) {
        return kPasswordLength;
    } else {
        return _passcodeDigit;
    }
}

-(NSString *)touchIDIcon{
    if (!_touchIDIcon.length) {
        return kTouchIDIcon;
    } else {
        return _touchIDIcon;
    }
}


-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)logDismissAuthVCReason{
    NSString *reason;
    switch (self.securityType) {
        case INPUT_ONCE:
            reason = @"user turn password off";
            break;
            
        case INPUT_TWICE:
            reason = @"user turn password on";
            break;
            
        case INPUT_THREE:
            reason = @"user change password";
            break;
            
        case INPUT_TOUCHID:
            reason = @"user launch app";
            break;
            
        default:
            break;
    }
}

-(void)touchID_OR_PasswordAuthSuccess{
    if ([self.delegate respondsToSelector:@selector(userSuccessAuthentication)]) {
        [self.delegate userSuccessAuthentication];
    }
}

-(void)touchID_OR_PasswordAuthFail:(NSInteger)failCount{
    if ([self.delegate respondsToSelector:@selector(userFailAuthenticationWithCount:)]) {
        [self.delegate userFailAuthenticationWithCount:failCount];
    }
}

-(void)logPresentAuthVCReason{
    NSString *reason;
    switch (self.securityType) {
    case INPUT_ONCE:
        reason = @"user turn password off";
        break;
        
    case INPUT_TWICE:
        reason = @"user turn password on";
        break;
        
    case INPUT_THREE:
        reason = @"user change password";
        break;
        
    case INPUT_TOUCHID:
        reason = @"user launch app";
        break;
        
    default:
        break;
    }
}

-(void)presentAuthViewController{
    
    if (self.securityType != INPUT_TOUCHID) {
        _isAuthenticated = NO;
    }
    
    if (!_isAuthenticated) {
        
        [self logPresentAuthVCReason];
        
        BOOL isAnimated = YES;
        
        if (self.securityType == INPUT_TOUCHID) {
            isAnimated = NO;
        }
        
        //dimiss all presentedViewController, for example, if user is editing password
        if (self.rootVC.presentedViewController) {
            [self.rootVC.presentedViewController dismissViewControllerAnimated:NO completion:nil];
        }
        
        if ([self.delegate respondsToSelector:@selector(AuthViewControllerPresented)]) {
            [self.delegate AuthViewControllerPresented];
        }
        
        _isShowLogin = YES;
        
   
        
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:kStoryBoardName bundle: nil];
        
        UINavigationController *naviVC = [storyboard instantiateViewControllerWithIdentifier:kSmileSettingNaviID];
        
        [self.rootVC presentViewController:naviVC animated:isAnimated completion:nil];
    }
}

-(void)authViewControllerDismissed{
    if ([self.delegate respondsToSelector:@selector(AuthViewControllerDismssed)]) {
        [self.delegate AuthViewControllerDismssed];
    }
    
    _isAuthenticated = true;
    _isShowLogin = NO;
}

#pragma mark - NSNotificationCenter

-(void)configureNotification{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

-(void)appDidEnterBackground:(NSNotification*)notification{
    _isAuthenticated = NO;
    _didReturnFromBackground = YES;
}

-(void)appWillEnterForeground:(NSNotification*)notification{  
    if (_didReturnFromBackground && !_isShowLogin) {
        if ([SmileAuthenticator hasPassword]) {
            //show login vc
            self.securityType = INPUT_TOUCHID;
            [self presentAuthViewController];
        }
    }
}

+(SmileAuthenticator *)sharedInstance{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SmileAuthenticator alloc] init];
    });
    
    return sharedInstance;
}


-(instancetype)init{
    if (self = [super init]) {
        self.context = [[LAContext alloc] init];
        self.policy = LAPolicyDeviceOwnerAuthenticationWithBiometrics;
        self.localizedReason = kDefaultReason;
        self.keychainWrapper = [[SmileKeychainWrapper alloc] init];
        self.securityType = INPUT_TWICE;
        
        [self configureNotification];
    }
    return self;
}


+ (BOOL) canAuthenticateWithError:(NSError **) error
{
    if ([NSClassFromString(@"LAContext") class]) {
        if ([[SmileAuthenticator sharedInstance].context canEvaluatePolicy:[SmileAuthenticator sharedInstance].policy error:error]) {
            return YES;
        }
        return NO;
    }
    return NO;
}

-(void)authenticateWithSuccess:(AuthCompletionBlock)authSuccessBlock andFailure:(AuthErrorBlock)failureBlock{
    
    NSError *authError = nil;
    
    self.context = [[LAContext alloc] init];
    
    if ([SmileAuthenticator canAuthenticateWithError:&authError]) {
        [self.context evaluatePolicy:self.policy localizedReason:self.localizedReason reply:^(BOOL success, NSError *error) {
            if (success) {
                DispatchMainThread(^(){authSuccessBlock();});
            }
            
            else {
                switch (error.code) {
                    case LAErrorAuthenticationFailed:
                        
                        NSLog(@"LAErrorAuthenticationFailed");
                        
                        break;
                        
                    case LAErrorUserCancel:
                        
                        NSLog(@"LAErrorUserCancel");
                        
                        break;
                        
                    case LAErrorUserFallback:
                        
                        NSLog(@"LAErrorUserFallback");
                        
                        break;
                        
                    case LAErrorSystemCancel:
                        
                        NSLog(@"LAErrorSystemCancel");
                        
                        break;
                        
                    case LAErrorPasscodeNotSet:
                        
                        NSLog(@"LAErrorPasscodeNotSet");
                        
                        break;
                    
                    case LAErrorTouchIDNotAvailable:
                        
                        NSLog(@"LAErrorTouchIDNotAvailable");
                        
                        break;
                        
                    case LAErrorTouchIDNotEnrolled:
                        
                        NSLog(@"LAErrorTouchIDNotEnrolled");
                        
                        break;
                        
                    default:
                        break;
                }
                
                DispatchMainThread(^(){failureBlock((LAError) error.code);});
            }
        }];
    }
    
    else {
        failureBlock((LAError) authError.code);
    }
}


+(BOOL)hasPassword {
    
    if ([(NSString*)[[SmileAuthenticator sharedInstance].keychainWrapper myObjectForKey:kKeyChainObjectKey] length] > 0) {
        return YES;
    }
    
    return NO;
}

+(BOOL)isSamePassword:(NSString *)userInput{
    
    if ([userInput isEqualToString:[[SmileAuthenticator sharedInstance].keychainWrapper myObjectForKey:kKeyChainObjectKey]]) {
        return YES;
    }
    
    return NO;
}

-(void)userSetPassword:(NSString*)newPassword{
    
    [self.keychainWrapper mySetObject:newPassword forKey:(__bridge id)(kSecValueData)];
    [self.keychainWrapper writeToKeychain];
}

+(void)clearPassword{
    [[SmileAuthenticator sharedInstance].keychainWrapper resetKeychainItem];
    [[SmileAuthenticator sharedInstance].keychainWrapper writeToKeychain];
}

@end
