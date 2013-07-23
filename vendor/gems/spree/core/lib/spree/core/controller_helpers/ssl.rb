module Spree
  module Core
    module ControllerHelpers
      module SSL
        extend ActiveSupport::Concern

        included do
          before_filter :force_non_ssl_redirect, :if => Proc.new { Spree::Config[:redirect_https_to_http] }
          before_filter :force_ssl_redirect, :if => Proc.new { Rails.application.config.force_ssl }

          def self.ssl_allowed(*actions)
            class_attribute :ssl_allowed_actions
            self.ssl_allowed_actions = actions
          end

          def self.ssl_required(*actions)
            class_attribute :ssl_required_actions
            self.ssl_required_actions = actions
            if ssl_supported?
              if ssl_required_actions.empty? or Rails.application.config.force_ssl
                force_ssl
              else
                force_ssl :only => ssl_required_actions
              end
            end
          end

          def self.ssl_supported?
            return Spree::Config[:allow_ssl_in_production] if Rails.env.production?
            return Spree::Config[:allow_ssl_in_staging] if Rails.env.staging?
            return Spree::Config[:allow_ssl_in_development_and_test] if (Rails.env.development? or Rails.env.test?)
          end

          private

            # Redirect the existing request to use the HTTP protocol.
            #
            # ==== Parameters
            # * <tt>host</tt> - Redirect to a different host name
            def force_non_ssl_redirect(host = nil)
              return true if defined?(ssl_allowed_actions) and ssl_allowed_actions.include?(action_name.to_sym)
              if request.ssl? and (!defined?(ssl_required_actions) or !ssl_required_actions.include?(action_name.to_sym))
                redirect_options = {:protocol => 'http://', :status => :moved_permanently}
                redirect_options.merge!(:host => host) if host
                redirect_options.merge!(:params => request.query_parameters)
                flash.keep if respond_to?(:flash)
                redirect_to redirect_options
              end
            end

            # Redirect the existing request to use the HTTPS protocol.
            #
            # ==== Parameters
            # * <tt>host</tt> - Redirect to a different host name
            def force_ssl_redirect(host = nil)
              unless request.ssl?
                redirect_options = {:protocol => 'https://', :status => :moved_permanently}
                redirect_options.merge!(:host => host) if host
                redirect_options.merge!(:params => request.query_parameters)
                flash.keep if respond_to?(:flash)
                redirect_to redirect_options
              end
            end

        end
      end
    end
  end
end
