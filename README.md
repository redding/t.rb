# t.rb

A test runner. Run locally configured test commands via a generic CLI with standard options/features.

```
$ t                        # every configured suite
$ t -c                     # only test files with uncommitted changes
$ t -c -r main             # only test files changed against a ref
$ t -v                     # use the verbose command
$ t -l                     # list the test files that would run
$ t test/unit/user_tests.rb  # an explicit file list
$ t --help
```

## What It Does...

**Reads a `.t.yml` config:** each suite declares a `default_cmd`, an optional
  `verbose_cmd`, the test directory, the file suffixes that mark a test file,
  and optional seed and ENV var settings.

**Resolves which test files to run:** from explicit paths, or from git — `-c`
  for uncommitted changes, `-r REF` against a ref — matched against the
  configured suffixes.

**Runs each suite with those files:** every suite runs even if an earlier one
  fails, and `t` exits non-zero if any of them did.

**Stays out of the way when asked:** `-l` lists the files it would run and
  `--dry-run` prints the command without running it. Neither executes
  anything, and both exit zero.

## Install

Open a terminal and run this command ([view source](https://raw.githubusercontent.com/redding/t.rb/main/install.sh)):

(change PREFIX as needed; it defaults to `/usr/local`)

```
$ curl -L https://raw.githubusercontent.com/redding/t.rb/main/install.sh | PREFIX=/usr/local sh
```

## Usage

Given a `./.t.yml` in your project's root, e.g.:

```yaml
default_cmd: "MINITEST_REPORTER=ProgressReporter ./bin/rake test"
verbose_cmd: "MINITEST_REPORTER=SpecReporter ./bin/rake test"
test_dir: "test"
test_file_suffixes:
  - "_test.rb"
seed_env_var_name: "SEED"
parallel_env_var_name: "PARALLEL_WORKERS"
env_vars: "USE_SIMPLE_COV=0"
```

Then:

```
$ cd my/project
$ t -h
Usage: t [options] [TESTS]

Options:
    -s, --seed-value VALUE           use a given seed to run tests
    -c, --[no-]changed-only          only run test files with changes
    -r, --changed-ref VALUE          reference for changes, use with `-c` opt
    -p, --parallel-workers VALUE     number of parallel workers to use (if applicable)
    -v, --[no-]verbose               output verbose runtime test info
        --[no-]dry-run               output the test command to $stdout
    -l, --[no-]list                  list test files on $stdout
    -d, --[no-]debug                 run in debug mode
        --version
        --help
$ t
```

#### Debug Mode

```
$ t -d
[DEBUG] CLI init and parse...          (6.686 ms)
[DEBUG] 2 Test files:
[DEBUG]   test/thing1_test.rb
[DEBUG]   test/thing2_test.rb
[DEBUG] Test command:
[DEBUG]   SEED=15991 MINITEST_REPORTER=ProgressReporter ./bin/rake test test/thing1_test.rb test/thing2_test.rb
```

This option, in addition to executing the test command, outputs a bunch of detailed debug information.

#### Changed Only

```
$ t -d -c
[DEBUG] CLI init and parse...          (7.138 ms)
[DEBUG] Lookup changed test files...   (24.889 ms)
[DEBUG]   `git diff --no-ext-diff --name-only  -- test && git ls-files --others --exclude-standard -- test`
[DEBUG] 1 Test files:
[DEBUG]   test/thing2_test.rb
[DEBUG] Test command:
[DEBUG]   SEED=36109 MINITEST_REPORTER=ProgressReporter ./bin/rake test test/thing2_test.rb
```

This runs a git command to determine which files have been updated (relative to `HEAD` by default) and only runs those tests.

You can specify a custom git ref to use instead:

```
$ t -d -c -r master
[DEBUG] CLI init and parse...          (6.933 ms)
[DEBUG] Lookup changed test files...   (162.297 ms)
[DEBUG]   `git diff --no-ext-diff --name-only master -- test && git ls-files --others --exclude-standard -- test`
[DEBUG] 2 Test files:
[DEBUG]   test/thing1_test.rb
[DEBUG]   test/thing2_test.rb
[DEBUG] Test command:
[DEBUG]   SEED=73412 MINITEST_REPORTER=ProgressReporter ./bin/rake test test/thing1_test.rb test/thing2_test.rb
```

#### Dry-Run

```
$ t --dry-run
SEED=23940 MINITEST_REPORTER=ProgressReporter ./bin/rake test test/thing1_test.rb test/thing2_test.rb
```

This option only outputs the test command it would have run.  It does not execute the test command.

#### Parallel Workers

```
$ t -p 2 --dry-run
SEED=23940 PARALLEL_WORKERS=2 MINITEST_REPORTER=ProgressReporter ./bin/rake test test/thing1_test.rb test/thing2_test.rb
```

Force a specific number of parallel workers to run the tests. This uses the configured `PARALLEL_ENV_VAR_NAME` constant to build the env var.

#### List

```
$ t -l
test/thing1_test.rb
test/thing2_test.rb
```

This option, similar to `--dry-run`, does not execute any tests.  It lists out each test file it would execute to `$stdout`.

#### Verbose

```
$ t -v --dry-run
SEED=50201 MINITEST_REPORTER=SpecReporter ./bin/rake test test/thing1_test.rb test/thing2_test.rb
```

This option switches to using the configured `VERBOSE_TEST_CMD` when executing the tests.

#### Seed

```
$ t -s 00000 --dry-run
SEED=00000 MINITEST_REPORTER=ProgressReporter ./bin/rake test test/thing1_test.rb test/thing2_test.rb
```

Force a specific seed value for the test run.

## Configuration

The only required value is: `default_cmd:` - all others are optional:

```yaml
default_cmd: "MINITEST_REPORTER=ProgressReporter ./bin/rake test"
test_dir: "test"
test_file_suffixes:
  - "_test.rb"
```

Alternatively, specifiy a list of multiple runners. T will run each of them in the order they are listed:

```yaml
- default_cmd: "MINITEST_REPORTER=ProgressReporter ./bin/rake test"
  verbose_cmd: "MINITEST_REPORTER=SpecReporter ./bin/rake test"
  test_dir: "test"
  test_file_suffixes:
    - "_test.rb"
  seed_env_var_name: "SEED"
  parallel_env_var_name: "PARALLEL_WORKERS"
  env_vars: "USE_SIMPLE_COV=0"

- default_cmd: "./bin/mocha"
  test_dir: "test/javascript"
  test_file_suffixes:
    - "_test.js"
```

#### `default_cmd:`

Required. The system command to execute the test suite.

#### `verbose_cmd:`

Optional. An alternative system command to execute the test suite in verbose mode (e.g. the `-v` CLI option).

#### `test_dir:`

Optional. The root directory all tests live in. Defaults to `"./test"`.

#### `test_file_suffixes:`

Optional. A list of suffixes that test files use. Defauluts to `"_test.rb"`.

#### `seed_env_var_name:`

Optional. The ENV_VAR name to specific seed values with. Defaults to `"SEED"`. This is used with the `-s` CLI option.

#### `parallel_env_var_name:`

Optional. The ENV_VAR name to specific the number of parallel workers with. Defaults to `"PARALLEL_WORKERS"`. This is used with the `-p` CLI option.

#### `parallel_env_var_name:`

Optional. The ENV_VAR name to specific the number of parallel workers with. Defaults to `"PARALLEL_WORKERS"`. This is used with the `-p` CLI option.

#### `env_vars:`

Optional. A String containing a list of default ENV_VAR names/values to run on both the default and the verbose commands, e.g. `ENV_VAR1=value1 ENV_VAR2=value2`. Defaults to `""`.

## Dependencies

[Ruby](https://www.ruby-lang.org/) `>= 2.5`, developed against the version in `.ruby-version`.

[Git](https://git-scm.com/).

## Uninstall

Open a terminal and run this command ([view source](https://raw.githubusercontent.com/redding/t.rb/main/uninstall.sh)):

```
$ curl -L https://raw.githubusercontent.com/redding/t.rb/main/uninstall.sh | sh
```

## Releasing

The version string lives in three places and they must match:

- `libexec/t.rb` — `VERSION`
- `install.sh` — `T_RELEASE`
- `release.sh` — `T_RELEASE`

To cut a release:

1. Bump the version in all three files.
2. Add a `CHANGELOG.md` entry — a `## <version> / <date>` heading, then one
   line per change ending in its commit SHA.
3. Commit those changes.
4. Run `./release.sh`. It refuses to run against a dirty working tree, then
   tags the release and pushes the commits and the tag.

`install.sh` fetches the tarball for the tag, so the tag must exist before the
published install command resolves to the new version.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

### Running the tests

```
$ bundle install
$ bundle exec assert                            # the whole suite
$ bundle exec assert test/unit/runner_tests.rb  # one file
```

Tests run on the Ruby in `.ruby-version`. This repo is configured for `t.rb`
itself (`.t.yml`), so `t` and `t -c` work too if you have it installed.
