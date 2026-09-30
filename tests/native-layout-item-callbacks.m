#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <assert.h>
#include <stdio.h>
@interface NSView (NativeLayoutItemProbe)
- (id)nsli_superitem;
- (void)nsli_addConstraint:(NSLayoutConstraint*)constraint;
- (void)nsli_removeConstraint:(NSLayoutConstraint*)constraint;
- (NSArray*)nsli_installedConstraints;
- (NSArray*)constraints;
@end
int main(void) {
 @autoreleasepool {
  NSView *root=[[NSView alloc] initWithFrame:NSMakeRect(0,0,300,100)];
  NSView *owner=[[NSView alloc] initWithFrame:NSMakeRect(0,0,100,100)];
  NSView *child=[[NSView alloc] initWithFrame:NSMakeRect(0,0,10,10)];
  [root addSubview:owner]; [owner addSubview:child];
  assert([child nsli_superitem]==owner && [owner nsli_superitem]==root && ![root nsli_superitem]);
  Class cls=NSClassFromString(@"NSLayoutConstraint");
  printf("constraint_image=%s\n",class_getImageName(cls));
  NSLayoutConstraint *c=[[child leftAnchor] constraintEqualToAnchor:[owner leftAnchor] constant:10];
  [owner setNeedsLayout:NO];
  assert(c != nil);
  [c setActive:YES];
  assert([[owner constraints] count]==1 && [[root constraints] count]==0 && [owner needsLayout]);
  assert([[owner constraints] objectAtIndex:0]==c);
  [owner nsli_addConstraint:c]; [owner addConstraints:@[c]];
  assert([[owner nsli_installedConstraints] count]==1);
  NSArray *snapshot=[[owner constraints] retain];
  [owner setNeedsLayout:NO]; [owner nsli_removeConstraint:c];
  assert([[owner constraints] count]==0 && [snapshot count]==1 && [owner needsLayout]);
  [owner setNeedsLayout:NO]; [owner nsli_removeConstraint:c];
  assert(![owner needsLayout]);
  [snapshot release]; [child release]; [owner release]; [root release];
  puts("PASS native layout callbacks: ownership, storage, identity, snapshots and removal");
 }
 return 0;
}
