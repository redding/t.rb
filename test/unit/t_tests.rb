# frozen_string_literal: true

require "assert"
require "libexec/t"

module TdotRB
  class UnitTests < Assert::Context
    desc "TdotRB"
    subject{ unit_module }

    let(:unit_module) { TdotRB }

    should have_imeths :config, :apply, :bench, :run

    should "know its config singleton" do
      assert_instance_of Config, subject.config
      assert_same subject.config, subject.config
    end
  end
end
