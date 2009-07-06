// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2009 Steve Nygard.

#import "CDTypeFormatter.h"

#include <assert.h>
#import <Foundation/Foundation.h>
#import "NSError-CDExtensions.h"
#import "NSScanner-Extensions.h"
#import "NSString-Extensions.h"
#import "CDClassDump.h" // not ideal
#import "CDMethodType.h"
#import "CDSymbolReferences.h"
#import "CDType.h"
#import "CDTypeLexer.h"
#import "CDTypeParser.h"

static BOOL debug = NO;

@implementation CDTypeFormatter

- (id)init;
{
    if ([super init] == nil)
        return nil;

    shouldShowLexing = debug;

    return self;
}

- (BOOL)shouldExpand;
{
    return shouldExpand;
}

- (void)setShouldExpand:(BOOL)newFlag;
{
    shouldExpand = newFlag;
}

- (BOOL)shouldAutoExpand;
{
    return shouldAutoExpand;
}

- (void)setShouldAutoExpand:(BOOL)newFlag;
{
    shouldAutoExpand = newFlag;
}

- (BOOL)shouldShowLexing;
{
    return shouldShowLexing;
}

- (void)setShouldShowLexing:(BOOL)newFlag;
{
    shouldShowLexing = newFlag;
}

- (int)baseLevel;
{
    return baseLevel;
}

- (void)setBaseLevel:(int)newBaseLevel;
{
    baseLevel = newBaseLevel;
}

- (id)delegate;
{
    return nonretainedDelegate;
}

- (void)setDelegate:(id)newDelegate;
{
    nonretainedDelegate = newDelegate;
}

- (NSString *)_specialCaseVariable:(NSString *)name type:(NSString *)type;
{
    if ([type isEqual:@"c"]) {
        if (name == nil)
            return @"BOOL";
        else
            return [NSString stringWithFormat:@"BOOL %@", name];
#if 0
    } else if ([type isEqual:@"b1"]) {
        if (name == nil)
            return @"BOOL :1";
        else
            return [NSString stringWithFormat:@"BOOL %@:1", name];
#endif
    }

    return nil;
}

// TODO (2004-01-28): See if we can pass in the actual CDType.
- (NSString *)formatVariable:(NSString *)name type:(NSString *)type symbolReferences:(CDSymbolReferences *)symbolReferences;
{
    CDTypeParser *aParser;
    CDType *resultType;
    NSMutableString *resultString;
    NSString *specialCase;
    NSError *error;

    // Special cases: char -> BOOLs, 1 bit ints -> BOOL too?
    specialCase = [self _specialCaseVariable:name type:type];
    if (specialCase != nil) {
        resultString = [NSMutableString string];
        [resultString appendString:[NSString spacesIndentedToLevel:baseLevel spacesPerLevel:4]];
        [resultString appendString:specialCase];

        return resultString;
    }

    aParser = [[CDTypeParser alloc] initWithType:type];
    [[aParser lexer] setShouldShowLexing:shouldShowLexing];
    resultType = [aParser parseType:&error];
    //NSLog(@"resultType: %p", resultType);

    if (resultType == nil) {
        NSLog(@"Couldn't parse return type: %@", [error myExplanation]);
        [aParser release];
        //NSLog(@"<  %s", _cmd);
        return nil;
    }

    resultString = [NSMutableString string];
    [resultType setVariableName:name];
    [resultString appendString:[NSString spacesIndentedToLevel:baseLevel spacesPerLevel:4]];
    [resultString appendString:[resultType formattedString:nil formatter:self level:0 symbolReferences:symbolReferences]];

    [aParser release];

    return resultString;
}

- (NSDictionary *)formattedTypesForMethodName:(NSString *)methodName type:(NSString *)type symbolReferences:(CDSymbolReferences *)symbolReferences;
{
    CDTypeParser *aParser;
    NSArray *methodTypes;
    NSError *error;
    NSMutableDictionary *typeDict;
    NSMutableArray *parameterTypes;

    aParser = [[CDTypeParser alloc] initWithType:type];
    methodTypes = [aParser parseMethodType:&error];
    if (methodTypes == nil)
        NSLog(@"Warning: Parsing method types failed, %@, %@", methodName, [error myExplanation]);
    [aParser release];

    if (methodTypes == nil || [methodTypes count] == 0) {
        return nil;
    }

    typeDict = [NSMutableDictionary dictionary];
    {
        int count, index;
        BOOL noMoreTypes;
        CDMethodType *aMethodType;
        NSScanner *scanner;
        NSString *specialCase;

        count = [methodTypes count];
        index = 0;
        noMoreTypes = NO;

        aMethodType = [methodTypes objectAtIndex:index];
        /*if ([[aMethodType type] isIDType] == NO)*/ {
            NSString *str;

            specialCase = [self _specialCaseVariable:nil type:[[aMethodType type] bareTypeString]];
            if (specialCase != nil) {
                [typeDict setValue:specialCase forKey:@"return-type"];
            } else {
                str = [[aMethodType type] formattedString:nil formatter:self level:0 symbolReferences:symbolReferences];
                if (str != nil)
                    [typeDict setValue:str forKey:@"return-type"];
            }
        }

        index += 3;

        parameterTypes = [NSMutableArray array];
        [typeDict setValue:parameterTypes forKey:@"parametertypes"];

        scanner = [[NSScanner alloc] initWithString:methodName];
        while ([scanner isAtEnd] == NO) {
            NSString *str;

            // We can have unnamed paramenters, :::
            if ([scanner scanUpToString:@":" intoString:&str]) {
                //NSLog(@"str += '%@'", str);
//				int unnamedCount, unnamedIndex;
//				unnamedCount = [str length];
//				for (unnamedIndex = 0; unnamedIndex < unnamedCount; unnamedIndex++)
//					[parameterTypes addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"", @"type", @"", @"name", nil]];
            }
            if ([scanner scanString:@":" intoString:NULL]) {
                NSString *typeString;

                if (index >= count) {
                    noMoreTypes = YES;
                } else {
                    NSMutableDictionary *parameter = [NSMutableDictionary dictionary];

                    aMethodType = [methodTypes objectAtIndex:index];
                    specialCase = [self _specialCaseVariable:nil type:[[aMethodType type] bareTypeString]];
                    if (specialCase != nil) {
                        [parameter setValue:specialCase forKey:@"type"];
                    } else {
                        typeString = [[aMethodType type] formattedString:nil formatter:self level:0 symbolReferences:symbolReferences];
                        //if ([[aMethodType type] isIDType] == NO)
                        [parameter setValue:typeString forKey:@"type"];
                    }
                    //[parameter setValue:[NSString stringWithFormat:@"fp%@", [aMethodType offset]] forKey:@"name"];
                    [parameter setValue:[NSString stringWithFormat:@"arg%u", index-2] forKey:@"name"];
                    [parameterTypes addObject:parameter];
                    index++;
                }
            }
        }

        [scanner release];

        if (noMoreTypes) {
            NSLog(@" /* Error: Ran out of types for this method. */");
        }
    }

    return typeDict;
}

