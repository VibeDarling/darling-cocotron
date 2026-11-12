/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

// NSSpellEngine is a class of Darling's Foundation that Apple's Foundation lacks, so AppKit finds
// it by name at run time. Without the class there are no engines, the same as a Foundation that
// has no *.spellEngine bundle installed.

#import <Foundation/NSArray.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSOrthography.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTextCheckingResult.h>
#import <objc/runtime.h>

@protocol AKSpellEngine <NSObject>
- (NSArray *) languages;
- (NSArray *) suggestGuessesForWord: (NSString *) word
                         inLanguage: (NSString *) language;
- (NSArray *) checkString: (NSString *) stringToCheck
                   offset: (NSUInteger) offset
                    types: (NSTextCheckingTypes) checkingTypes
                  options: (NSDictionary *) options
              orthography: (NSOrthography *) orthography
                wordCount: (NSInteger *) wordCount;
@end

@protocol AKSpellEngineClass <NSObject>
+ (NSArray *) allSpellEngines;
@end

static inline NSArray *AKSpellEngines(void) {
    Class<AKSpellEngineClass> engine = NSClassFromString(@"NSSpellEngine");

    if (engine == Nil || ![engine respondsToSelector: @selector(allSpellEngines)])
        return @[];

    return [engine allSpellEngines];
}
