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
    EDITORS = ["Code", "idea64", "rubymine64", "sublime_text", "atom"].freeze

    def self.active_project
      hwnd = Win32.GetForegroundWindow()
      return nil if hwnd == 0

      pid = foreground_pid(hwnd)
      return nil unless pid && pid > 0

      cwd = process_cwd(pid)
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

    def self.foreground_pid(hwnd)
      pid_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_LONG)
      Win32.GetWindowThreadProcessId(hwnd, pid_buf)
      pid_buf[0, Fiddle::SIZEOF_LONG].unpack1("L")
    end

    def self.process_cwd(pid)
      EDITORS.each do |editor|
        title = `powershell -NoProfile -Command "Get-Process '#{editor}' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty MainWindowTitle"`.strip
        next if title.empty?

        if editor == "Code"
          parts = title.split(" - ").map(&:strip)
          folder = parts[-2]
          next if folder.nil? || folder.empty?

          ["C:\\Users\\#{ENV['USERNAME']}\\Desktop\\Proyectos",
          "C:\\Users\\#{ENV['USERNAME']}",
          "C:\\"].each do |base|
            candidate = File.join(base, folder)
            return candidate if File.directory?(candidate)
          end
        end
      end

      raw = `powershell -NoProfile -Command "(Get-Process -Id #{pid} -ErrorAction SilentlyContinue).MainModule.FileName"`.strip
      return nil if raw.empty?
      File.dirname(raw)
    end

    def self.git_root(path)
      return nil unless path && File.directory?(path)
      root = `git -C "#{path}" rev-parse --show-toplevel 2>NUL`.strip
      return nil if root.empty?
      root.gsub("/", "\\")
    end
  end
end