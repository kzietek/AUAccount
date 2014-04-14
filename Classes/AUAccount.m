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

// Notifications
NSString * const AUAccountDidLoginUserNotification      = @"AUAccountDidLoginUserNotification";
NSString * const AUAccountWillLogoutUserNotification    = @"AUAccountWillLogoutUserNotification";
NSString * const AUAccountDidLogoutUserNotification     = @"AUAccountDidLogoutUserNotification";
NSString * const AUAccountDidUpdateUserNotification     = @"AUAccountDidUpdateUserNotification";

// Private keys
NSString * const kAUAccountKey = @"kAUAccountKey";
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

- (id)init {
    self = [super init];
    if (self) {
        // get user dict
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSDictionary* dict = [userDefaults objectForKey:kAUAccountKey];
        
        // check if any account exist
        if (dict) {
            // get account informations
            _expirationDate = dict[kAUAccountExpirationDateKey];
            _loginDate = dict[kAUAccountLoginDateKey];
            _accountType = dict[kAUAccountTypeKey];
            
            // load user's data
            _user = [NSKeyedUnarchiver unarchiveObjectWithFile:[self _userDataStoragePath]];
        }
    }
    return self;
}

- (void)logout {

    // post notification with logout user object
    [[NSNotificationCenter defaultCenter] postNotificationName:AUAccountWillLogoutUserNotification
                                                        object:self.user];

    // fire clean up block
    if (self.logoutBlock) {
        self.logoutBlock(self, self.user);
    }
    
    // clean all account user data
    [self _cleanUserData];

    // post notification after logout data cleanup
    [[NSNotificationCenter defaultCenter] postNotificationName:AUAccountDidLogoutUserNotification
                                                        object:nil];
}

- (BOOL)updateUser:(id<NSSecureCoding>)user {
    // add updated user object
    BOOL successed = [NSKeyedArchiver archiveRootObject:user toFile:[self _userDataStoragePath]];

    // if archived user without any problems
    if (successed) {
        // update user data
        _user = user;
        
        // post notification with new user object
        [[NSNotificationCenter defaultCenter] postNotificationName:AUAccountDidUpdateUserNotification
                                                            object:user];
    }
    
    return successed;
}

- (void)registerAccountWithType:(NSString *)accounType {
    [self registerAccountWithAuthenticationToken:nil expirationDate:nil accountType:accounType error:NULL];
}

- (BOOL)registerAccountWithAuthenticationToken:(NSString *)token expirationDate:(NSDate *)expirationDate accountType:(NSString *)accounType error:(NSError *__autoreleasing *)error {
    NSParameterAssert(accounType);

    error = nil;
    
    // remove previous user data
    if ([self isLoggedIn]) {
        [self _cleanUserData];
    }

    // save authentication token in Keychain
    if ([token length] > 0) {
        [SSKeychain setPassword:token
                     forService:kServiceName
                        account:kAccountName
                          error:error];
    }
    
    if (!error) {
        // assing new values
        _expirationDate = expirationDate;
        _accountType = accounType;
        _loginDate = [NSDate date];
        
        // prepare dictionary to save
        NSMutableDictionary* dict = [NSMutableDictionary new];
        dict[kAUAccountLoginDateKey] = _loginDate;
        
        if ([accounType length] > 0) {
            dict[kAUAccountTypeKey] = accounType;
        }

        if (expirationDate) {
            dict[kAUAccountExpirationDateKey] = expirationDate;
        }
        
        // save user data to file
        BOOL success = [NSKeyedArchiver archiveRootObject:dict toFile:[self _userDataStoragePath]];

        // if archived user without any problems
        if (success) {
            // save account information to NSUserDefaults
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            [userDefaults setObject:dict forKey:kAUAccountKey];
            [userDefaults synchronize];
            
            // post notification with new user object
            [[NSNotificationCenter defaultCenter] postNotificationName:AUAccountDidLoginUserNotification
                                                                object:nil];
        }
        
        return success;
    }

    return NO;
}

- (BOOL)isLoggedIn {
    return (_loginDate != nil);
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
    // remove user data from file
    [[NSFileManager defaultManager] removeItemAtPath:[self _userDataStoragePath] error:nil];
    
    // remove data form NSUserDefaults
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAUAccountKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // clean user data
    _user = nil;
    _expirationDate = nil;
    _loginDate = nil;
}

- (NSString *)_userDataStoragePath {
    // get documents directory path
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    // add store file name
    return [documentsDirectory stringByAppendingPathComponent:@"AUAccount.usr"];
}

@end
