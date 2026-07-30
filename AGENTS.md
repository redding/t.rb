# t.rb — notes for agents working on this repo

Notes for *developing* `t.rb`. For using the tool, see the README.

## The whole program is one file

`libexec/t.rb` is it — around 435 lines, no `lib/`, no gemspec. Install
symlinks `$PREFIX/bin/t` at that file and runs it directly.

Two constraints follow:

- **Stdlib only at runtime.** The file requires `benchmark`, `set`, and
  `yaml` and nothing else. `pry` and `assert` in the `Gemfile` are for
  development; a runtime `require` of a gem would break every install, since
  there is no bundle around the installed script.
- **Ruby floor is real.** The file is run by whatever Ruby the user's shell
  resolves, not a pinned one. `class ::Hash` is reopened near the bottom to
  backport a method for older interpreters — that is the shape a
  compatibility fix takes here.

## Layout of that file

| region | role |
|---|---|
| `module TdotRB` | entry point — `.run`, `.apply`, `.config`, `.bench`, `.help_msg` |
| `Config` | parses `./.t.yml`, holds CLI settings and the suite definitions |
| `Runner` | resolves which test files to run, then runs each suite |
| `GitChangedFiles` | the `-c` / `-r` git integration |
| `RoundedMillisecondTime` | benchmarking helper |
| `CLIRB` | **vendored** option parser, copied from redding/cli.rb |
| `class ::Hash` | backport for older Rubies |

Note the difference from the sibling `l.rb`: there is no `Linter`-equivalent
class here. Suites are value objects held by `Config`, so per-suite behavior
lives in `Config::Suite` and `Runner`, not in a class of its own.

`CLIRB` is a verbatim copy carrying its own version comment. Fix bugs
upstream in redding/cli.rb and re-copy rather than editing it here, or the
next copy silently reverts the change.

## Requiring the file runs the CLI

The last lines are:

```ruby
unless ENV["TDOTRB_DISABLE_RUN"]
  # ... parse ARGV and run
end
```

`test/helper.rb` sets `TDOTRB_DISABLE_RUN` before requiring, which is the only
reason the suite can load the file without executing a test run — without it,
loading the file inside a test run would kick off another test run. Anything
else that requires `libexec/t` must do the same.

## Tests

```
$ bundle install
$ bundle exec assert                            # the whole suite
$ bundle exec assert test/unit/runner_tests.rb  # one file
```

The framework is [assert](https://github.com/redding/assert), not RSpec or
Minitest. `test/helper.rb` is auto-required.

- `test/unit/*_tests.rb` mirrors the classes above one-to-one.
- `test/support/test/` holds fixture test files (`thing1_test.rb`,
  `thing2_test.rb`) that the file-resolution logic actually globs over.
  **Adding a file there can change expectations in the config and runner
  tests** — it is fixture data, not scratch space.
- Stubbing is `Assert.stub(obj, :meth){ ... }`. It requires the receiver to
  `respond_to?` the method, so private `Kernel` methods like `system` cannot be
  stubbed directly — that is why command execution sits behind a named
  `execute_cmd` method rather than calling `system` inline.

Most tests drive `Runner` with `dry_run` or `list` stubbed true, so no
subprocess is spawned. If you change execution behavior, add coverage that
exercises the executing path — the default setup will not reach it.

## Maintenance notes

- The version string lives in three files and must match: `libexec/t.rb`
  (`VERSION`), `install.sh` (`T_RELEASE`), `release.sh` (`T_RELEASE`). The
  duplication is deliberate — `install.sh` fetches a release *tag*.
- `CHANGELOG.md` entries carry the commit SHA of each change.
- Release steps are in the README under `## Releasing`. Version bumps are
  committed on `main` and tagged there, not merged through a pull request.
- This repo has no CI. Run the suite locally before pushing; nothing else will.
