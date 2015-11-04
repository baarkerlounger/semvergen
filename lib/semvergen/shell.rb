module Semvergen

  class Shell

    def initialize(execute_function = method(:system_exec).to_proc)
      @execute_function = execute_function
    end

    def git_index_dirty?
      execute("git status --porcelain") =~ /^\s*(D|M|A|R|C)\s/
    end

    def current_branch
      execute("git symbolic-ref --short HEAD").strip
    end

    def git_fetch
      `git fetch -q`
    end

    def git_branch_is_tracking?
      `git rev-list HEAD..@{u} --count` and return $?.exitstatus == 0
    end

    def git_up_to_date?
      `git rev-list HEAD..@{u} --count`.strip.to_i == 0
    end

    def commit(version_path, new_version, commit_subject, features)
      commit_body = COMMIT_MESSAGE % [new_version, commit_subject, features.join("\n")]

      execute "git add CHANGELOG.md"
      execute "git add #{version_path}"
      execute %Q[git commit -m "#{commit_body}"]
      execute %Q[git tag #{new_version} -a -m "Version: #{new_version} - #{commit_subject}"]
    end

    def push(new_version, remote_name="origin", branch_name=current_branch)
      execute "git push -q #{remote_name} #{branch_name} #{new_version}"
    end

    def build_gem(gem_name)
      execute "gem build #{gem_name}.gemspec --force"
    end

    def publish(gem_name, version, gem_server)
      execute "gem inabox #{gem_name}-#{version}.gem --host #{gem_server}"
    end

    def cleanup(gem_name, version)
      execute "rm #{gem_name}-#{version}.gem"
    end

    private

    def execute(command)
      @execute_function[command]
    end

    def system_exec(command)
      result = `#{command}`
      raise if $?.exitstatus > 0
      result
    end

    COMMIT_MESSAGE = <<-STR
Version %s: %s

%s
    STR

  end

end