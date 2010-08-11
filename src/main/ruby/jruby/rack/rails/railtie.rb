require 'rails/railtie'
require 'pathname'

module JRuby::Rack
  class Railtie < ::Rails::Railtie
    initializer "set_webapp_public_path", :before => "action_controller.set_configs" do |app|
      old_public  = Pathname.new(app.config.paths.public.to_a.first)
      new_public  = Pathname.new(JRuby::Rack.booter.public_path)
      javascripts = Pathname.new(app.config.paths.public.javascripts.to_a.first)
      stylesheets = Pathname.new(app.config.paths.public.stylesheets.to_a.first)
      app.config.paths.public = new_public.to_s
      app.config.paths.public.javascripts = new_public.join(javascripts.relative_path_from(old_public)).to_s
      app.config.paths.public.stylesheets = new_public.join(stylesheets.relative_path_from(old_public)).to_s
    end

    initializer "set_servlet_logger", :after => :initialize_logger do |app|
      class << app.config.logger # Make these accessible to wire in the log device
        public :instance_variable_get, :instance_variable_set
      end
      old_device = app.config.logger.instance_variable_get "@log"
      old_device.close rescue nil
      app.config.logger.instance_variable_set "@log", JRuby::Rack.booter.logdev
    end

    initializer "set_relative_url_root", :before => "action_controller.set_configs" do |app|
      path = nil
      begin
        path = JRuby::Rack.booter.rack_context.getContextPath
      rescue Exception
        path = JRuby::Rack.booter.rack_context.getInitParameter('app-context-path')
      end
      if path && !path.empty?
        ENV['RAILS_RELATIVE_URL_ROOT'] = path
        app.config.action_controller.relative_url_root = path
      end

    end
  end
end
