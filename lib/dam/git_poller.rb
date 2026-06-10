module Dam
  class GitPoller
    def initialize(project_dir)
      @project_dir = project_dir
    end

    def poll
      branch = current_branch
      return nil unless branch

      { project: File.basename(@project_dir), branch: branch, dir: @project_dir }
    end

    private

    def current_branch
      if Gem.win_platform?
        output = `git -C "#{@project_dir}" rev-parse --abbrev-ref HEAD 2>NUL`.strip
      else
        output = `git -C "#{@project_dir}" rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
      end
      output.empty? ? nil : output
    end
  end
end