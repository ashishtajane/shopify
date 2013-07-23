# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "spree_product_zoom"
  s.version = "1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Dyer"]
  s.date = "2013-07-22"
  s.email = "jdyer@spreecommerce.com"
  s.files = [".gitignore", ".rspec", "Gemfile", "Gemfile.lock", "LICENSE", "README.md", "Rakefile", "Versionfile", "app/assets/images/zoom.gif", "app/assets/javascripts/admin/spree_product_zoom.js", "app/assets/javascripts/store/spree_product_zoom.js", "app/assets/javascripts/store/zoom.js.coffee", "app/assets/stylesheets/admin/spree_product_zoom.css", "app/assets/stylesheets/store/spree_product_zoom.css", "app/models/spree/product_zoom_configuration.rb", "app/views/spree/products/_image.html.erb", "app/views/spree/products/_thumbnails.html.erb", "config/locales/en.yml", "config/routes.rb", "lib/generators/spree_product_zoom/install/install_generator.rb", "lib/spree_product_zoom.rb", "lib/spree_product_zoom/engine.rb", "script/rails", "spec/spec_helper.rb", "spree_product_zoom.gemspec", "vendor/assets/images/store/blank.gif", "vendor/assets/images/store/fancybox_buttons.png", "vendor/assets/images/store/fancybox_loading.gif", "vendor/assets/images/store/fancybox_overlay.png", "vendor/assets/images/store/fancybox_sprite.png", "vendor/assets/javascripts/fancybox.js", "vendor/assets/javascripts/jquery.fancybox-buttons.js", "vendor/assets/javascripts/jquery.fancybox-media.js", "vendor/assets/javascripts/jquery.fancybox-thumbs.js", "vendor/assets/javascripts/jquery.fancybox.js", "vendor/assets/stylesheets/fancybox.css", "vendor/assets/stylesheets/jquery.fancybox-thumbs.css", "vendor/assets/stylesheets/jquery.fancybox.css.erb"]
  s.homepage = "http://www.spreecommerce.com"
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.requirements = ["none"]
  s.rubygems_version = "1.8.23"
  s.summary = "Add product image zoom functionality via a lightbox"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<spree_core>, ["~> 2.1.0.beta"])
      s.add_development_dependency(%q<capybara>, ["= 1.0.1"])
      s.add_development_dependency(%q<factory_girl>, ["~> 2.6.4"])
      s.add_development_dependency(%q<ffaker>, [">= 0"])
      s.add_development_dependency(%q<rspec-rails>, ["~> 2.9"])
      s.add_development_dependency(%q<sqlite3>, [">= 0"])
    else
      s.add_dependency(%q<spree_core>, ["~> 2.1.0.beta"])
      s.add_dependency(%q<capybara>, ["= 1.0.1"])
      s.add_dependency(%q<factory_girl>, ["~> 2.6.4"])
      s.add_dependency(%q<ffaker>, [">= 0"])
      s.add_dependency(%q<rspec-rails>, ["~> 2.9"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
    end
  else
    s.add_dependency(%q<spree_core>, ["~> 2.1.0.beta"])
    s.add_dependency(%q<capybara>, ["= 1.0.1"])
    s.add_dependency(%q<factory_girl>, ["~> 2.6.4"])
    s.add_dependency(%q<ffaker>, [">= 0"])
    s.add_dependency(%q<rspec-rails>, ["~> 2.9"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
  end
end
