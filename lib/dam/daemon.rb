require "fileutils"

module Dam
  class Daemon
    POLL_INTERVAL = 10
    IDLE_TIMEOUT  = 120
    STOP_FILE     = File.expand_path("~/.dam/stop")

    def initialize
      @current_session = nil
      @last_activity   = Time.now
      @db              = Database.instance
    end

    def start
      Log.info("Daemon started (PID: #{Process.pid})")
      File.delete(STOP_FILE) if File.exist?(STOP_FILE)
      @db.close_open_sessions!
      write_pidfile

      loop do
        if File.exist?(STOP_FILE)
          Log.info("Stop file detected, shutting down...")
          File.delete(STOP_FILE)
          break
        end
        tick
        sleep POLL_INTERVAL
      end

      finalize_session
      Log.info("Daemon stopped.")
    rescue Interrupt
      finalize_session
      Log.info("Daemon stopped.")
    ensure
      cleanup_pidfile
    end

    private

    def tick
      project_path = GitPoller.active_project

      if project_path
        project = GitPoller.project_name(project_path)
        branch  = GitPoller.current_branch(project_path)
        now     = Time.now

        if @current_session.nil?
          @current_session = { project: project, branch: branch, started_at: now }
          Log.info("Session started: #{project} (#{branch})")
        elsif session_changed?(project, branch)
          finalize_session
          @current_session = { project: project, branch: branch, started_at: now }
          Log.info("Session changed: #{project} (#{branch})")
        end

        @last_activity = now
      else
        if @current_session && idle?
          Log.info("Idle detected, closing session")
          finalize_session
        end
      end
    end

    def session_changed?(project, branch)
      @current_session[:project] != project || @current_session[:branch] != branch
    end

    def idle?
      Time.now - @last_activity > IDLE_TIMEOUT
    end

    def finalize_session
      return unless @current_session

      ended_at   = Time.now
      duration_s = (ended_at - @current_session[:started_at]).to_i

      if duration_s < 5
        Log.debug("Session too short (#{duration_s}s), skipping")
        @current_session = nil
        return
      end

      @db.insert_session(
        project:    @current_session[:project],
        branch:     @current_session[:branch],
        started_at: @current_session[:started_at],
        ended_at:   ended_at,
        duration_s: duration_s
      )

      Log.info("Session saved: #{@current_session[:project]} — #{duration_s}s")
      @current_session = nil
    end

    def write_pidfile
      FileUtils.mkdir_p(File.expand_path("~/.dam"))
      File.write(File.expand_path("~/.dam/daemon.pid"), Process.pid.to_s)
    end

    def cleanup_pidfile
      File.delete(File.expand_path("~/.dam/daemon.pid")) rescue nil
    end
  end
end