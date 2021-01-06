# frozen_string_literal: true

require "assert"
require "libexec/t"

class TdotRB::Config
  class UnitTests < Assert::Context
    desc "TdotRB::Config"
    subject{ unit_class }

    let(:unit_class) { TdotRB::Config }

    should have_imeths :settings

    should "know its suites config file path" do
      assert_that(subject::SUITES_FILE_PATH).equals("./.t.yml")
    end
  end

  class InitTests < UnitTests
    desc "when init"
    subject{ config }

    let(:config) { unit_class.new }

    should have_readers :stdout, :suites, :version
    should have_imeths  :seed_value, :changed_only, :changed_ref, :parallel_workers
    should have_imeths  :verbose, :dry_run, :list, :debug
    should have_imeths  :apply
    should have_imeths :debug_msg, :debug_puts, :puts, :print
    should have_imeths :bench, :bench_start_msg, :bench_finish_msg

    should "know its stdout" do
      assert_that(subject.stdout).is($stdout)

      io     = StringIO.new(+"")
      assert_that(unit_class.new(io).stdout).is_the_same_as(io)
    end

    should "default to having no suites" do
      assert_that(subject.suites).equals([])
    end

    should "default its settings attrs" do
      assert_not_nil subject.seed_value
      assert_false   subject.changed_only
      assert_empty   subject.changed_ref
      assert_nil     subject.parallel_workers
      assert_false   subject.verbose
      assert_false   subject.dry_run
      assert_false   subject.list
      assert_false   subject.debug
    end

    should "apply custom settings attributes and suite configs" do
      settings = {
        :seed_value       => Factory.integer,
        :changed_only     => true,
        :changed_ref      => Factory.string,
        :parallel_workers => Factory.integer(3),
        :verbose          => true,
        :dry_run          => true,
        :list             => true,
        :debug            => true
      }
      subject.apply(settings)

      assert_equal settings[:seed_value],       subject.seed_value
      assert_equal settings[:changed_only],     subject.changed_only
      assert_equal settings[:changed_ref],      subject.changed_ref
      assert_equal settings[:parallel_workers], subject.parallel_workers
      assert_equal settings[:verbose],          subject.verbose
      assert_equal settings[:dry_run],          subject.dry_run
      assert_equal settings[:list],             subject.list
      assert_equal settings[:debug],            subject.debug
    end

    should "load suite configs from a YAML file" do
      Assert.stub_on_call(YAML, :load) do |call|
        @yaml_call = call
        [{ "default_cmd" => "CMD 1" }, { "default_cmd" => "CMD 2" }]
      end

      subject.load_suites
      assert_that(subject.suites.size).equals(2)
      subject.suites.each do |suite|
        assert_that(suite).is_instance_of(unit_class::Suite)
        assert_that(suite.default_cmd).includes("CMD ")
      end
    end

    should "know how to build debug messages" do
      msg = Factory.string
      exp = "[DEBUG] #{msg}"
      assert_equal exp, subject.debug_msg(msg)
    end

    should "know how to build bench start messages" do
      msg = Factory.string
      exp = subject.debug_msg("#{msg}...".ljust(30))
      assert_equal exp, subject.bench_start_msg(msg)

      msg = Factory.string(35)
      exp = subject.debug_msg("#{msg}...".ljust(30))
      assert_equal exp, subject.bench_start_msg(msg)
    end

    should "know how to build bench finish messages" do
      time_in_ms = Factory.float
      exp = " (#{time_in_ms} ms)"
      assert_equal exp, subject.bench_finish_msg(time_in_ms)
    end
  end

  class BenchTests < InitTests
    desc "`bench`"
    setup do
      @start_msg   = Factory.string
      @proc        = proc{}
      @test_output = +""
    end

    let(:config) { unit_class.new(StringIO.new(@test_output)) }

    should "not output any stdout info if not in debug mode" do
      Assert.stub(subject, :debug){ false }

      subject.bench(@start_msg, &@proc)

      assert_empty @test_output
    end

    should "output any stdout info if in debug mode" do
      Assert.stub(subject, :debug){ true }

      time_in_ms = subject.bench(@start_msg, &@proc)

      exp = "#{subject.bench_start_msg(@start_msg)}"\
            "#{subject.bench_finish_msg(time_in_ms)}\n"
      assert_equal exp, @test_output
    end
  end

  class SuiteUnitTests < UnitTests
    desc "Suite"
    subject{ suite_class }

    let(:suite_class) { unit_class::Suite }
  end

  class SuiteInitTests < SuiteUnitTests
    desc "when init"
    subject{ suite }

    let(:suite) {
      suite_class.new(
        default_cmd:      "DEFAULT TEST CMD1",
        verbose_cmd:      "VERBOSE TEST CMD1",
        test_dir:              "TEST DIR1",
        test_file_suffixes:    ["TEST SUFFIX 1", "TEST SUFFIX 2"],
        parallel_env_var_name: "PARALLEL ENV VAR",
        seed_env_var_name:     "SEED ENV VAR ",
        env_vars:              "ENV_VAR1=value1 ENV_VAR2=value2",
      )
    }

    should have_readers :default_cmd, :verbose_cmd
    should have_readers :test_dir, :test_file_suffixes
    should have_readers :parallel_env_var_name, :seed_env_var_name, :env_vars

    should "know its attributes" do
      assert_that(subject.default_cmd).equals("DEFAULT TEST CMD1")
      assert_that(subject.verbose_cmd).equals("VERBOSE TEST CMD1")
      assert_that(subject.test_dir).equals("TEST DIR1")
      assert_that(subject.test_file_suffixes)
        .equals(["TEST SUFFIX 1", "TEST SUFFIX 2"])
      assert_that(subject.parallel_env_var_name).equals("PARALLEL ENV VAR")
      assert_that(subject.seed_env_var_name).equals("SEED ENV VAR ")
      assert_that(subject.env_vars).equals("ENV_VAR1=value1 ENV_VAR2=value2")
    end

    should "default its attributes" do
      suite = suite_class.new(default_cmd: "DEFAULT TEST CMD1")

      assert_that(suite.default_cmd).equals("DEFAULT TEST CMD1")
      assert_that(suite.verbose_cmd).equals("DEFAULT TEST CMD1")
      assert_that(suite.test_dir).equals("test")
      assert_that(suite.test_file_suffixes).equals(["_test.rb"])
      assert_that(suite.parallel_env_var_name).equals("PARALLEL_WORKERS")
      assert_that(suite.seed_env_var_name).equals("SEED")
      assert_that(suite.env_vars).equals("")
    end
  end
end
