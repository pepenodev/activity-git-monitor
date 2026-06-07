require "spec_helper"
require "dam"

RSpec.describe Dam::GitPoller do
  describe ".project_name" do
    it "retrieve the directory name" do
      expect(Dam::GitPoller.project_name("C:\\Users\\pepe\\proyectos\\mi-app")).to eq("mi-app")
    end

    it "returns “unknown” if the path is nil" do
      expect(Dam::GitPoller.project_name(nil)).to eq("unknown")
    end
  end

  describe ".current_branch" do
    it "returns “not-git” if the path is nil" do
      expect(Dam::GitPoller.current_branch(nil)).to eq("no-git")
    end

    it "returns the current branch of the ongoing project" do
      current_dir = Dir.pwd
      branch = Dam::GitPoller.current_branch(current_dir)
      expect(branch).not_to be_empty
      expect(branch).not_to eq("no-git")
    end
  end

  describe ".active_project" do
    it "devuelve nil o una ruta válida" do
      result = Dam::GitPoller.active_project
      if result
        expect(File.directory?(result)).to be true
      else
        expect(result).to be_nil
      end
    end
  end
end