# lib/dam/git_poller.rb (versión Windows)
require "fiddle"
require "fiddle/import"

module Dam
  module Win32
    extend Fiddle::Importer
    dlload "user32"
    extern "int GetForegroundWindow()"
    extern "int GetWindowThreadProcessId(int, void*)"
  end

  class GitPoller
    def self.active_project
      hwnd = Win32.GetForegroundWindow()
      return nil if hwnd == 0

      pid_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      Win32.GetWindowThreadProcessId(hwnd, pid_buf)
      pid = pid_buf[0, Fiddle::SIZEOF_INT].unpack1("L")

      cwd = process_cwd_windows(pid)
      return nil unless cwd

      git_root(cwd)
    end

    def self.current_branch(project_path)
      return "no-git" unless project_path
      branch = `git -C "#{project_path}" rev-parse --abbrev-ref HEAD 2>NUL`.strip
      branch.empty? ? "no-git" : branch
    end

    def self.project_name(project_path)
      return "unknown" unless project_path
      File.basename(project_path)
    end

    private

    def self.process_cwd_windows(pid)
      # Usa wmic para obtener el directorio de trabajo del proceso
      result = `wmic process where ProcessId=#{pid} get ExecutablePath 2>NUL`.strip
      path = result.lines.last&.strip
      return nil if path.nil? || path.empty? || path == "ExecutablePath"
      File.dirname(path)
    end

    def self.git_root(path)
      root = `git -C "#{path}" rev-parse --show-toplevel 2>NUL`.strip
      root.empty? ? nil : root.gsub("/", "\\")
    end
  end
end