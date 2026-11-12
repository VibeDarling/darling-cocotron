#import <CoreData/NSBatchDeleteRequest.h>

@interface NSBatchDeleteRequest (Private)
- (NSArray *)_objectIDs;
@end

@interface NSBatchDeleteResult (Private)
- (instancetype)_initWithResult:(id)result type:(NSBatchDeleteRequestResultType)type;
@end
