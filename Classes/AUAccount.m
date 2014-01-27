//
//  AUAccount.m
//  Yapert
//
//  Created by Emil Wojtaszek on 07.12.2013.
//  Copyright (c) 2013 AppUnite.com. All rights reserved.
//

#import "AUAccount.h"

// Account Types
NSString * const AUAccountTypeCustom    = @"AUAccountTypeCustom";
NSString * const AUAccountTypeTwitter   = @"AUAccountTypeTwitter";
NSString * const AUAccountTypeFacebook  = @"AUAccountTypeFacebook";

// Notification
NSString * const AUAccountDidLoginUserWithSuccessNotification   = @"AUAccountDidLoginUserWithSuccessNotification";
NSString * const AUAccountDidLogoutUserWithSuccessNotification  = @"AUAccountDidLogoutUserWithSuccessNotification";
NSString * const AUAccountDidUpdateUserNotification             = @"AUAccountDidUpdateUserNotification";

// Private keys
NSString * const kAUAccountKey = @"kAUAccountKey";
NSString * const kAUAccountUserKey = @"kAUAccountUserKey";
NSString * const kAUAccountTypeKey = @"kAUAccountTypeKey";
NSString * const kAUAccountLoginDateKey = @"kAUAccountLoginDateKey";
NSString * const kAUAccountExpirationDateKey = @"kAUAccountExpirationDateKey";

#define kAccountName [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
#define kServiceName [[NSBundle mainBundle] bundleIdentifier]

@implementation AUAccount

+ (instancetype)account {
    static AUAccount* __sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[self alloc] init];
    });
    
    return __sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        // get user dict
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSDictionary* dict = [userDefaults objectForKey:kAUAccountKey];
        
        // check if any account exist
        if (dict) {
            _user = [NSKeyedUnarchiver unarchiveObjectWithData:dict[kAUAccountUserKey]];
            _expirationDate = dict[kAUAccountExpirationDateKey];
            _loginDate = dict[kAUAccountLoginDateKey];
            _accountType = dict[kAUAccountTypeKey];
        }
    }
    return self;
}

- (void)logout {

    // post notification with logout user object
    [[NSNotificationCenter defaultCenter] postNotificationName:AUAccountDidLogoutUserWithSuccessNotification
                                                        object:self.user];
    // fire clean up block
    if (self.logoutBlock) {
        self.logoutBlock(self, self.user);
    }
    
    // clean all account user data
    [self _cleanUserData];
}

- (void)updateUser:(id<NSCopying, NSCoding>)user {
    // update user data
    _user = user;
    
    // get previous saved user data
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary* dict = [[userDefaults objectForKey:kAUAccountKey] mutableCopy];

    // save new user data
    [dict setObject:[NSKeyedArchiver archivedDataWithRootObject:user]
             forKey:kAUAccountUserKey];
    
    // post notification with new user object
    [[NSNotificationCenter defaultCenter] postNotificationName:AUAccountDidUpdateUserNotification
                                                        object:user];
}

- (BOOL)loginWithUser:(id<NSCopying, NSCoding>)user authToken:(NSString *)token expirationDate:(NSDate *)expirationDate accountType:(NSString *)accounType error:(NSError *__autoreleasing *)error {
    NSParameterAssert(user);
    NSParameterAssert(token);
    NSParameterAssert(accounType);

    error = nil;
    
    // remove previou user data
    if ([self isLoggedIn]) {
        [self _cleanUserData];
    }

    // save authentication token in Keychain
    [SSKeychain setPassword:token
                 forService:kServiceName
                    account:kAccountName
                      error:error];
    
    if (!error) {
        // assing new values
        _user = user;
        _expirationDate = expirationDate;
        _accountType = accounType;
        
        // prepare dictionary to save
        NSMutableDictionary* dict = [NSMutableDictionary new];
        dict[kAUAccountLoginDateKey] = [NSDate date];
        
        if ([accounType length] > 0) {
            dict[kAUAccountTypeKey] = accounType;
        }

        if (expirationDate) {
            dict[kAUAccountExpirationDateKey] = expirationDate;
        }

        if (user) {
            dict[kAUAccountUserKey] = [NSKeyedArchiver archivedDataWithRootObject:user];
        }
        
        // save account to NSUserDefaults
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:dict forKey:kAUAccountKey];
        [userDefaults synchronize];
        
        // post notification with new user object
        [[NSNotificationCenter defaultCenter] postNotificationName:AUAccountDidLoginUserWithSuccessNotification
                                                            object:user];
        
        return YES;
    }

    return NO;
}

- (BOOL)isLoggedIn {
    return (_user != nil);
}


#pragma mark -
#pragma mark Getters

- (NSString *)authenticationToken:(NSError **)error {
    return [SSKeychain passwordForService:kServiceName
                                  account:kAccountName
                                    error:error];
}


#pragma mark -
#pragma mark Private

- (void)_cleanUserData {
    // remove data form NSUserDefaults
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAUAccountKey];
    
    // clean user data
    _user = nil;
    _expirationDate = nil;
    _loginDate = nil;
}

@end