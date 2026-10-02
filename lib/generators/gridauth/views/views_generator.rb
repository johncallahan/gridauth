require "rails/generators"

module Gridauth
  module Generators
    # Copies the engine's views into app/views/gridauth for customization.
    class ViewsGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../../app/views/gridauth", __dir__)

      def copy_views
        directory ".", "app/views/gridauth"
      end
    end
  end
end
