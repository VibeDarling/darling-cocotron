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

@interface Doc : NSObject
@property(copy) NSString *White;
@property(copy) NSString *Black;
@end
@implementation Doc
@end

// Chess's game info panel: a text field shows "<white> vs <black>" through displayPatternValue1 and 2 bound to
// document.White and document.Black of an object whose document is set after the nib loaded.
@interface Flags : NSObject
@property(assign) BOOL a;
@property(assign) BOOL b;
@property int writes;
@end
@implementation Flags
- (void)setA:(BOOL)a { _a = a; _writes++; }
- (void)setB:(BOOL)b { _b = b; _writes++; }
@end

// A view whose hiding changes a second model synchronously, so the binder writes the source again inside its own write.
@interface Box : NSTextField
@property(assign) Flags *partner;
@property(assign) BOOL inWrite;
@end
@implementation Box
- (void)setHidden:(BOOL)hidden
{
    if (hidden && !_inWrite)
    {
        _inWrite = YES;
        _partner.b = YES;
    }
    // The setter changes the source's state once more after the nested write.
    [self willChangeValueForKey:@"hidden"];
    [super setHidden:hidden];
    [self didChangeValueForKey:@"hidden"];
}
@end

@interface Info : NSObject
@property(retain) Doc *document;
@property int removals;
@end
@implementation Info
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
    _removals++;
    [super removeObserver:observer forKeyPath:keyPath];
}
@end

// With any argument only the hidden/hidden2 scenario runs (it passes before and after the change).
int main(int argc, char **argv)
{
    @autoreleasepool
    {
        if (argc == 1)
        {
            Info *info = [[Info alloc] init];
            Doc *doc = [[Doc alloc] init];
            doc.White = @"Alice";
            doc.Black = @"Bob";

            NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
            NSDictionary *options = @{NSDisplayPatternBindingOption : @"%{value1}@ vs %{value2}@"};
            [field bind:@"displayPatternValue1" toObject:info withKeyPath:@"document.White" options:options];
            [field bind:@"displayPatternValue2" toObject:info withKeyPath:@"document.Black" options:options];

            info.removals = 0;
            info.document = doc;
            expect([[field stringValue] isEqualToString:@"Alice vs Bob"],
                   [NSString stringWithFormat:@"the pattern shows both values, got '%@'", [field stringValue]]);
            expect(info.removals == 0,
                   [NSString stringWithFormat:@"a document change keeps the bound key paths observed, %d removals", info.removals]);
            expect([doc.White isEqualToString:@"Alice"] && [doc.Black isEqualToString:@"Bob"],
                   [NSString stringWithFormat:@"the read-only binding writes nothing back, got '%@' and '%@'", doc.White, doc.Black]);

            doc.White = @"Carol";
            expect([[field stringValue] isEqualToString:@"Carol vs Bob"],
                   [NSString stringWithFormat:@"a model change updates the pattern, got '%@'", [field stringValue]]);

            [field setStringValue:@"typed"];
            expect([doc.White isEqualToString:@"Carol"], @"editing the field does not write the pattern into the model");

            [field unbind:@"displayPatternValue1"];
            [field unbind:@"displayPatternValue2"];
        }

        // Binders that are peers through a fake path (hidden, hidden2) keep combining, and the write into the source is
        // not echoed back into the models.
        Flags *one = [[Flags alloc] init];
        Flags *two = [[Flags alloc] init];
        NSTextField *box = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 20, 20)];
        [box bind:@"hidden" toObject:one withKeyPath:@"a" options:nil];
        expect(![box isHidden], @"hidden starts NO");
        one.a = YES;
        expect([box isHidden], @"a single binder follows its model");
        one.a = NO;
        [box bind:@"hidden2" toObject:two withKeyPath:@"b" options:nil];
        one.a = YES;
        two.b = YES;
        expect([box isHidden], @"both peers YES hide the field");
        expect(one.a && two.b, @"the write into the source is not echoed back into the models");
        one.a = NO;
        two.b = NO;
        expect(![box isHidden], @"both peers NO show the field");
        [box unbind:@"hidden"];
        [box unbind:@"hidden2"];

        // A reversible binding: an edit of the source reaches the model once, and the model reaches the source.
        Flags *edited = [[Flags alloc] init];
        NSTextField *plain = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 20, 20)];
        [plain bind:@"hidden" toObject:edited withKeyPath:@"a" options:nil];
        [plain setHidden:YES];
        expect(edited.a && edited.writes == 1,
               [NSString stringWithFormat:@"an edit of the source reaches the model once, %d writes", edited.writes]);
        edited.a = NO;
        expect(![plain isHidden] && edited.writes == 2,
               [NSString stringWithFormat:@"a model change reaches the source without an echo, %d writes", edited.writes]);
        [plain unbind:@"hidden"];

        // The write into the source changes the other model synchronously. The binder writes the source again inside
        // its own write and must not observe the source again before the outer write is over, or the source change
        // of the outer write is reversed into the models.
        Flags *left = [[Flags alloc] init];
        Flags *right = [[Flags alloc] init];
        Box *nested = [[Box alloc] initWithFrame:NSMakeRect(0, 0, 20, 20)];
        nested.partner = right;
        [nested bind:@"hidden" toObject:left withKeyPath:@"a" options:nil];
        [nested bind:@"hidden2" toObject:right withKeyPath:@"b" options:nil];
        left.a = YES;
        expect([nested isHidden], @"the nested write hides the field");
        expect(left.writes == 1 && right.writes == 1,
               [NSString stringWithFormat:@"the write into the source is not echoed into the models, %d and %d writes", left.writes, right.writes]);
        [nested unbind:@"hidden"];
        [nested unbind:@"hidden2"];

        NSLog(@"PASS: display pattern bindings are read-only and share one pattern, peer bindings still combine");
    }
    return 0;
}
