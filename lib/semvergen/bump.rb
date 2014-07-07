module Semvergen

  class Bump

    extend Forwardable

    PATCH = "Patch: Bug fixes, recommended for all (default)"
    MINOR = "Minor: New features, but backwards compatible"
    MAJOR = "Major: Breaking changes"

    RELEASE_TYPES = [
      PATCH,
      MINOR,
      MAJOR
    ]

    def_delegators :@interface, :say, :ask, :color, :choose, :newline, :agree

    def initialize(interface, version_file, change_log_file, shell)
      @interface = interface
      @version_file = version_file
      @change_log_file = change_log_file
      @shell = shell
    end

    def run!(options)
      if @shell.git_index_dirty? && !options[:ignore_dirty]
        say color("Git index dirty. Commit changes before continuing", :red, :bold)
      else
        say color("Cut new Quattro Release", :white, :underline, :bold)

        newline

        release_type = choose do |menu|
          menu.header    = "Select release type"
          menu.default   = "1"
          menu.select_by = :index
          menu.choices *RELEASE_TYPES
        end

        new_version = next_version(@version_file.version, release_type)

        newline

        say "Current version: #{color(@version_file.version, :bold)}"
        say "Bumped version : #{color(new_version, :bold, :green)}"

        newline

        say "Enter change log features (or a blank line to finish):"

        features = []

        while true
          response = ask "* " do |q|
            q.validate                 = lambda { |answer| features.size > 0 || answer.length > 0 }
            q.responses[:not_valid]    = color("Enter at least one feature", :red)
            q.responses[:invalid_type] = color("Enter at least one feature", :red)
            q.responses[:ask_on_error] = "* "
          end

          if response.length == 0
            features << "\n"
            break
          else
            features << "* #{response}"
          end
        end

        change_log_lines   = ["# #{new_version}"] + features
        change_log_message = change_log_lines.join("\n")
        diff_change_log    = change_log_lines.map { |l| color("+++ ", :white) + color(l, :green) }.join("\n")

        newline

        say color("Will add the following to CHANGELOG.md", :underline)
        say color(diff_change_log)

        commit_message = ask("Git commit subject line: ") do |q|
          q.validate                 = /.{10,}/
          q.responses[:not_valid]    = color("Message must be more than 10 chars", :red)
          q.responses[:invalid_type] = color("Message must be more than 10 chars", :red)
        end

        newline

        say color("Summary of actions:", :underline, :green, :red)
        newline

        say "Bumping version: #{color(@version_file.version, :yellow)} -> #{color(new_version, :green)}"
        newline

        say "Adding features to CHANGELOG.md:"
        say color(diff_change_log, :green)

        say "Staging files for commit:"
        say color("* lib/quattro/version.rb", :green)
        say color("* CHANGELOG.md", :green)
        newline

        say "Committing with message: #{color(commit_message, :green)}"
        newline

        if agree("Proceed? ")
          @version_file.version = new_version

          @change_log_file << change_log_message

          @shell.commit(@version_file.path, new_version, commit_message, features)

          newline

          say color("To release, use rake release", :bold, :green)
        end
      end
    end

    def next_version(current_version, release_type)
      version_tuples = current_version.split(".")

      release_index = 2 - RELEASE_TYPES.index(release_type)

      bumping   = version_tuples[release_index]
      unchanged = version_tuples[0...release_index]
      zeroing   = version_tuples[(release_index + 1)..-1]

      new_version_tuples = unchanged + [bumping.to_i + 1] + (["0"] * zeroing.size)

      new_version_tuples.join(".")
    end

  end

end
