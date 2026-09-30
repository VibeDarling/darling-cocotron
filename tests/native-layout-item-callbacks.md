Native CoreAutoLayout asks layout items for their superitem, installed
constraints, and layout engine. NSView now reports its actual superview,
maintains retained identity-based constraint storage, returns immutable
snapshots, and marks layout dirty only when storage changes. The callbacks
never reenter constraint activation. The engine query returns nil because
Cocotron does not own a native solver.

Build `native-layout-item-callbacks.m` as a Darling AppKit guest and run with
cached CoreAutoLayout and the candidate disk AppKit. It prints the runtime
constraint class's image, creates an anchor constraint, and verifies native
activation reaches the nearest owner, repeated callback/batch activation does
not duplicate storage, snapshots remain stable, and removal is idempotent.
The test invokes the removal callback directly: this is a layout-item bridge,
not implementation of native engine activation/deactivation or a solver.
`isActive` can remain false without an engine, and this change does not claim
to solve frames. Direct native constraint-factory recognition of standalone
Cocotron NSView instances is also outside this change; the probe uses anchors.

The motivating integration failure is iTerm2's quit accessory view raising
an unrecognized `nsli_superitem` (then `nsli_addConstraint`) exception. With
these callbacks and existing alert/disclosure layout fixes, the quit dialog
renders and confirms exit in the current-main iTerm2 workload. Public
single-constraint add/remove APIs are not added by this patch.
