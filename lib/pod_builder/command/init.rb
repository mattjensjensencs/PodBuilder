require 'pod_builder/core'

module PodBuilder
  module Command
    class Init
      def self.call(options)
        raise "\n\nAlready initialized\n".red if Configuration.exists

        xcworkspace = Dir.glob("*.xcworkspace")
        raise "\n\nNo xcworkspace found in current folder\n" if xcworkspace.count == 0
        raise "\n\nToo many xcworkspaces found in current folder\n#{xcworkspace}\n" if xcworkspace.count > 1

        Configuration.project_name = File.basename(xcworkspace.first, ".*")
        
        options[:prebuild_path] ||= Configuration.base_path

        if File.expand_path(options[:prebuild_path]) != options[:prebuild_path] # if not absolute
          options[:prebuild_path] = File.expand_path(PodBuilder::project_path(options[:prebuild_path]))
        end

        FileUtils.mkdir_p(options[:prebuild_path])
        FileUtils.mkdir_p("#{options[:prebuild_path]}/.pod_builder")
        FileUtils.touch("#{options[:prebuild_path]}/.pod_builder/pod_builder")

        source_path_rel_path = "Sources"
        development_pods_config_rel_path = Configuration.dev_pods_configuration_filename

        git_ignores = ["Pods/",
                       "*.xcworkspace",
                       "*.xcodeproj",
                       "Podfile.lock",
                       source_path_rel_path,
                       development_pods_config_rel_path]
        
        File.write("#{options[:prebuild_path]}/.gitignore", git_ignores.join("\n"))

        project_podfile_path = PodBuilder::project_path("Podfile")
        prebuilt_podfile_path = File.join(options[:prebuild_path], "Podfile")
        FileUtils.cp(project_podfile_path, prebuilt_podfile_path)
        
        Podfile.add_install_block(prebuilt_podfile_path)
        Podfile.update_path_entires(prebuilt_podfile_path, false, PodBuilder::project_path(""))
        Podfile.update_project_entries(prebuilt_podfile_path, false, PodBuilder::project_path(""))

        Configuration.write

        update_gemfile

        puts "\n\n🎉 done!\n".green
        return 0
      end

      private 

      def self.update_gemfile
        gemfile_path = File.join(PodBuilder::home, "Gemfile")
        unless File.exist?(gemfile_path)
          FileUtils.touch(gemfile_path)
        end

        source_line = "source 'https://rubygems.org'"
        podbuilder_line = "gem 'pod-builder'"

        gemfile = File.read(gemfile_path)

        gemfile_lines = gemfile.split("\n")
        gemfile_lines.select! { |x| !trim_gemfile_line(x).include?(trim_gemfile_line(source_line)) }
        gemfile_lines.select! { |x| !trim_gemfile_line(x).include?(trim_gemfile_line(podbuilder_line)) }

        gemfile_lines.insert(0, source_line)
        gemfile_lines.push(podbuilder_line)
     
        File.write(gemfile_path, gemfile_lines.join("\n"))

        Dir.chdir(PodBuilder::home)
        system("bundle")
      end

      def self.trim_gemfile_line(line)
        return line.gsub("\"", "'").gsub(" ", "")
      end
    end
  end
end
