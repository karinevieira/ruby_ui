require_relative "javascript_utils"
module RubyUI
  module Generators
    class ComponentGenerator < Rails::Generators::Base
      include RubyUI::Generators::JavascriptUtils

      namespace "ruby_ui:component"

      source_root File.expand_path("../../ruby_ui", __dir__)
      argument :component_name, type: :string, required: true

      def generate_component
        if component_not_found?
          say "Component not found: #{component_name}", :red
          exit
        end

        say "Generating component files"
      end

      def copy_main_component_file
        main_component_file_path = File.join(component_folder_path, "#{component_folder_name}.rb")

        # some components dont't have a main component, eg. Typography
        return unless File.exist? main_component_file_path

        say "Generating main component"

        copy_file main_component_file_path, Rails.root.join("app/components/ruby_ui", "#{component_folder_name}.rb")
      end

      def copy_related_component_files
        return if related_components_file_paths.empty?

        say "Generating related components"

        related_components_file_paths.each do |file_path|
          component_file_name = file_path.split("/").last
          copy_file file_path, Rails.root.join("app/components/ruby_ui", component_folder_name, component_file_name)
        end
      end

      def copy_js_files
        return if js_controller_file_paths.empty?

        say "Generating Stimulus controllers"

        js_controller_file_paths.each do |file_path|
          controller_file_name = file_path.split("/").last
          copy_file file_path, Rails.root.join("app/javascript/controllers/ruby_ui", controller_file_name)
        end

        # Importmap doesn't have controller manifest, instead it uses `eagerLoadControllersFrom("controllers", application)`
        if !using_importmap?
          say "Updating Stimulus controllers manifest"
          run "rake stimulus:manifest:update"
        end
      end

      def install_dependencies
        return if dependencies.blank?

        say "Installing dependencies"

        install_components_dependencies(dependencies["components"])
        install_gems_dependencies(dependencies["gems"])
        install_js_packages(dependencies["js_packages"])
      end

      private

      def component_not_found? = !Dir.exist?(component_folder_path)

      def component_folder_name = component_name.underscore

      def component_folder_path = File.join(self.class.source_root, component_folder_name)

      def main_component_file_path = File.join(component_folder_path, "#{component_folder_name}.rb")

      def related_components_file_paths = Dir.glob(File.join(component_folder_path, "*.rb")) - [main_component_file_path]

      def js_controller_file_paths = Dir.glob(File.join(component_folder_path, "*.js"))

      def install_components_dependencies(components)
        components&.each do |component|
          run "bin/rails generate ruby_ui:component #{component}"
        end
      end

      def install_gems_dependencies(gems)
        gems&.each do |ruby_gem|
          run "bundle show #{ruby_gem} > /dev/null 2>&1 || bundle add #{ruby_gem}"
        end
      end

      def install_js_packages(js_packages)
        js_packages&.each do |js_package|
          install_js_package(js_package)
        end
      end

      def pin_motion
        say <<~TEXT
          WARNING: Installing motion from CDN because `bin/importmap pin motion` doesn't download the correct file.
        TEXT

        inject_into_file Rails.root.join("config/importmap.rb"), <<~RUBY
          pin "motion", to: "https://cdn.jsdelivr.net/npm/motion@11.11.17/+esm"\n
        RUBY
      end

      def pin_tippy_js
        say <<~TEXT
          WARNING: Installing tippy.js from CDN because `bin/importmap pin tippy.js` doesn't download the correct file.
        TEXT

        inject_into_file Rails.root.join("config/importmap.rb"), <<~RUBY
          pin "tippy.js", to: "https://cdn.jsdelivr.net/npm/tippy.js@6.3.7/+esm"
          pin "@popperjs/core", to: "https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.8/+esm"\n
        RUBY
      end

      def dependencies
        @dependencies ||= YAML.load_file(File.join(__dir__, "dependencies.yml")).freeze

        @dependencies[component_folder_name]
      end
    end
  end
end
