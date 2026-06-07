# lib/dam/database.rb
require "sqlite3"
require "singleton"
require "fileutils"

module Dam
  class Database
    include Singleton

    DB_PATH = File.expand_path("~/.dam/sessions.db")

    def initialize
      FileUtils.mkdir_p(File.dirname(DB_PATH))
      @db = SQLite3::Database.new(DB_PATH)
      @db.results_as_hash = true
      migrate!
    end

    def migrate!
      @db.execute <<~SQL
        CREATE TABLE IF NOT EXISTS sessions (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          project     TEXT NOT NULL,
          branch      TEXT NOT NULL DEFAULT 'unknown',
          started_at  INTEGER NOT NULL,
          ended_at    INTEGER,
          duration_s  INTEGER
        );
      SQL

      @db.execute <<~SQL
        CREATE INDEX IF NOT EXISTS idx_sessions_project
          ON sessions(project, started_at);
      SQL
    end

    def insert_session(project:, branch:, started_at:, ended_at:, duration_s:)
      @db.execute(
        "INSERT INTO sessions (project, branch, started_at, ended_at, duration_s)
         VALUES (?, ?, ?, ?, ?)",
        [project, branch, started_at.to_i, ended_at.to_i, duration_s]
      )
    end

    def sessions_since(timestamp)
      @db.execute(
        "SELECT * FROM sessions WHERE started_at >= ? ORDER BY started_at DESC",
        [timestamp.to_i]
      )
    end

    def aggregate_by_project(since:)
      @db.execute(<<~SQL, [since.to_i])
        SELECT
          project,
          branch,
          COUNT(*)        AS session_count,
          SUM(duration_s) AS total_seconds
        FROM sessions
        WHERE started_at >= ?
        GROUP BY project, branch
        ORDER BY total_seconds DESC
      SQL
    end
  end
end