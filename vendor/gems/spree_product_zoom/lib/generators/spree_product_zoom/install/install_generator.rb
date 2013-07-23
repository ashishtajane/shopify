module SpreeProductZoom
  module Generators
    class InstallGenerator < Rails::Generators::Base

      def add_javascripts
        append_file 'app/assets/javascripts/store/all.js', "//= require store/spree_product_zoom\n"
      end

      def add_stylesheets
        inject_into_file 'app/assets/stylesheets/store/all.css', " *= require store/spree_product_zoom\n", :before => /\*\//, :verbose => true
      end
    end
  end
end
