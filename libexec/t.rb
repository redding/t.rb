#!/usr/bin/env ruby

# frozen_string_literal: true

require "benchmark"
require "set"
require "yaml"

module TdotRB
  VERSION = "0.0.1"

  class Config
    SUITES_FILE_PATH = "./.t.yml"

    def self.settings(*items)
      items.each do |item|
        define_method(item) do |*args|
          if !(value = args.size > 1 ? args : args.first).nil?
            instance_variable_set("@#{item}", value)
          end
          instance_variable_get("@#{item}")
        end
      end
    end

    attr_reader :stdout, :suites, :version

    settings :seed_value, :changed_only, :changed_ref, :parallel_workers
    settings :verbose, :dry_run, :list, :debug

    def initialize(stdout = nil)
      @stdout = stdout || $stdout
      @suites = []
      @version = VERSION

      # cli option settings
      @seed_value       = begin; srand; srand % 0xFFFF; end.to_i
      @changed_only     = false
      @changed_ref      = ""
      @parallel_workers = nil
      @verbose          = false
      @dry_run          = false
      @list             = false
      @debug            = false
    end

    def apply(settings)
      settings.keys.each do |name|
        if !settings[name].nil? && self.respond_to?(name.to_s)
          self.send(name.to_s, settings[name])
        end
      end
    end

    def load_suites
      @suites =
        [YAML.load(File.read(SUITES_FILE_PATH))]
          .flatten
          .map { |suite_hash|
            Suite.new(**suite_hash.transform_keys(&:to_sym))
          }
    end

    def debug_msg(msg)
      "[DEBUG] #{msg}"
    end

    def debug_puts(msg)
      self.puts debug_msg(msg)
    end

    def puts(msg)
      stdout.puts msg
    end

    def print(msg)
      stdout.print msg
    end

    def bench(start_msg, &block)
      if !debug
        block.call; return
      end
      self.print bench_start_msg(start_msg)
      RoundedMillisecondTime.new(Benchmark.measure(&block).real).tap do |time_in_ms|
        self.puts bench_finish_msg(time_in_ms)
      end
    end

    def bench_start_msg(msg)
      debug_msg("#{msg}...".ljust(30))
    end

    def bench_finish_msg(time_in_ms)
      " (#{time_in_ms} ms)"
    end

    class Suite
      attr_reader :default_cmd, :verbose_cmd
      attr_reader :test_dir, :test_file_suffixes
      attr_reader :parallel_env_var_name, :seed_env_var_name, :env_vars

      def initialize(
            default_cmd:,
            verbose_cmd: nil,
            test_dir: nil,
            test_file_suffixes: nil,
            parallel_env_var_name: nil,
            seed_env_var_name: nil,
            env_vars: nil)
        @default_cmd      = default_cmd
        @verbose_cmd      = verbose_cmd || @default_cmd
        @test_dir              = test_dir || "test"
        @test_file_suffixes    = test_file_suffixes || ["_test.rb"]
        @parallel_env_var_name = parallel_env_var_name || "PARALLEL_WORKERS"
        @seed_env_var_name     = seed_env_var_name || "SEED"
        @env_vars              = env_vars || ""
      end
    end
  end

  class Runner
    attr_reader :test_paths, :config

    def initialize(test_paths, config:)
      @test_paths = test_paths
      @config = config
    end

    def run
      @config.suites.each do |suite|
        run_suite(suite)
      end
    end

    def run_suite(suite)
      paths = test_paths.empty? ? [*suite.test_dir] : test_paths
      test_files = lookup_test_files(paths, suite)

      if config.debug
        config.debug_puts "#{test_files.size} Test files:"
        test_files.each do |fa|
          config.debug_puts "  #{fa}"
        end
      end

      cmd_str =
        "#{cmd_str_env(suite)} #{cmd_str_cmd(suite)} #{test_files.join(" ")}"
      if config.debug && !test_files.empty?
        config.debug_puts "Test command:"
        config.debug_puts "  #{cmd_str}"
      end

      if execute_cmd_str?(test_files)
        system(cmd_str)
      else
        config.puts test_files.join("\n") if config.list
        config.puts cmd_str               if config.dry_run
      end
    end

    private

    def execute_cmd_str?(test_files)
      !test_files.empty? && !config.dry_run && !config.list
    end

    def cmd_str_env(suite)
      (+"").tap do |s|
        s << suite.env_vars
        s << " #{suite.seed_env_var_name}=#{config.seed_value}"
        if config.parallel_workers
          s << " #{suite.parallel_env_var_name}=#{config.parallel_workers}"
        end
      end
    end

    def cmd_str_cmd(suite)
      config.verbose ? suite.verbose_cmd : suite.default_cmd
    end

    def lookup_test_files(test_paths, suite)
      files = nil

      if config.changed_only
        result = nil
        TdotRB.bench("Lookup changed test files") do
          result = changed_test_files(test_paths, suite)
        end
        files = result.files
        if config.debug
          config.debug_puts "  `#{result.cmd}`"
        end
      else
        TdotRB.bench("Lookup test files") do
          files = filtered_test_files(test_paths, suite)
        end
      end

      files
    end

    def changed_test_files(test_paths, suite)
      result = GitChangedFiles.new(config, test_paths)
      ChangedResult.new(result.cmd, filtered_test_files(result.files, suite))
    end

    def filtered_test_files(test_paths, suite)
      test_paths
        .reduce(Set.new) { |files, path|
          files +=
            if is_single_test?(path, suite)
              [path]
            else
              globbed_test_files(path, suite)
            end
        }
        .sort
    end

    def globbed_test_files(test_path, suite)
      pwd = Dir.pwd
      path = File.expand_path(test_path, pwd)
      (Dir.glob("#{path}*") + Dir.glob("#{path}*/**/*"))
        .select{ |p| is_test_file?(p, suite) }
        .map{ |p| p.gsub("#{pwd}/", "") }
    end

    def is_single_test?(file_line_path, suite)
      file, line =
        (file_line_path.to_s.match(/(^[^\:]*)\:*(\d*).*$/) || [])[1..2]
      !line.empty? && is_test_file?(file, suite)
    end

    def is_test_file?(path, suite)
      [*suite.test_file_suffixes].reduce(false) do |result, suffix|
        result || path =~ /#{suffix}$/
      end
    end
  end

  ChangedResult = Struct.new(:cmd, :files)

  module GitChangedFiles
    def self.cmd(config, test_paths)
      [ "git diff --no-ext-diff --name-only #{config.changed_ref}", # changed files
        "git ls-files --others --exclude-standard"                  # added files
      ].map{ |c| "#{c} -- #{test_paths.join(" ")}" }.join(" && ")
    end

    def self.new(config, test_paths)
      cmd = self.cmd(config, test_paths)
      ChangedResult.new(cmd, `#{cmd}`.split("\n"))
    end
  end

  module RoundedMillisecondTime
    ROUND_PRECISION = 3
    ROUND_MODIFIER = 10 ** ROUND_PRECISION
    def self.new(time_in_seconds)
      (time_in_seconds * 1000 * ROUND_MODIFIER).to_i / ROUND_MODIFIER.to_f
    end
  end

  class CLIRB  # Version 1.1.0, https://github.com/redding/cli.rb
    Error    = Class.new(RuntimeError);
    HelpExit = Class.new(RuntimeError); VersionExit = Class.new(RuntimeError)
    attr_reader :argv, :args, :opts, :data

    def initialize(&block)
      @options = []; instance_eval(&block) if block
      require "optparse"
      @data, @args, @opts = [], [], {}; @parser = OptionParser.new do |p|
        p.banner = ""; @options.each do |o|
          @opts[o.name] = o.value; p.on(*o.parser_args){ |v| @opts[o.name] = v }
        end
        p.on_tail("--version", ""){ |v| raise VersionExit, v.to_s }
        p.on_tail("--help",    ""){ |v| raise HelpExit,    v.to_s }
      end
    end

    def option(*args); @options << Option.new(*args); end
    def parse!(argv)
      @args = (argv || []).dup.tap do |args_list|
        begin; @parser.parse!(args_list)
        rescue OptionParser::ParseError => err; raise Error, err.message; end
      end; @data = @args + [@opts]
    end
    def to_s; @parser.to_s; end
    def inspect
      "#<#{self.class}:#{"0x0%x" % (object_id << 1)} @data=#{@data.inspect}>"
    end

    class Option
      attr_reader :name, :opt_name, :desc, :abbrev, :value, :klass, :parser_args

      def initialize(name, desc = nil, abbrev: nil, value: nil)
        @name, @desc = name, desc || ""
        @opt_name, @abbrev = parse_name_values(name, abbrev)
        @value, @klass = gvalinfo(value)
        @parser_args = if [TrueClass, FalseClass, NilClass].include?(@klass)
          ["-#{@abbrev}", "--[no-]#{@opt_name}", @desc]
        else
          ["-#{@abbrev}", "--#{@opt_name} VALUE", @klass, @desc]
        end
      end

      private

      def parse_name_values(name, custom_abbrev)
        [ (processed_name = name.to_s.strip.downcase).gsub("_", "-"),
          custom_abbrev || processed_name.gsub(/[^a-z]/, "").chars.first || "a"
        ]
      end
      def gvalinfo(v); v.kind_of?(Class) ? [nil,v] : [v,v.class]; end
    end
  end

  # TdotRB

  def self.clirb
    @clirb ||= CLIRB.new do
      option "seed_value", "use a given seed to run tests", {
        abbrev: "s", value: Integer
      }
      option "changed_only", "only run test files with changes", {
        abbrev: "c"
      }
      option "changed_ref", "reference for changes, use with `-c` opt", {
        abbrev: "r", value: ""
      }
      option "parallel_workers", "number of parallel workers to use (if applicable)", {
        abbrev: "p", value: Integer
      }
      option "verbose", "output verbose runtime test info", {
        abbrev: "v"
      }
      option "dry_run", "output the test command to $stdout"
      option "list", "list test files on $stdout", {
        abbrev: "l"
      }
      # show loaded test files, cli err backtraces, etc
      option "debug", "run in debug mode", {
        abbrev: "d"
      }
    end
  end

  def self.config
    @config ||= Config.new
  end

  def self.apply(argv)
    clirb.parse!(argv)
    config.apply(clirb.opts)
    config.load_suites
  end

  def self.bench(*args, &block)
    config.bench(*args, &block)
  end

  def self.run
    begin
      bench("ARGV parse and configure"){ apply(ARGV) }
      Runner.new(clirb.args, config: config).run
    rescue CLIRB::HelpExit
      config.puts help_msg
    rescue CLIRB::VersionExit
      config.puts config.version
    rescue CLIRB::Error => exception
      config.puts "#{exception.message}\n\n"
      config.puts config.debug ? exception.backtrace.join("\n") : help_msg
      exit(1)
    rescue StandardError => exception
      config.puts "#{exception.class}: #{exception.message}"
      config.puts exception.backtrace.join("\n")
      exit(1)
    end
    exit(0)
  end

  def self.help_msg
    "Usage: t [options] [TESTS]\n\n"\
    "Options:"\
    "#{clirb}"
  end
end

unless ENV["TDOTRB_DISABLE_RUN"]
  TdotRB.run
end
