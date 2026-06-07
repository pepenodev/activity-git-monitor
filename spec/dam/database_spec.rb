require "spec_helper"
require "dam"

RSpec.describe Dam::Database do
  let(:db) { Dam::Database.instance }

  it "initializes correctly" do
    expect(db).not_to be_nil
  end

  it "insert and restore a session" do
    now = Time.now.to_i

    db.insert_session(
      project:    "test-project",
      branch:     "main",
      started_at: now - 120,
      ended_at:   now,
      duration_s: 120
    )

    sessions = db.sessions_since(now - 300)
    expect(sessions).not_to be_empty
    expect(sessions.first["project"]).to eq("test-project")
    expect(sessions.first["branch"]).to eq("main")
  end

  it "add time by project and branch" do
    results = db.aggregate_by_project(since: Time.now - 3600)
    expect(results).to be_an(Array)
    expect(results.first["total_seconds"]).to be > 0
  end
end