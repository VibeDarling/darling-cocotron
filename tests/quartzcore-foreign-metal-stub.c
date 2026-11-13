// A Metal that exports only the public entry point QuartzCore imports from it, so it
// has no MTLTextureInternal class. Install name and layout follow a Metal framework.
void *MTLCreateSystemDefaultDevice(void) { return 0; }