- (NSString *)formatMethodName:(NSString *)methodName type:(NSString *)type symbolReferences:(CDSymbolReferences *)symbolReferences;
{
    CDTypeParser *aParser;
    NSArray *methodTypes;
    NSMutableString *resultString;
    NSError *error;

    aParser = [[CDTypeParser alloc] initWithType:type];
    methodTypes = [aParser parseMethodType:&error];
    if (methodTypes == nil)
        NSLog(@"Warning: Parsing method types failed, %@, %@", methodName, [error myExplanation]);
    [aParser release];

    if (methodTypes == nil || [methodTypes count] == 0) {
        return nil;
    }

    resultString = [NSMutableString string];
    {
        int count, index;
        BOOL noMoreTypes;
        CDMethodType *aMethodType;
        NSScanner *scanner;
        NSString *specialCase;

        count = [methodTypes count];
        index = 0;
        noMoreTypes = NO;

        aMethodType = [methodTypes objectAtIndex:index];
        /*if ([[aMethodType type] isIDType] == NO)*/ {
            NSString *str;

            [resultString appendString:@"("];
            specialCase = [self _specialCaseVariable:nil type:[[aMethodType type] bareTypeString]];
            if (specialCase != nil) {
                [resultString appendString:specialCase];
            } else {
                str = [[aMethodType type] formattedString:nil formatter:self level:0 symbolReferences:symbolReferences];
                if (str != nil)
                    [resultString appendFormat:@"%@", str];
            }
            [resultString appendString:@")"];
        }

        index += 3;

        scanner = [[NSScanner alloc] initWithString:methodName];
        while ([scanner isAtEnd] == NO) {
            NSString *str;

            // We can have unnamed paramenters, :::
            if ([scanner scanUpToString:@":" intoString:&str]) {
                //NSLog(@"str += '%@'", str);
                [resultString appendString:str];
            }
            if ([scanner scanString:@":" intoString:NULL]) {
                NSString *typeString;

                [resultString appendString:@":"];
                if (index >= count) {
                    noMoreTypes = YES;
                } else {
                    NSString *ch;

                    aMethodType = [methodTypes objectAtIndex:index];
                    specialCase = [self _specialCaseVariable:nil type:[[aMethodType type] bareTypeString]];
                    if (specialCase != nil) {
                        [resultString appendFormat:@"(%@)", specialCase];
                    } else {
                        typeString = [[aMethodType type] formattedString:nil formatter:self level:0 symbolReferences:symbolReferences];
                        //if ([[aMethodType type] isIDType] == NO)
                        [resultString appendFormat:@"(%@)", typeString];
                    }
                    //[resultString appendFormat:@"fp%@", [aMethodType offset]];
                    [resultString appendFormat:@"arg%u", index-2];

                    ch = [scanner peekCharacter];
                    // if next character is not ':' nor EOS then add space
                    if (ch != nil && [ch isEqual:@":"] == NO)
                        [resultString appendString:@" "];
                    index++;
                }
            }
        }

        [scanner release];

        if (noMoreTypes) {
            [resultString appendString:@" /* Error: Ran out of types for this method. */"];
        }
    }

    return resultString;
}

- (CDType *)replacementForType:(CDType *)aType;
{
    //NSLog(@"[%p] %s, aType: %@", self, _cmd, [aType typeString]);
    if ([nonretainedDelegate respondsToSelector:@selector(typeFormatter:replacementForType:)]) {
        return [nonretainedDelegate typeFormatter:self replacementForType:aType];
    }

    return nil;
}

- (NSString *)typedefNameForStruct:(CDType *)structType level:(int)level;
{
    if ([nonretainedDelegate respondsToSelector:@selector(typeFormatter:typedefNameForStruct:level:)])
        return [nonretainedDelegate typeFormatter:self typedefNameForStruct:structType level:level];

    return nil;
}

@end
