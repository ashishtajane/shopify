# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "spree_fancy"
  s.version = "1.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Alexey Topolyanskiy"]
  s.date = "2013-07-23"
  s.description = "Fancy theme to apply to out of the box Spree so it looks a bit nicer. Use it as a starting point."
  s.email = "devilcoders@gmail.com"
  s.homepage = "http://www.spreecommerce.com"
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.requirements = ["none"]
  s.rubygems_version = "1.8.23"
  s.summary = "Fancy Spree Theme"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<spree_core>, ["~> 2.0.0"])
      s.add_runtime_dependency(%q<compass-rails>, [">= 0"])
      s.add_runtime_dependency(%q<jquery-ui-rails>, [">= 0"])
      s.add_development_dependency(%q<capybara>, ["= 1.0.1"])
      s.add_development_dependency(%q<factory_girl>, ["~> 2.6.4"])
      s.add_development_dependency(%q<ffaker>, [">= 0"])
      s.add_development_dependency(%q<rspec-rails>, ["~> 2.9"])
      s.add_development_dependency(%q<spree_auth_devise>, [">= 0"])
      s.add_development_dependency(%q<sqlite3>, [">= 0"])
    else
      s.add_dependency(%q<spree_core>, ["~> 2.0.0"])
      s.add_dependency(%q<compass-rails>, [">= 0"])
      s.add_dependency(%q<jquery-ui-rails>, [">= 0"])
      s.add_dependency(%q<capybara>, ["= 1.0.1"])
      s.add_dependency(%q<factory_girl>, ["~> 2.6.4"])
      s.add_dependency(%q<ffaker>, [">= 0"])
      s.add_dependency(%q<rspec-rails>, ["~> 2.9"])
      s.add_dependency(%q<spree_auth_devise>, [">= 0"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
    end
  else
    s.add_dependency(%q<spree_core>, ["~> 2.0.0"])
    s.add_dependency(%q<compass-rails>, [">= 0"])
    s.add_dependency(%q<jquery-ui-rails>, [">= 0"])
    s.add_dependency(%q<capybara>, ["= 1.0.1"])
    s.add_dependency(%q<factory_girl>, ["~> 2.6.4"])
    s.add_dependency(%q<ffaker>, [">= 0"])
    s.add_dependency(%q<rspec-rails>, ["~> 2.9"])
    s.add_dependency(%q<spree_auth_devise>, [">= 0"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
  end
end
