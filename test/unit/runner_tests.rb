# frozen_string_literal: true

require "assert"
require "libexec/t"

class TdotRB::Runner
  class UnitTests < Assert::Context
    desc "TdotRB::Runner"
    subject{ unit_class }

    let(:unit_class) { TdotRB::Runner }
  end

  class InitSetupTests < UnitTests
    desc "when init"
    subject{ @runner }

    setup do
      Assert.stub(Dir, :pwd){ TEST_SUPPORT_PATH }
      @test_files = [
        "test/thing1_test.rb",
        "test/thing2_test.rb"
      ]

      @test_output = +""
      @config      = TdotRB::Config.new(StringIO.new(@test_output))
      Assert.stub(TdotRB, :config){ @config }

      @default_cmd  = Factory.string
      @verbose_cmd  = Factory.string
      @seed_env_var_name = Factory.string
      @env_vars          = "#{Factory.string.upcase}=#{Factory.string}"
      Assert.stub(@config, :suites) do
        [
          TdotRB::Config::Suite.new(
            default_cmd:  @default_cmd,
            verbose_cmd:  @verbose_cmd,
            seed_env_var_name: @seed_env_var_name,
            env_vars:          @env_vars,
          )
        ]
      end

      @test_paths = [""]
    end
  end

  class InitTests < InitSetupTests
    setup do
      @runner = unit_class.new(@test_paths, config: @config)
    end

    should have_readers :test_paths, :config

    should "know its attribtes" do
      assert_that(subject.test_paths).equals(@test_paths)
      assert_that(subject.config).is(@config)
    end
  end

  class DryRunTests < InitSetupTests
    desc "and configured to dry run"

    setup do
      Assert.stub(@config, :dry_run){ true }

      debug = Factory.boolean
      Assert.stub(@config, :debug){ debug }

      list = Factory.boolean
      Assert.stub(@config, :list){ list }

      @runner = unit_class.new(@test_paths, config: @config)
    end

    should "output the cmd str to stdout and but not execute it" do
      subject.run

      assert_includes     @default_cmd, @test_output
      assert_not_includes @verbose_cmd, @test_output

      exp = "#{@env_vars} #{@seed_env_var_name}=#{@config.seed_value}"
      assert_includes exp, @test_output

      assert_includes @test_files.join(" "), @test_output
    end
  end

  class ListTests < InitSetupTests
    desc "and configured to list"
    setup do
      Assert.stub(@config, :list){ true }

      debug = Factory.boolean
      Assert.stub(@config, :debug){ debug }

      dry_run = Factory.boolean
      Assert.stub(@config, :dry_run){ dry_run }

      @runner = unit_class.new(@test_paths, config: @config)
    end

    should "list out the test files to stdout and not execute the cmd str" do
      subject.run
      assert_includes @test_files.join("\n"), @test_output
    end
  end

  class VerboseTests < InitSetupTests
    desc "and configured in verbose mode"
    setup do
      Assert.stub(@config, :dry_run) { true }
      Assert.stub(@config, :verbose) { true }

      @runner = unit_class.new(@test_paths, config: @config)
    end

    should "use the verbose test command" do
      subject.run

      assert_includes     @verbose_cmd, @test_output
      assert_not_includes @default_cmd, @test_output
    end
  end

  class ChangedOnlySetupTests < InitSetupTests
    setup do
      @changed_ref = Factory.string
      Assert.stub(@config, :changed_ref) { @changed_ref }
      Assert.stub(@config, :changed_only) { true }

      @changed_test_file = @test_files.sample
      @git_cmd_used      = nil
      Assert.stub(TdotRB::GitChangedFiles, :new) do |*args|
        @git_cmd_used = TdotRB::GitChangedFiles.cmd(*args)
        TdotRB::ChangedResult.new(@git_cmd_used, [@changed_test_file])
      end

      @test_paths = @test_files
    end
  end

  class ChangedOnlyTests < ChangedOnlySetupTests
    desc "and configured in changed only mode"
    setup do
      Assert.stub(@config, :dry_run) { true }

      @runner = unit_class.new(@test_paths, config: @config)
    end

    should "run a git cmd to determine which files to test" do
      subject.run

      exp = "git diff --no-ext-diff --name-only #{@changed_ref} "\
            "-- #{@test_paths.join(" ")} && "\
            "git ls-files --others --exclude-standard "\
            "-- #{@test_paths.join(" ")}"
      assert_equal exp, @git_cmd_used
    end

    should "only run the test files that have changed" do
      subject.run

      exp = "#{@default_cmd} #{@changed_test_file}"
      assert_includes exp, @test_output
    end
  end

  class DebugTests < ChangedOnlySetupTests
    desc "and configured in debug mode"
    setup do
      Assert.stub(@config, :dry_run) { true }
      Assert.stub(@config, :debug) { true }

      @runner = unit_class.new(@test_paths, config: @config)
    end

    should "output detailed debug info" do
      subject.run

      changed_result      = TdotRB::GitChangedFiles.new(@config, @test_paths)
      changed_cmd         = changed_result.cmd
      changed_files_count = changed_result.files.size
      changed_files_lines = changed_result.files.map{ |f| "[DEBUG]   #{f}" }

      assert_includes "[DEBUG] Lookup changed test files...", @test_output

      exp = "[DEBUG]   `#{changed_cmd}`\n"\
            "[DEBUG] #{changed_files_count} Test files:\n"\
            "#{changed_files_lines.join("\n")}\n"\
            "[DEBUG] Test command:\n"
      assert_includes exp, @test_output
    end
  end
end
