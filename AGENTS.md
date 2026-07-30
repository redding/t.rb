# t.rb — notes for agents and non-interactive shells

`t` runs the test commands a project declares in its `.t.yml`. There is no
built-in knowledge of any particular test framework: the config supplies the
command strings, and `t` decides which test files to hand them.

## Always scope the run

`t` with no scope runs the whole suite for every configured suite, which in a
large repo can be far more than the change warrants. Pass a scope:

- `t -c` — only test files with uncommitted changes
- `t -c -r <ref>` — only test files changed against a ref
- `t <file> [<file>...]` — an explicit list
- `t <dir>` — everything under a directory

## `-c` reads the working tree, not the branch

`-c` means *uncommitted* changes. Once work is committed it selects nothing,
so a post-commit `t -c` runs no tests and reports success. Use
`-c -r <base-branch>` to cover a branch's worth of changes, or name the files.

It also selects *test files* that changed — editing an implementation file
does not pull in the test that covers it.

## Exit status reflects the result

`t` exits non-zero when any suite fails, so it can gate a hook or a CI step.
Every suite still runs after one fails, so a single failing suite does not
suppress the results of the ones behind it.

`--list` and `--dry-run` do not execute anything and exit zero; do not read a
zero from those as a passing suite.

## Confirm what will run before trusting a pass

`-l` prints the test files that would run and `--dry-run` prints the command
without executing it. An empty file list is the most common reason a run
"passes" without having tested anything.

## Seeds are for reproducing, not for stability

`-s VALUE` pins the framework's seed. Reach for it to reproduce an ordering
failure, not as a way to make a flaky suite look green.

## Config lookup is per-directory

The config is `./.t.yml`, resolved from the current directory. Running `t`
from outside a project — or from a subdirectory whose parent holds the
config — will not find it.
