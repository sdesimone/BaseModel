//
//  BaseModel.m
//
//  Version 2.1
//
//  Created by Nick Lockwood on 25/06/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//
//  Get the latest version of BaseModel from either of these locations:
//
//  http://charcoaldesign.co.uk/source/cocoa#basemodel
//  https://github.com/nicklockwood/BaseModel
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "BaseModel.h"
#include <sys/xattr.h>


NSString *const BaseModelSharedInstanceUpdatedNotification = @"BaseModelSharedInstanceUpdatedNotification";


@implementation BaseModel

@synthesize uniqueID;

#pragma mark -
#pragma mark Private utility methods

+ (NSString *)resourceFilePath:(NSString *)path
{
    //check if the path is a full path or not
    if (![path isAbsolutePath])
    {
        return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:path];
    }
    return path;
}

+ (NSString *)resourceFilePath
{
    return [self resourceFilePath:[self resourceFile]];
}

+ (NSString *)saveFilePath:(NSString *)path
{
    //check if the path is a full path or not
    if (![path isAbsolutePath])
    {
        //get the path to the application support folder
        NSString *folder = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
        
#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
        
        //append application name on Mac OS
        NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
        folder = [folder stringByAppendingPathComponent:identifier];
        
#endif
        
        //create the folder if it doesn't exist
        if (![[NSFileManager defaultManager] fileExistsAtPath:folder])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:folder
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:NULL];
        }
        
        return [folder stringByAppendingPathComponent:path];
    }
    return path;
}

+ (NSString *)saveFilePath
{
    return [self saveFilePath:[self saveFile]];
}

#pragma mark -
#pragma mark Singleton behaviour

static NSMutableDictionary *sharedInstances = nil;

+ (void)setSharedInstance:(BaseModel *)instance
{
    if (![instance isKindOfClass:self])
    {
        [NSException raise:NSGenericException format:@"setSharedInstance: instance class does not match"];
    }
    sharedInstances = sharedInstances ?: [[NSMutableDictionary alloc] init];
    id oldInstance = [sharedInstances objectForKey:NSStringFromClass(self)];
    [sharedInstances setObject:instance forKey:NSStringFromClass(self)];
    if (oldInstance)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:BaseModelSharedInstanceUpdatedNotification object:oldInstance];
    }
}

+ (BOOL)hasSharedInstance
{
    return [sharedInstances objectForKey:NSStringFromClass(self)] != nil;
}

+ (id)sharedInstance
{
    sharedInstances = sharedInstances ?: [[NSMutableDictionary alloc] init];
    id instance = [sharedInstances objectForKey:NSStringFromClass(self)];
    if (instance == nil)
    {
        //load or create instance
        [self reloadSharedInstance];
        
        //get loaded instance
        instance = [sharedInstances objectForKey:NSStringFromClass(self)];
    }
    return instance;
}

+ (void)reloadSharedInstance
{
    id instance = nil;
    
    //try loading previously saved version
    instance = [self instanceWithContentsOfFile:[self saveFilePath]];   
    if (instance == nil)
    {
        //construct a new instance
        instance = [self instance];
    }
    
    //set singleton
    [self setSharedInstance:instance];
}

+ (NSString *)resourceFile
{
    //used for every instance
    return [NSStringFromClass(self) stringByAppendingPathExtension:@"plist"];
}

+ (NSString *)saveFile
{
    //used to save shared (singleton) instance
    return [NSStringFromClass(self) stringByAppendingPathExtension:@"plist"];
}

- (void)save
{
    if ([sharedInstances objectForKey:NSStringFromClass([self class])] == self)
    {
        //shared (singleton) instance
        [self writeToFile:[[self class] saveFilePath] atomically:YES];
    }
    else
    {
        //no save implementation
        [NSException raise:NSGenericException format:@"Unable to save object, save method not implemented"];
    }
}

#pragma mark -
#pragma mark Default constructors

- (void)setUp
{
    //override this
}

+ (id)instance
{
    return AH_AUTORELEASE([[self alloc] init]);
}

static BOOL loadingFromResourceFile = NO;

- (id)init
{
    @synchronized ([BaseModel class])
    {
        if (!loadingFromResourceFile)
        {
            //attempt to load from resource file
            loadingFromResourceFile = YES;
            id object = [[[self class] alloc] initWithContentsOfFile:[[self class] resourceFilePath]];
            loadingFromResourceFile = NO;
            if (object)
            {
                AH_RELEASE(self);
                self = object;
                return self;
            }
        }
        if ((self = [super init]))
        {
            
#ifdef DEBUG
            if ([self class] == [BaseModel class])
            {
                [NSException raise:NSGenericException format:@"BaseModel class is abstract and should be subclassed rather than instantiated directly"];
            }
#endif
            [self setUp];
        }
        return self;
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [self init]))
    {
        if ([self respondsToSelector:@selector(setWithCoder:)])
        {
            [self setWithCoder:aDecoder];
        }
        else
        {
            [NSException raise:NSGenericException
                        format:@"-setWithCoder: not implemented"];
        }
    }
    return self;
}

