#import <Foundation/NSObject.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSDictionary.h>

@protocol NSFetchRequestResult <NSObject>
@end

@interface NSNumber (NSFetchRequestResult) <NSFetchRequestResult>
@end

@interface NSDictionary (NSFetchRequestResult) <NSFetchRequestResult>
@end
