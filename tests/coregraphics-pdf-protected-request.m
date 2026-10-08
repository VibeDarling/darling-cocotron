#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Onyx2D/O2PDFDocument.h>
#include <stdio.h>
#include <string.h>

extern const CFStringRef kCGPDFContextOwnerPassword __attribute__((weak_import));
extern const CFStringRef kCGPDFContextUserPassword __attribute__((weak_import));
extern const CFStringRef kCGPDFContextEncryptionKeyLength __attribute__((weak_import));

int main(void) {
    @autoreleasepool {
        if (&kCGPDFContextOwnerPassword == NULL || &kCGPDFContextUserPassword == NULL ||
            &kCGPDFContextEncryptionKeyLength == NULL) {
            fputs("missing PDF encryption-setting keys\n", stderr);
            return 10;
        }
        NSArray *requests = @[
            @{(id)kCGPDFContextOwnerPassword: @"fixture-owner"},
            @{(id)kCGPDFContextUserPassword: @"fixture-user"},
            @{(id)kCGPDFContextEncryptionKeyLength: @128},
            @{(id)kCGPDFContextOwnerPassword: @""},
            @{(id)kCGPDFContextUserPassword: @"\u03A9"},
            @{(id)kCGPDFContextEncryptionKeyLength: @7},
            @{(id)kCGPDFContextOwnerPassword: @"fixture-owner",
              (id)kCGPDFContextUserPassword: @"fixture-user",
              (id)kCGPDFContextEncryptionKeyLength: @128},
            @{(id)kCGPDFContextOwnerPassword: [NSNull null]},
        ];
        CGRect box = CGRectMake(0, 0, 100, 200);
        for (unsigned i = 0; i < [requests count]; i++) {
            NSDictionary *request = [requests objectAtIndex:i];
            NSDictionary *original = [[request copy] autorelease];
            NSMutableData *data = [NSMutableData dataWithBytes:"seed" length:4];
            CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((CFMutableDataRef)data);
            CGContextRef context = CGPDFContextCreate(consumer, &box, (CFDictionaryRef)request);
            CGDataConsumerRelease(consumer);
            if (context) {
                CGPDFContextClose(context);
                CGContextRelease(context);
                if ([data length] <= 4) return 30 + i;
                NSData *output = [data subdataWithRange:NSMakeRange(4, [data length] - 4)];
                CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)output);
                CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
                CGDataProviderRelease(provider);
                BOOL plaintext = document && ![(O2PDFDocument *)document encryptDictionary];
                if (document) CGPDFDocumentRelease(document);
                if (!plaintext) return 30 + i;
                fprintf(stderr, "unsupported encryption request created plaintext output case%u\n", i);
                return 20 + i;
            }
            if ([data length] != 4 || memcmp([data bytes], "seed", 4)) return 40 + i;
            if (![request isEqual:original]) return 60 + i;
        }
        for (unsigned i = 0; i < 2; i++) {
            NSMutableData *data = [NSMutableData data];
            CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((CFMutableDataRef)data);
            NSDictionary *info = i ? @{(id)kCGPDFContextTitle: @"Plain context"} : nil;
            CGContextRef context = CGPDFContextCreate(consumer, &box, (CFDictionaryRef)info);
            CGDataConsumerRelease(consumer);
            if (!context) return 80 + i;
            CGPDFContextClose(context);
            CGContextRelease(context);
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
            CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
            CGDataProviderRelease(provider);
            if (!document || [(O2PDFDocument *)document encryptDictionary]) return 90 + i;
            CGPDFDocumentRelease(document);
        }
        puts("unsupported PDF encryption requests fail without writes; plaintext creation passed");
    }
    return 0;
}