+ (id)instanceWithDictionary:(NSDictionary *)dict
{
    //return nil if dict is nil
    return dict? AH_AUTORELEASE([[self alloc] initWithDictionary:dict]): nil;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
    if ((self = [self init]))
    {
        if ([self respondsToSelector:@selector(setWithDictionary:)])
        {
            [self setWithDictionary:dict];
        }
        else
        {
            [NSException raise:NSGenericException
                        format:@"setWithDictionary: not implemented"];
        }
    }
    return self;
}

+ (id)instanceWithArray:(NSArray *)array
{
    //return nil if array is nil
    return array? AH_AUTORELEASE([[self alloc] initWithArray:array]): nil;
}

- (id)initWithArray:(NSArray *)array
{
    if ((self = [self init]))
    {
        if ([self respondsToSelector:@selector(setWithArray:)])
        {
            [self setWithArray:array];
        }
        else
        {
            [NSException raise:NSGenericException format:@"setWithArray: not implemented"];
        }
    }
    return self;
}

+ (id)instanceWithContentsOfFile:(NSString *)filePath
{
    //check if the path is a full path or not
    NSString *path = filePath;
    if (![path isAbsolutePath])
    {
        //try resources
        path = [self resourceFilePath:filePath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            //try application support
            path = [self saveFilePath:filePath];
        }
    }

    return AH_AUTORELEASE([[self alloc] initWithContentsOfFile:path]);
}

- (id)initWithContentsOfFile:(NSString *)filePath
{
    static NSCache *cachedResourceFiles = nil;
    if (cachedResourceFiles == nil)
    {
        cachedResourceFiles = [[NSCache alloc] init];
    }
    
    //check cache for existing instance
    //only cache files inside the main bundle as they are immutable 
    BOOL isResourceFile = [filePath hasPrefix:[[NSBundle mainBundle] bundlePath]];
    if (isResourceFile)
    {
        id object = [cachedResourceFiles objectForKey:filePath];
        if (object)
        {
            AH_RELEASE(self);
            return ((self = (object == [NSNull null])? nil: AH_RETAIN(object)));
        }
    }
    
    //load the file
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    //attempt to deserialise data as a plist
    id object = nil;
    if (data)
    {
        NSPropertyListFormat format;
        if ([NSPropertyListSerialization respondsToSelector:@selector(propertyListWithData:options:format:error:)])
        {
            object = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format error:NULL];
        }
        else
        {
            object = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:&format errorDescription:NULL];
        }
    }
        
    //success?
    if (object)
    {
        //check if object is an NSCoded unarchive
        if ([object respondsToSelector:@selector(objectForKey:)] && [object objectForKey:@"$archiver"])
        {
            object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            if ([object isKindOfClass:[self class]])
            {
                //return object
                AH_RELEASE(self);
                return ((self = AH_RETAIN(object)));
            }
        }
        else if (isResourceFile)
        {
            //cache for next time
            [cachedResourceFiles setObject:object forKey:filePath];
        }
        
        if ([object isKindOfClass:[NSDictionary class]])
        {
            //load as dictionary
            return ((self = [self initWithDictionary:object]));
        }
        else if ([object isKindOfClass:[NSArray class]])
        {
            //load as array
            return ((self = [self initWithArray:object]));
        }
        else
        {
            //invalid
            [NSException raise:NSGenericException format:@"Attempted to load %@ as %@", [object class], [self class]];
        }
    }
    else if (isResourceFile)
    {
        //store null for non-existent files to improve performance next time
        [cachedResourceFiles setObject:[NSNull null] forKey:filePath];
    }
    
    //failed to load
    AH_RELEASE(self);
    return ((self = nil));
}

- (void)writeToFile:(NSString *)path atomically:(BOOL)atomically
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    [data writeToFile:[[self class] saveFilePath:path] atomically:YES];
}

- (NSString *)uniqueID
{
    if (uniqueID == nil)
    {
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        uniqueID = AH_RETAIN(CFBridgingRelease(CFUUIDCreateString(NULL, uuid)));
        CFRelease(uuid);
    }
    return uniqueID;
}

- (void)dealloc
{
    AH_RELEASE(uniqueID);
    AH_SUPER_DEALLOC;
}

@end