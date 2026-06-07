require "spec_helper"
require "dam"

RSpec.describe "Dam setup" do
  it "modules without error" do
    expect(defined?(Dam)).to eq("constant")
  end
end