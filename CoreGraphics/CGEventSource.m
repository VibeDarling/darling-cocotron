/*
 This file is part of Darling.

 Copyright (C) 2020 Lubos Dolezel

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
#include "CGEventObjC.h"
#include <CoreGraphics/CGEventSource.h>

static CGEventFlags g_sourceStates[3];

CFTypeID CGEventSourceGetTypeID(void) {
    return (CFTypeID)[CGEventSource self];
}

CGEventSourceRef CGEventSourceCreate(CGEventSourceStateID stateID) {
    return (CGEventSourceRef) [[CGEventSource alloc] initWithState: stateID];
}

CGEventSourceKeyboardType CGEventSourceGetKeyboardType(CGEventSourceRef source)
{
    CGEventSource *src = (CGEventSource *) source;
    return src.keyboardType;
}

void CGEventSourceSetKeyboardType(CGEventSourceRef source,
                                  CGEventSourceKeyboardType keyboardType)
{
    CGEventSource *src = (CGEventSource *) source;
    src.keyboardType = keyboardType;
}

CGEventSourceStateID CGEventSourceGetSourceStateID(CGEventSourceRef source) {
    CGEventSource *src = (CGEventSource *) source;
    return src.stateID;
}

int64_t CGEventSourceGetUserData(CGEventSourceRef source) {
    CGEventSource *src = (CGEventSource *) source;
    return src.userData;
}

void CGEventSourceSetUserData(CGEventSourceRef source, int64_t userData) {
    CGEventSource *src = (CGEventSource *) source;
    src.userData = userData;
}

double CGEventSourceGetPixelsPerLine(CGEventSourceRef source) {
    CGEventSource *src = (CGEventSource *) source;
    return src.pixelsPerLine;
}

void CGEventSourceSetPixelsPerLine(CGEventSourceRef source,
                                   double pixelsPerLine)
{
    CGEventSource *src = (CGEventSource *) source;
    src.pixelsPerLine = pixelsPerLine;
}

CGEventFlags CGEventSourceFlagsState(CGEventSourceStateID stateID) {
    if (stateID < -1 || stateID > 1) return 0;
    return g_sourceStates[stateID + 1];
}

bool CGEventSourceButtonState(CGEventSourceStateID stateID, CGMouseButton button) {
    return false;
}

bool CGEventSourceKeyState(CGEventSourceStateID stateID, CGKeyCode key) {
    return false;
}

CFTimeInterval CGEventSourceSecondsSinceLastEventType(CGEventSourceStateID stateID, CGEventType eventType) {
    return 0.0;
}

uint32_t CGEventSourceCounterForEventType(CGEventSourceStateID stateID, CGEventType eventType) {
    return 0;
}

void CGEventSourceSetLocalEventsSuppressionInterval(CGEventSourceRef source, CFTimeInterval seconds) {
}

CFTimeInterval CGEventSourceGetLocalEventsSuppressionInterval(CGEventSourceRef source) {
    return 0.0;
}

void CGEventSourceSetLocalEventsFilterDuringSuppressionState(CGEventSourceRef source, CGEventFilterMask filter, CGEventSuppressionState state) {
}

CGEventFilterMask CGEventSourceGetLocalEventsFilterDuringSuppressionState(CGEventSourceRef source, CGEventSuppressionState state) {
    return 0;
}
