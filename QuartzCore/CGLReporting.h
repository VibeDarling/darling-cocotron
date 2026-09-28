/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <OpenGL/gl.h>

//
// Drains the GL error queue and reports anything found.
//
// This used to be compiled out entirely, which made every GL failure on the
// Metal present path silent: a bad texture import or an incomplete framebuffer
// left the layer blank with no diagnostic at all, and a bug like that can hide
// for a very long time. It is back on because the first thing anyone debugging
// the handoff needs is to see the errors.
//
// It sits in per-frame paths, so an error that persists would otherwise print
// on every frame and bury everything else in the log. Each distinct error code
// is therefore reported once, and the count of how many times it has been seen
// is logged periodically, so a repeating error is still visible without
// drowning the log. The queue is drained either way, so a later unrelated error
// is never masked by an earlier repeated one.
//
// `tag` names the subsystem in the message, so a report from the layer and one
// from a drawable are told apart.
//
static inline void drainAndReportGLErrors(const char* tag) {
	static constexpr int kMaxTrackedErrors = 16;
	struct {
		GLenum code;
		unsigned long count;
	} seen[kMaxTrackedErrors] = {};
	static unsigned int seenCount = 0;
	static unsigned int quietRounds;

	GLenum err;

	while ((err = glGetError()) != GL_NO_ERROR) {
		unsigned int i = 0;
		for (; i < seenCount; ++i) {
			if (seen[i].code == err) {
				break;
			}
		}

		if (i < seenCount) {
			++seen[i].count;
			continue;
		}

		if (seenCount < kMaxTrackedErrors) {
			seen[seenCount].code = err;
			seen[seenCount].count = 1;
			++seenCount;
		}

		NSLog(@"%s: OpenGL error 0x%x (reporting each code once)", tag, err);
	}

	// Log the totals once things have settled, so a persistent error shows up
	// with a count instead of never being mentioned again.
	if (seenCount != 0 && ++quietRounds == 240) {
		for (unsigned int i = 0; i < seenCount; ++i) {
			NSLog(@"%s: OpenGL error 0x%x occurred %lu times", tag, seen[i].code, seen[i].count);
		}
		quietRounds = 0;
	}
}
