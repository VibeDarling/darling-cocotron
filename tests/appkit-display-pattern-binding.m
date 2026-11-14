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

// Chess's game info panel: a text field shows "<white> vs <black>" through displayPatternValue1 and 2 bound to
// document.White and document.Black of an object whose document is set after the nib loaded.
@interface Doc : NSObject
@property(copy) NSString *White;
@property(copy) NSString *Black;
@end
@implementation Doc
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

@interface Flags : NSObject
@property(assign) BOOL a;
@property(assign) BOOL b;
@end
@implementation Flags
@end

// A model that counts the writes it receives.
@interface Level : NSObject
@property(assign) double level;
@property int writes;
@end
@implementation Level
- (void)setLevel:(double)level
{
    _level = level;
    _writes++;
}
@end

// A slider whose new value also changes its model synchronously (while partnerEnabled), so the binder writes the
// source again inside its own write, and which posts one more change of its value after that nested write.
@interface Slider : NSSlider
@property(assign) Level *partner;
@property(assign) BOOL partnerEnabled;
@property(assign) BOOL inWrite;
@end
@implementation Slider
- (void)setObjectValue:(id)value
{
    BOOL outermost = !_inWrite;
    if (outermost && _partnerEnabled)
    {
        _inWrite = YES;
        _partner.level = [value doubleValue];
    }
    [self willChangeValueForKey:@"objectValue"];
    [super setObjectValue:value];
    [self didChangeValueForKey:@"objectValue"];
    if (outermost)
        _inWrite = NO;
}
@end

// With any argument only the hidden/hidden2 and slider scenarios run: `value` of an NSSlider is a read/write binding in the
// Cocoa Bindings Reference ("NSSlider Bindings": the page marks hidden, enabled and toolTip "Binding is Read-Only"
// and value is not), and they pass before and after the change.
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

        // Two bindings of one source that are peers through a fake path (hidden, hidden2). hidden is read-only in the
        // Cocoa Bindings Reference, so only the model reaching the view is checked.
        Flags *one = [[Flags alloc] init];
        Flags *two = [[Flags alloc] init];
        NSTextField *box = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 20, 20)];
        [box bind:@"hidden" toObject:one withKeyPath:@"a" options:nil];
        [box bind:@"hidden2" toObject:two withKeyPath:@"b" options:nil];
        one.a = YES;
        two.b = YES;
        expect([box isHidden], @"both peers YES hide the field");
        one.a = NO;
        two.b = NO;
        expect(![box isHidden], @"both peers NO show the field");
        [box unbind:@"hidden"];
        [box unbind:@"hidden2"];

        // A reversible binding: an edit of the source reaches the model once, and the model reaches the source.
        Level *edited = [[Level alloc] init];
        NSSlider *plain = [[NSSlider alloc] initWithFrame:NSMakeRect(0, 0, 100, 20)];
        [plain bind:@"value" toObject:edited withKeyPath:@"level" options:nil];
        [plain setObjectValue:@0.5];
        expect(edited.level == 0.5 && edited.writes == 1,
               [NSString stringWithFormat:@"an edit of the source reaches the model once, %g after %d writes", edited.level, edited.writes]);
        edited.level = 0.25;
        expect([plain doubleValue] == 0.25 && edited.writes == 2,
               [NSString stringWithFormat:@"a model change reaches the source without an echo, %g after %d writes", [plain doubleValue], edited.writes]);
        [plain unbind:@"value"];

        // The write into the source changes the model synchronously. The binder writes the source again inside its
        // own write and must not observe the source again before the outer write is over, or the change the outer
        // write posts afterwards is reversed into the model.
        Level *model = [[Level alloc] init];
        Slider *nested = [[Slider alloc] initWithFrame:NSMakeRect(0, 0, 100, 20)];
        nested.partner = model;
        nested.partnerEnabled = YES;
        [nested bind:@"value" toObject:model withKeyPath:@"level" options:nil];
        model.writes = 0; // binding the slider already wrote its initial value through the partner
        model.level = 0.5;
        expect([nested doubleValue] == 0.5, @"the nested write reaches the slider");
        expect(model.writes == 2,
               [NSString stringWithFormat:@"the write into the source is not echoed into the model, %d writes", model.writes]);

        // The source is observed again once the writes are over: a later edit reaches the model, and so does a
        // later model change reach the source.
        nested.partnerEnabled = NO;
        [nested setObjectValue:@0.9];
        expect(model.level == 0.9,
               [NSString stringWithFormat:@"a later edit of the source reaches the model, got %g", model.level]);
        model.level = 0.75;
        expect([nested doubleValue] == 0.75, @"a later model change reaches the source");
        [nested unbind:@"value"];

        NSLog(@"PASS: display pattern bindings are read-only and share one pattern, reversible bindings keep working");
    }
    return 0;
}
