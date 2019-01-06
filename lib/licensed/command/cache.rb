# frozen_string_literal: true
module Licensed
  module Command
    class Cache
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def run(force: false)
        summary = @config.apps.flat_map do |app|
          app_name = app["name"]
          @config.ui.info "Caching licenses for #{app_name}:"

          # load the app environment
          Dir.chdir app.source_path do

            # map each available app source to it's dependencies
            app.sources.map do |source|
              type = source.class.type

              @config.ui.info "  #{type} dependencies:"

              names = []
              cache_path = app.cache_path.join(type)

              # ensure each dependency is cached
              source.dependencies.each do |dependency|
                name = dependency.name
                version = dependency.version

                names << name
                filename = cache_path.join("#{name}.dependency")

                # try to load existing license from disk
                # or default to a blank license
                license = Licensed::License.read(filename) || Licensed::License.new

                # cached version string exists and did not change, no need to re-cache
                has_version = !license["version"].nil? && !license["version"].empty?
                if !force && has_version && version == license["version"]
                  @config.ui.info "    Using #{name} (#{version})"
                  next
                end

                @config.ui.info "    Caching #{name} (#{version})"

                # use the cached license value if the license text wasn't updated
                dependency.data["license"] = license["license"] if dependency.data.matches?(license)

                dependency.data.save(filename)
              end

              # Clean up cached files that dont match current dependencies
              Dir.glob(cache_path.join("**/*.dependency")).each do |file|
                file_path = Pathname.new(file)
                relative_path = file_path.relative_path_from(cache_path).to_s
                FileUtils.rm(file) unless names.include?(relative_path.chomp(".dependency"))
              end

              "* #{app_name} #{type} dependencies: #{source.dependencies.size}"
            end
          end
        end

        @config.ui.confirm "License caching complete!"
        summary.each do |message|
          @config.ui.confirm message
        end
      end

      def success?
        true
      end
    end
  end
end
