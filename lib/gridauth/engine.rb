module Gridauth
  class Engine < ::Rails::Engine
    initializer "gridauth.model" do
      ActiveSupport.on_load(:active_record) do
        extend Gridauth::Model
      end
    end

    # Keep grid card answers out of the logs.
    initializer "gridauth.filter_parameters" do |app|
      app.config.filter_parameters += [ /\Acells\z/ ]
    end
  end
end
