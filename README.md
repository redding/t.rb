# t.rb

A test runner. Run locally configured test commands via a generic CLI with standard options/features.

## Install

Open a terminal and run this command ([view source](https://git.io/t.rb--install)):

```
$ curl -L https://git.io/t.rb--install | sh
```

## Usage

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

Add a `./.t.yml` in your project's root:

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

[Ruby](https://www.ruby-lang.org/) `~> 2.5`.

[Git](https://git-scm.com/).

## Uninstall

Open a terminal and run this command ([view source](http://git.io/t.rb--uninstall)):

```
$ curl -L http://git.io/t.rb--uninstall | sh
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
