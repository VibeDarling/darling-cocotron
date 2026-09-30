#import <AppKit/AppKit.h>
#include <assert.h>
#include <stdio.h>
@interface ResizingAccessory : NSView { @public unsigned layouts; }
@end
@implementation ResizingAccessory
- (void)layout { layouts++; [super layout]; [self setFrameSize:NSMakeSize(200,80)]; }
@end
int main(void) {
 @autoreleasepool {
  [NSApplication sharedApplication];
  NSAlert *alert=[NSAlert new];
  ResizingAccessory *view=[[ResizingAccessory alloc] initWithFrame:NSMakeRect(0,0,10,2)];
  [alert setMessageText:@"Accessory size test"];[alert addButtonWithTitle:@"OK"];
  [alert setAccessoryView:view];[alert layout];
  assert(view->layouts==1);
  assert([view frame].size.width==200 && [view frame].size.height==80);
  NSRect bounds=[[[alert window] contentView] bounds];
  assert(NSMinY([view frame])>=0 && NSMaxY([view frame])<=NSMaxY(bounds));
  assert(NSMinY([view frame])>=NSMaxY([[[alert buttons] objectAtIndex:0] frame]));
  [alert layout]; assert(view->layouts==1);
  [view release];[alert release];puts("PASS alert measures laid-out accessory without overlapping buttons");
 }
 return 0;
}
