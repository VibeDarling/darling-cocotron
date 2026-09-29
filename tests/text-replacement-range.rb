# Actual insertion entry points and editability gate; controlled selection/replacement adapters.
# Usage: ruby tests/text-replacement-range.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
sdk,root=ARGV
root ||= File.expand_path('..',__dir__)
private_source=public_source=File.read(File.join(root,'AppKit/NSTextView.subproj/NSTextView.m'))
candidate=true
wrapper=private_source[/^- \(void\) insertText: \(id\) object replacementRange:.*?^\}/m] or abort 'missing wrapper'
legacy=public_source[/^- \(void\) insertText: \(id\) object \{.*?^\}/m] or abort 'missing insertion'
gate=public_source[/^- \(BOOL\) shouldChangeTextInRange:.*?^\}/m] or abort 'missing edit gate'
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  @interface View : NSObject {
  @public NSRange _rangeForUserCompletion,selection,rewrite;
    NSMutableString *_textStorage;
    BOOL editable,allow,rewritesSelection; unsigned selections,changes;
    id lastInput,lastDelegateString; BOOL lastCoalesce; unsigned completions;
  }
  @end
  @implementation View
  ACTUAL_METHODS
  - (id)init {
    if((self=[super init])) {
      _textStorage=[@"abcdef" mutableCopy]; _rangeForUserCompletion=NSMakeRange(NSNotFound,0);
      selection=NSMakeRange(0,0); editable=YES; allow=YES;
    } return self;
  }
  - (BOOL)isEditable { return editable; }
  - (NSRange)selectedRange { return selection; }
  - (void)setSelectedRange:(NSRange)range { ++selections; selection=rewritesSelection?rewrite:range; }
  - (BOOL)_delegateChangeTextInRange:(NSRange)range replacementString:(NSString *)text { lastDelegateString=text; return allow; }
  - (void)endUserCompletion { ++completions; _rangeForUserCompletion=NSMakeRange(NSNotFound,0); }
  - (void)_replaceCharactersInRange:(NSRange)range withString:(id)value allowsTypingCoalescing:(BOOL)coalesce {
    lastInput=value; lastCoalesce=coalesce;
    NSString *plain=[value isKindOfClass:[NSAttributedString class]]?[value string]:value;
    [_textStorage replaceCharactersInRange:range withString:plain];
    [self setSelectedRange:NSMakeRange(range.location+[value length],0)];
  }
  - (void)didChangeText { ++changes; }
  - (void)scrollRangeToVisible:(NSRange)range {}
  - (void)dealloc { [_textStorage release]; [super dealloc]; }
  @end
  int main(void) {
    @autoreleasepool {
      for(unsigned mode=0;mode<3;++mode) {
        View *v=[View new];
        if(mode==0) v->editable=NO;
        if(mode==1) v->allow=NO;
        if(mode==2) { v->rewritesSelection=YES; v->rewrite=NSMakeRange(4,1); }
        [v insertText:@"X" replacementRange:NSMakeRange(1,2)];
        if(mode<2) {
          assert([v->_textStorage isEqual:@"abcdef"] && v->changes==0);
          if(CANDIDATE) assert(v->selections==0 && NSEqualRanges(v->selection,NSMakeRange(0,0)));
          else assert(v->selections==1 && NSEqualRanges(v->selection,NSMakeRange(1,2)));
        } else {
          assert([v->_textStorage isEqual:CANDIDATE ? @"aXdef" : @"abcdXf"]);
          assert(v->changes==1);
        }
        printf("mode=%u selection=%lu,%lu text=%s\n",mode,(unsigned long)v->selection.location,
               (unsigned long)v->selection.length,[v->_textStorage UTF8String]);
        [v release];
      }
      if(CANDIDATE) {
        NSRange invalid[]={{7,0},{5,2},{1,NSUIntegerMax}};
        for(unsigned i=0;i<3;++i) {
          View *v=[View new]; BOOL threw=NO;
          @try { [v insertText:@"X" replacementRange:invalid[i]]; }
          @catch(NSException *e) { assert([[e name] isEqual:NSRangeException]); threw=YES; }
          assert(threw && !v->changes && !v->selections && !v->lastDelegateString);
          assert([v->_textStorage isEqual:@"abcdef"]); [v release];
        }
        View *v=[View new]; [v insertText:@"X" replacementRange:NSMakeRange(6,0)];
        assert([v->_textStorage isEqual:@"abcdefX"] && NSEqualRanges(v->selection,NSMakeRange(7,0)));
        [v release];
        v=[View new]; v->selection=NSMakeRange(2,2);
        [v insertText:@"X" replacementRange:NSMakeRange(NSNotFound,0)];
        assert([v->_textStorage isEqual:@"abXef"]); [v release];
        v=[View new]; v->_rangeForUserCompletion=NSMakeRange(1,1);
        NSAttributedString *a=[[[NSAttributedString alloc] initWithString:@"XY"
            attributes:[NSDictionary dictionaryWithObject:@"value" forKey:@"probe"]] autorelease];
        [v insertText:a replacementRange:NSMakeRange(1,2)];
        assert([v->_textStorage isEqual:@"aXYdef"] && v->lastInput==a);
        assert([v->lastDelegateString isEqual:@"XY"] && v->lastCoalesce && v->completions==1);
        assert(v->changes==1 && NSEqualRanges(v->selection,NSMakeRange(3,0))); [v release];
        puts("PASS: bounds/overflow, end insertion, NSNotFound, attributed-object forwarding and completion cleanup");
      }
      puts(CANDIDATE ? "PASS: rejected edits preserve selection; explicit replacement survives selection delegate" :
          "CONFIRMED: selection changes before veto and delegate selection redirects explicit replacement");
    }
  }
OBJC
program=program.sub('ACTUAL_METHODS'){wrapper+"\n"+legacy+"\n"+gate}.gsub('CANDIDATE',candidate ? '1' : '0')
gcc,status=Open3.capture2('gcc','-print-file-name=include')
abort 'missing headers' unless status.success?
Dir.mktmpdir('replacement-selection') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O1','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'behavior probe failed' unless system(output,rlimit_core:0)
end
