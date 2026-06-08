gemfile = File.expand_path("../../Gemfile", __dir__)
ENV["BUNDLE_GEMFILE"] = gemfile

require "bundler/setup"
require_relative "../dam"

Dam::Log.setup(verbose: false)
Dam::Daemon.new.start