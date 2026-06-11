gemfile = File.expand_path("../../Gemfile", __dir__)
ENV["BUNDLE_GEMFILE"] = gemfile

require "bundler/setup"
require_relative "../dam"

project_dir = ARGV[0]

if project_dir.nil? || project_dir.strip.empty?
  warn "Error: no project directory provided."
  warn "Usage: daemon_runner.rb <project_dir>"
  exit 1
end

unless Dir.exist?(File.join(project_dir, ".git"))
  warn "Error: #{project_dir} is not a git repository."
  exit 1
end

Dam::Log.setup(verbose: false)
Dam::Daemon.new(project_dir).start