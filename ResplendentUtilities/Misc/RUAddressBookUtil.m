//
//  AddressBookUtil.m
//  Albumatic
//
//  Created by Benjamin Maer on 2/4/13.
//  Copyright (c) 2013 Resplendent G.P. All rights reserved.
//

#import "RUAddressBookUtil.h"
#import <AddressBook/AddressBook.h>
#import "RUConstants.h"

typedef enum {
    RUAddressBookUtilABMultiValueRefTypeUnknown,
    RUAddressBookUtilABMultiValueRefTypeNSString,
    RUAddressBookUtilABMultiValueRefTypeArray
}RUAddressBookUtilABMultiValueRefType;

NSString* const kRUAddressBookUtilHasAskedUserForContacts = @"kRUAddressBookUtilHasAskedUserForContacts";

void kRUAddressBookUtilAddPersonPropertiesArrayToPersonPropertiesDictionary(CFTypeRef personPropertiesRecord, NSMutableDictionary* personPropertyDictionary,NSString* phoneProperty);

ABPropertyID abMultiValueRefForPersonWithPropertyType(kRUAddressBookUtilPhonePropertyType propertyType);
RUAddressBookUtilABMultiValueRefType abMultiValueRefTypeForPersonWithPropertyType(kRUAddressBookUtilPhonePropertyType propertyType);

static NSMutableArray* sharedInstances;

@interface RUAddressBookUtil () <UIAlertViewDelegate>

@property (nonatomic, strong) RUAddressBookUtilAskForPermissionsCompletionBlock alertViewCompletion;

+(BOOL)usesNativePermissions;

@end



@interface RUAddressBookUtil (UserDefaults)

+(NSNumber*)cachedHasAskedUserForContacts;
+(void)setCachedHasAskedUserForContacts:(NSNumber*)number;

@end




@implementation RUAddressBookUtil

#pragma mark - UIAlertViewDelegate methods
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    BOOL allowedPermission = (buttonIndex != alertView.cancelButtonIndex);

    [RUAddressBookUtil setCachedHasAskedUserForContacts:@(allowedPermission)];
    _alertViewCompletion(NO,allowedPermission);
    _alertViewCompletion = nil;

    [sharedInstances removeObject:self];
}

#pragma mark - C methods
void kRUAddressBookUtilAddPersonPropertiesArrayToPersonPropertiesDictionary(CFTypeRef personPropertiesRecord, NSMutableDictionary* personPropertyDictionary,NSString* phoneProperty)
{
    CFIndex personPropertiesCount = ABMultiValueGetCount(personPropertiesRecord);
    
    NSMutableArray* personPropertiesArray = [NSMutableArray array];
    
    for (int phoneIndex = 0; phoneIndex < personPropertiesCount; phoneIndex++)
    {
        NSString* personProperty = (__bridge NSString*)ABMultiValueCopyValueAtIndex(personPropertiesRecord, phoneIndex);

        if (personProperty)
            [personPropertiesArray addObject:personProperty];
    }
    
    if (personPropertiesArray.count)
        [personPropertyDictionary setObject:personPropertiesArray forKey:phoneProperty];
}

RUAddressBookUtilABMultiValueRefType abMultiValueRefTypeForPersonWithPropertyType(kRUAddressBookUtilPhonePropertyType propertyType)
{
    switch (propertyType)
    {
        case kRUAddressBookUtilPhonePropertyTypeEmail:
        case kRUAddressBookUtilPhonePropertyTypePhone:
            return RUAddressBookUtilABMultiValueRefTypeArray;

        case kRUAddressBookUtilPhonePropertyTypeFirstName:
        case kRUAddressBookUtilPhonePropertyTypeLastName:
            return RUAddressBookUtilABMultiValueRefTypeNSString;
            break;
    }

    RUDLog(@"unknown property type %i",propertyType);
    return RUAddressBookUtilABMultiValueRefTypeUnknown;
}
ABPropertyID abMultiValueRefForPersonWithPropertyType(kRUAddressBookUtilPhonePropertyType propertyType)
{
    switch (propertyType)
    {
        case kRUAddressBookUtilPhonePropertyTypeEmail:
            return kABPersonEmailProperty;
            break;

        case kRUAddressBookUtilPhonePropertyTypePhone:
            return kABPersonPhoneProperty;
            break;

        case kRUAddressBookUtilPhonePropertyTypeFirstName:
            return kABPersonFirstNameProperty;
            break;

        case kRUAddressBookUtilPhonePropertyTypeLastName:
            return kABPersonLastNameProperty;
            break;
    }

    [NSException raise:NSInvalidArgumentException format:@"unhandled property type %i",propertyType];
}

#pragma mark - Static methods
+(BOOL)usesNativePermissions
{
    return (ABAddressBookRequestAccessWithCompletion != nil);
}

