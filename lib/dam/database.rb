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
      @db.execute("PRAGMA journal_mode=WAL;")

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

    def close_open_sessions!
      now = Time.now.to_i
      @db.execute(<<~SQL, [now, now])
        UPDATE sessions
        SET ended_at   = ?,
            duration_s = ? - started_at
        WHERE ended_at IS NULL
          AND duration_s IS NULL
      SQL

      count = @db.changes
      Log.info("Closed #{count} orphan session(s) from previous run") if count > 0
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
          AND duration_s IS NOT NULL
          AND duration_s > 0
        GROUP BY project, branch
        ORDER BY total_seconds DESC
      SQL
    end

    def activity_by_day(since:)
      @db.execute(<<~SQL, [since.to_i])
        SELECT
          DATE(started_at, 'unixepoch', 'localtime') AS day,
          SUM(duration_s) AS total_seconds
        FROM sessions
        WHERE started_at >= ?
          AND duration_s IS NOT NULL
          AND duration_s > 0
        GROUP BY day
        ORDER BY day ASC
      SQL
    end

    def sessions_detail(since:)
      @db.execute(<<~SQL, [since.to_i])
        SELECT
          id,
          project,
          branch,
          started_at,
          ended_at,
          duration_s,
          DATE(started_at, 'unixepoch', 'localtime') AS day,
          TIME(started_at, 'unixepoch', 'localtime') AS start_time,
          TIME(ended_at,   'unixepoch', 'localtime') AS end_time
        FROM sessions
        WHERE started_at >= ?
          AND duration_s IS NOT NULL
          AND duration_s > 0
        ORDER BY started_at DESC
      SQL
    end

    def aggregate_by_project_and_day(since:)
      @db.execute(<<~SQL, [since.to_i])
        SELECT
          project,
          DATE(started_at, 'unixepoch', 'localtime') AS day,
          SUM(duration_s) AS total_seconds
        FROM sessions
        WHERE started_at >= ?
          AND duration_s IS NOT NULL
          AND duration_s > 0
        GROUP BY project, day
        ORDER BY day ASC
      SQL
    end
  end
end