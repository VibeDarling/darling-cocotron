// Constraints a nib decodes are owned by the nib's object list only (NSView does not decode
// NSViewConstraints, so nothing installs them), and outlets of the nib's objects still point at
// them. They must outlive the NSNib. The nib file is built with NSKeyedArchiver from stand-in
// classes whose class names are then rewritten to the nib classes.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static int constraintDeallocs;

@interface TestConstraint : NSLayoutConstraint <NSCoding>
@end
@implementation TestConstraint
- (void)dealloc
{
    constraintDeallocs++;
    [super dealloc];
}
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeObject:self.firstItem forKey:@"TestFirstItem"]; }
- (id)initWithCoder:(NSCoder *)coder
{
    NSView *view = [coder decodeObjectForKey:@"TestFirstItem"];
    // Returns an autoreleased object; the nib loader retains what it decodes.
    [super release];
    return [TestConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual
        toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5];
}
@end

// Interface Builder archives a constraint under the view that is the common ancestor of its items.
@interface TestView : NSView <NSCoding>
@property (retain) NSArray *archivedSubviews;
@property (retain) NSArray *archivedConstraints;
@end
@implementation TestView
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.archivedSubviews forKey:@"NSSubviews"];
    [coder encodeObject:self.archivedConstraints forKey:@"NSViewConstraints"];
}
- (id)initWithCoder:(NSCoder *)coder { return [super initWithCoder:coder]; }
@end

@interface TestObjectData : NSObject <NSCoding>
@property (retain) id root;
@property (retain) NSArray *objects;
@end
@implementation TestObjectData
- (void)encodeWithCoder:(NSCoder *)coder
{
    // The parent view is a top-level object; its subview and the constraint belong to it.
    NSArray *parents = @[self.root, self.objects[0], self.objects[0]];
    [coder encodeObject:self.root forKey:@"NSRoot"];
    [coder encodeObject:self.objects forKey:@"NSObjectsKeys"];
    [coder encodeObject:parents forKey:@"NSObjectsValues"];
}
- (id)initWithCoder:(NSCoder *)coder { return [self init]; }
@end

static NSNib *nib(void)
{
    TestView *parent = [[[TestView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)] autorelease];
    TestView *child = [[[TestView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)] autorelease];
    TestConstraint *constraint = [TestConstraint constraintWithItem:child attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual
        toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5];
    parent.archivedSubviews = @[child];
    parent.archivedConstraints = @[constraint];
    TestObjectData *data = [[TestObjectData new] autorelease];
    data.root = [NSMutableArray array];
    data.objects = @[parent, child, constraint];

    NSMutableData *archive = [NSMutableData data];
    NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:archive] autorelease];
    [archiver encodeObject:data forKey:@"IB.objectdata"];
    [archiver finishEncoding];

    NSMutableDictionary *plist = [NSPropertyListSerialization propertyListWithData:archive
        options:NSPropertyListMutableContainersAndLeaves format:NULL error:NULL];
    NSUInteger renamed = 0;
    for (id object in plist[@"$objects"])
    {
        if (![object isKindOfClass:[NSMutableDictionary class]] || ![object[@"$classname"] isEqualToString:@"TestObjectData"])
            continue;
        object[@"$classes"] = @[@"NSIBObjectData", @"NSObject"];
        object[@"$classname"] = @"NSIBObjectData";
        renamed++;
    }
    expect(renamed == 1, @"archive has the object data stand-in");
    NSData *bytes = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"constraints-%d.nib", getpid()]];
    expect([bytes writeToFile:path atomically:NO], @"nib written");
    NSNib *result = [[[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]] autorelease];
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    return result;
}

int main(void)
{
    @autoreleasepool
    {
        NSMutableArray *topLevel = [NSMutableArray array];
        NSView *parent = nil;
        NSNib *loader = nil;
        @autoreleasepool
        {
            loader = [nib() retain]; // the objects the archive was written from die with this pool
        }
        @autoreleasepool
        {
            NSObject *owner = [[NSObject new] autorelease];
            expect([loader instantiateNibWithExternalNameTable:@{NSNibOwner: owner, NSNibTopLevelObjects: topLevel}], @"the nib loads");
            constraintDeallocs = 0; // the alloc'd object the stand-in's -initWithCoder: replaces died during the load
            for (id object in topLevel)
                if ([object isKindOfClass:[TestView class]])
                    parent = [object retain];
            expect(parent != nil && topLevel.count == 1 && [[parent subviews] count] == 1,
                   [NSString stringWithFormat:@"the nib has its parent view with one subview: %@", topLevel]);
        }
        // The NSNib and its object list are gone; the view is not.
        [loader release];
        expect(constraintDeallocs == 0,
               [NSString stringWithFormat:@"a constraint of the nib outlives the nib, %d deallocated", constraintDeallocs]);
        // The constraint's first item leaves the view tree; the constraint stays with its common ancestor.
        NSView *child = [[[parent subviews] objectAtIndex:0] retain];
        [child removeFromSuperview];
        [child release];
        expect(constraintDeallocs == 0,
               [NSString stringWithFormat:@"a constraint outlives its removed first item, %d deallocated", constraintDeallocs]);
        expect([[parent constraints] count] == 0, @"the archived constraints are not installed");
        [topLevel removeAllObjects];
        [parent release];
        [parent release]; // the nib creates its top-level objects with an extra reference
        NSLog(@"PASS: nib constraints are owned by the view they are archived under");
    }
    return 0;
}