+(void)askUserForPermissionWithCompletion:(RUAddressBookUtilAskForPermissionsCompletionBlock)completion
{
    ABAddressBookRef addressbook = ABAddressBookCreate();

    if ([self usesNativePermissions])
    {
        if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined)
        {
            ABAddressBookRequestAccessWithCompletion(addressbook, ^(bool granted, CFErrorRef error) {
                // First time access has been granted, add the contact
                if (granted)
                    RUDLog(@"got permission");
                else
                    RUDLog(@"rejected");
                
                if (completion)
                    completion(NO,granted);
            });
        }
        else
        {
            if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
            {
                if (completion)
                    completion(YES,YES);
            }
            else
            {
                if (completion)
                    completion(YES,NO);
            }
        }
    }
    else
    {
        NSNumber* hasAskedForPermission = [self cachedHasAskedUserForContacts];
        if (hasAskedForPermission)
        {
            completion(YES,hasAskedForPermission.boolValue);
        }
        else
        {
            RUAddressBookUtil* addressBookUtilInstance = [RUAddressBookUtil new];
            [addressBookUtilInstance setAlertViewCompletion:completion];
            
            if (!sharedInstances)
                sharedInstances = [NSMutableArray array];
            
            [sharedInstances addObject:addressBookUtilInstance];
            
            [[[UIAlertView alloc] initWithTitle:@"Albumatic Would Like to Access Your Contacts" message:nil delegate:addressBookUtilInstance cancelButtonTitle:@"Don't Allow" otherButtonTitles:@"OK", nil]show];
        }
    }
}

//phoneProperties must be an array of ABPropertyID types
+(NSDictionary*)getArraysFromAddressBookWithPhonePropertyTypes:(NSArray*)phoneProperties
{
    ABAddressBookRef addressbook = ABAddressBookCreate();

    if(addressbook)
    {
        if ([self usesNativePermissions])
        {
            if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
            {
                // The user has previously given access, add the contact
                RUDLog(@"has permission");
            }
            else
            {
                RUDLog(@"previously rejected permission");
                return nil;
            }
        }
        else
        {
            NSNumber* askedPermission = [self cachedHasAskedUserForContacts];

            if (!(askedPermission && askedPermission.boolValue))
                return nil;
        }

        NSMutableDictionary* arrayDictionary = [NSMutableDictionary dictionaryWithCapacity:phoneProperties.count];
        
        //Add the arrays to the dictionary
        for (NSNumber* phoneProperty in phoneProperties)
        {
            [arrayDictionary setObject:[NSMutableArray array] forKey:phoneProperty.stringValue];
        }

        CFArrayRef people =  ABAddressBookCopyArrayOfAllPeople(addressbook);

        if( people )
        {
            CFIndex contactCount = CFArrayGetCount(people);
            
            for (int contantIndex = 0; contantIndex < contactCount; contantIndex++)
            {
                ABRecordRef person = CFArrayGetValueAtIndex(people, contantIndex);

                for (NSNumber* phoneProperty in phoneProperties)
                {
                    NSMutableArray* propArray = [arrayDictionary objectForKey:phoneProperty.stringValue];
                    ABMultiValueRef personProperties = (ABMultiValueRef)ABRecordCopyValue(person, abMultiValueRefForPersonWithPropertyType(phoneProperty.integerValue));

                    NSString* personProperty = nil;

                    CFIndex personPropertiesCount = ABMultiValueGetCount(personProperties);

                    for (int phoneIndex = 0; phoneIndex < personPropertiesCount; phoneIndex++)
                    {
                        personProperty = (__bridge NSString*)ABMultiValueCopyValueAtIndex(personProperties, phoneIndex);

                        if (personProperty)
                            [propArray addObject:personProperty];
                    }
                }
            }
        }

        return arrayDictionary;
    }
    else
    {
        RUDLog(@"no address book");
        return nil;
    }
}

