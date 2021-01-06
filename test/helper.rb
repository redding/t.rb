# frozen_string_literal: true

# this file is automatically required when you run `assert`
# put any test helpers here

# add the root dir to the load path
$LOAD_PATH.unshift(File.expand_path("../..", __FILE__))

ENV['TDOTRB_DISABLE_RUN'] = "yes"

# require pry for debugging (`binding.pry`)
require "pry"

require "test/support/factory"

TEST_SUPPORT_PATH = File.expand_path("../support", __FILE__)
