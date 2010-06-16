//
//  StringExtensions.m
//  Vienna
//
//  Created by Steve on Wed Mar 17 2004.
//  Copyright (c) 2004 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "StringExtensions.h"

@implementation NSMutableString (MutableStringExtensions)

/* replaceString
 * Replaces one string with another. This is just a simpler version of the standard
 * NSMutableString replaceOccurrencesOfString function with NSLiteralString implied
 * and the range set to the entire string.
 */
-(void)replaceString:(NSString *)source withString:(NSString *)dest
{
	[self replaceOccurrencesOfString:source withString:dest options:NSLiteralSearch range:NSMakeRange(0, [self length])];
}
@end

@implementation NSString (StringExtensions)

/* firstLine
 * Returns a string that contains just the first non-blank line of the
 * string of which this method is part. A line is assumed to
 * be terminated by any of \r, \n or \0.
 */
-(NSString *)firstLine
{
	return [self firstLineWithMaximumCharacters:[self length] allowEmpty:YES];
}

/* firstNonBlankLine
 * Returns the first line of the string that isn't entirely spaces or tabs.
 */
-(NSString *)firstNonBlankLine
{
	return [self firstLineWithMaximumCharacters:[self length] allowEmpty:NO];
}

/* firstLineWithMaximumCharacters
 * Returns a string that contains just the first non-blank line of the
 * string of which this method is part. A line is assumed to
 * be terminated by any of \r, \n or \0. A maximum of maxChars are
 * returned.
 */
-(NSString *)firstLineWithMaximumCharacters:(unsigned int)maxChars allowEmpty:(BOOL)allowEmpty
{
	unsigned int indexOfLastWord;
	unsigned int indexOfChr;
	BOOL hasNonEmptyChars;
	unichar ch;
	NSRange r;
	
	r.location = 0;
	r.length = 0;
	indexOfChr = 0;
	indexOfLastWord = 0;
	hasNonEmptyChars = NO;
	if (maxChars > [self length])
		maxChars = [self length];
	while (indexOfChr < maxChars)
	{
		ch = [self characterAtIndex:indexOfChr];
		if (ch == '\r' || ch == '\n')
		{
			if ((r.length > 0 && allowEmpty) || (!allowEmpty && hasNonEmptyChars))
			{
				indexOfLastWord = r.length;
				break;
			}
			r.location += r.length + 1;
			r.length = -1;
			hasNonEmptyChars = NO;
		}
		else
		{
			if (ch == ' ' || ch == '\t')
				indexOfLastWord = r.length;
			else
				hasNonEmptyChars = YES;
		}
		++indexOfChr;
		++r.length;
	}
	if (r.length < maxChars)
		r.length = indexOfLastWord;
	if (r.location >= maxChars)
		r.location = maxChars - r.length;
	return [self substringWithRange:r];
}

/* secondAndSubsequentLines
 * Returns a string that contains just the first line of the
 * string of which this method is part. A line is assumed to
 * be terminated by any of \r, \n or \0.
 */
-(NSString *)secondAndSubsequentLines
{
	unsigned int length = [self length];
	unichar ch = 0;
	NSRange r;

	r.location = 0;
	while (r.location < length)
	{
		ch = [self characterAtIndex:r.location];
		if (ch == '\r' || ch == '\n')
			break;
		++r.location;
	}
	if (ch == '\r')
	{
		if (++r.location < length)
			ch = [self characterAtIndex:r.location];
	}
	if (ch == '\n')
		++r.location;
	r.length = length - r.location;
	return [self substringWithRange:r];
}

/* indexOfCharacterInString
 * Returns the index of the first occurrence of the specified character after
 * the starting index.
 */
-(int)indexOfCharacterInString:(char)ch afterIndex:(int)startIndex
{
	int length = [self length];
	int index;

	if (startIndex < length - 1)
		for (index = startIndex; index < length; ++index)
		{
			if ([self characterAtIndex:index] == ch)
				return index;
		}
	return NSNotFound;
}

/* hasCharacter
 * Returns YES if the specified character appears in the string. NO otherwise.
 */
-(BOOL)hasCharacter:(char)ch
{
	return [self indexOfCharacterInString:ch afterIndex:0] != NSNotFound;
}

/* reversedString
 * Return the string reversed.
 */
-(NSString *)reversedString
{
	const char * cString = [self cString];
	char * rcString = strdup(cString);
	NSString * reversedString = nil;

	if (rcString != nil)
	{
		int length = strlen(cString);
		int p;
		
		for (p = 0; p < length; ++p)
			rcString[p] = cString[(length - p) - 1];
		rcString[p] = '\0';
		reversedString = [[[NSMutableString alloc] initWithCString:rcString] autorelease];
		free(rcString);
	}
	return reversedString;
}

/* rewrapString
 * Reformat a string so that lines are broken at the specified
 * column.
 */
-(NSMutableArray *)rewrapString:(int)wrapColumn
{
	NSMutableArray * arrayOfLines = [NSMutableArray array];
	const char * cString = [self cString];
	const char * lineStart;
	int lineLength;
	int indexOfEndOfLastWord;
	BOOL inSpace;

	lineLength = 0;
	lineStart = cString;
	indexOfEndOfLastWord = 0;
	inSpace = NO;

	while (*cString)
	{
		if (*cString == ' ' || *cString == '\t')
		{
			if (!inSpace) {
				indexOfEndOfLastWord = lineLength;
				inSpace = YES;
			}
		}
		else
		{
			inSpace = NO;
		}
		if (*cString == '\n')
		{
			[arrayOfLines addObject:[NSString stringWithCString:lineStart length:lineLength]];
			lineLength = 0;
			indexOfEndOfLastWord = 0;
			lineStart = ++cString;
		}
		else if (lineLength == wrapColumn)
		{
			if (indexOfEndOfLastWord == 0)
				indexOfEndOfLastWord = lineLength;
			[arrayOfLines addObject:[NSString stringWithCString:lineStart length:indexOfEndOfLastWord]];
			lineLength = 0;
			lineStart += indexOfEndOfLastWord;
			
			while (*lineStart == ' ' || *lineStart == '\t')
				++lineStart;
			cString = lineStart;
		}
		else
		{
			++cString;
			++lineLength;
		}
	}
	if (lineLength)
		[arrayOfLines addObject:[NSString stringWithCString:lineStart length:lineLength]];
	return arrayOfLines;
}
@end