//+(NSArray*)getDictionariesFromAddressBookWithPhonePropertyTypes:(NSArray*)phoneProperties
+(NSArray*)getObjectsFromAddressBookWithPhonePropertyTypes:(NSArray*)phoneProperties objectCreationBlock:(RUAddressBookUtilCreateObjectWithDictBlcok)objectCreationBlock
{
    if (!objectCreationBlock)
    {
        RUDLog(@"need to pass non nil objectCreationBlock");
        return nil;
    }

    ABAddressBookRef addressbook = ABAddressBookCreate();
    
    if(addressbook)
    {
        if ([self usesNativePermissions])
        {
            if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
            {
                // The user has previously given access, add the contact
            }
            else
            {
                RUDLog(@"previously rejected permission");
                return nil;
            }
        }
        else
        {
            NSNumber* askedPermission = [self cachedHasAskedUserForContacts];
            
            if (!(askedPermission && askedPermission.boolValue))
                return nil;
        }

        NSMutableArray* objectsArray = [NSMutableArray array];

        CFArrayRef people =  ABAddressBookCopyArrayOfAllPeople(addressbook);

        if( people )
        {
            CFIndex contactCount = CFArrayGetCount(people);

            for (int contantIndex = 0; contantIndex < contactCount; contantIndex++)
            {
                ABRecordRef person = CFArrayGetValueAtIndex(people, contantIndex);

                NSMutableDictionary* personPropertyDictionary = [NSMutableDictionary dictionary];
                for (NSNumber* phoneProperty in phoneProperties)
                {
                    CFTypeRef personPropertiesRecord = ABRecordCopyValue(person, abMultiValueRefForPersonWithPropertyType(phoneProperty.integerValue));

                    if (personPropertiesRecord)
                    {
                        RUAddressBookUtilABMultiValueRefType propType = abMultiValueRefTypeForPersonWithPropertyType(phoneProperty.integerValue);
                        
                        switch (propType)
                        {
                            case RUAddressBookUtilABMultiValueRefTypeNSString:
                                [personPropertyDictionary setObject:(__bridge NSString*)personPropertiesRecord forKey:phoneProperty.stringValue];
                                break;
                                
                            case RUAddressBookUtilABMultiValueRefTypeArray:
                                kRUAddressBookUtilAddPersonPropertiesArrayToPersonPropertiesDictionary(personPropertiesRecord, personPropertyDictionary,phoneProperty.stringValue);
                                break;
                                
                            case RUAddressBookUtilABMultiValueRefTypeUnknown:
                            default:
                                RUDLog(@"unknown type for phone property %@",phoneProperty);
                                break;
                        }
                    }
//                    NSString* personProperty = (__bridge NSString*)personPropertiesRecord;
//
//                    if ([personProperty isKindOfClass:[NSString class]])
//                    {
//                        [personPropertyDictionary setObject:personProperty forKey:phoneProperty];
//                    }
//                    else
//                    {
//                        CFIndex personPropertiesCount = ABMultiValueGetCount(personPropertiesRecord);
//
//                        NSMutableArray* personPropertiesArray = [NSMutableArray array];
//                        
//                        for (int phoneIndex = 0; phoneIndex < personPropertiesCount; phoneIndex++)
//                        {
//                            personProperty = (__bridge NSString*)ABMultiValueCopyValueAtIndex(personPropertiesRecord, phoneIndex);
//
//                            [personPropertiesArray addObject:personProperty];
//                        }
//
//                        if (personPropertiesArray.count)
//                            [personPropertyDictionary setObject:personPropertiesArray forKey:phoneProperty];
//                    }
                }

                id object = objectCreationBlock(personPropertyDictionary);
                if (object)
                {
                    [objectsArray addObject:object];
                }
            }
        }

        return objectsArray;
    }
    else
    {
        RUDLog(@"no address book");
        return nil;
    }
}

+(NSArray*)getContactsPhoneNumbersArray
{
    NSMutableArray* phoneNumbersArray = [NSMutableArray array];
    ABAddressBookRef addressbook = ABAddressBookCreate();
    if( addressbook )
    {
        ABRecordRef source = ABAddressBookCopyDefaultSource(addressbook);
        CFArrayRef people = ABAddressBookCopyArrayOfAllPeopleInSource(addressbook, source);

        if( people )
        {
            CFIndex contactCount = CFArrayGetCount(people);
            
            for (int contantIndex = 0; contantIndex < contactCount; contantIndex++)
            {
                ABRecordRef person = CFArrayGetValueAtIndex(people, contantIndex);
                ABMultiValueRef phoneNumbers = (ABMultiValueRef)ABRecordCopyValue(person, kABPersonPhoneProperty);
                NSString* phoneNumber = nil;

                for (int phoneIndex = 0; phoneIndex < ABMultiValueGetCount(phoneNumbers); phoneIndex++)
                {
//                    phoneNumberLabel = (__bridge NSString *)ABMultiValueCopyLabelAtIndex(phoneNumbers, phoneIndex);
//                    RUDLog(@"phoneNumberLabel: %@",phoneNumberLabel);
                    phoneNumber = (__bridge NSString*)ABMultiValueCopyValueAtIndex(phoneNumbers, phoneIndex);

                    if (phoneNumber)
                        [phoneNumbersArray addObject:phoneNumber];

//                    if([phoneNumberLabel isEqualToString:(NSString *)kABPersonPhoneMobileLabel]) {
//                        NSLog(@"mobile:");
//                        RUDLog(@"phoneNumber: %@",phoneNumber);
//                    } else if ([phoneNumberLabel isEqualToString:(NSString*)kABPersonPhoneIPhoneLabel]) {
//                        NSLog(@"iphone:");
//                    } else if ([phoneNumberLabel isEqualToString:(NSString*)kABPersonPhonePagerLabel]) {
//                        NSLog(@"pager:");
//                    }
                }
            }
        }
    }

    RUDLog(@"phoneNumbersArray: %@",phoneNumbersArray);
    return phoneNumbersArray;
}

@end



@implementation RUAddressBookUtil (UserDefaults)

+(NSNumber*)cachedHasAskedUserForContacts
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kRUAddressBookUtilHasAskedUserForContacts];
}

+(void)setCachedHasAskedUserForContacts:(NSNumber*)number
{
    if (!number)
        [NSException raise:NSInvalidArgumentException format:@"Can't send nil number"];

    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:number forKey:kRUAddressBookUtilHasAskedUserForContacts];
    [userDefaults synchronize];
}

@end


