# Loaded by every shell (interactive or not), so non-interactive callers
# (git commit, cron, ssh <host> <cmd>) see the editor too.
export EDITOR=nvim
export VISUAL=nvim

# macOS dev default `unpacked` leaves every incremental rebuild's *.rcgu.o in
# target/debug/deps forever; a crowded deps dir slows FSEvents registration
# (~0.9 s each at 450k files). `off`: no growth, panic location kept, backtrace
# frames lose file:line. The test profile inherits dev.
export CARGO_PROFILE_DEV_SPLIT_DEBUGINFO=off
