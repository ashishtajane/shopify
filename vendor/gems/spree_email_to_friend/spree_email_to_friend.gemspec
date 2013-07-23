# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "spree_email_to_friend"
  s.version = "1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jorge Cal\u{e1}s Lozano, Roman Smirnov, Trung L\u{ea}"]
  s.date = "2013-07-23"
  s.description = "Spree extension to send product recommendations to friends"
  s.files = [".gitignore", ".rspec", "Gemfile", "LICENSE", "README.md", "Rakefile", "Versionfile", "app/controllers/spree/admin/captcha_settings_controller.rb", "app/controllers/spree/email_sender_controller.rb", "app/mailers/spree/to_friend_mailer.rb", "app/models/spree/captcha_configuration.rb", "app/models/spree/mail_to_friend.rb", "app/overrides/add_captcha_settings_to_admin_configurations_menu.rb", "app/overrides/add_email_to_friend_link_to_products.rb", "app/views/spree/admin/captcha_settings/edit.html.erb", "app/views/spree/email_sender/send_mail.html.erb", "app/views/spree/products/_mail_to_friend.text.erb", "app/views/spree/to_friend_mailer/mail_to_friend.text.erb", "config/locales/de.yml", "config/locales/en.yml", "config/locales/es.yml", "config/locales/fr-FR.yml", "config/locales/pt-BR.yml", "config/locales/sl.yml", "config/routes.rb", "lib/spree_email_to_friend.rb", "lib/spree_email_to_friend/engine.rb", "script/rails", "spec/controllers/email_sender_controller_spec.rb", "spec/spec_helper.rb", "spree_email_to_friend.gemspec"]
  s.homepage = "https://github.com/spree/spree_email_to_friend"
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.requirements = ["none"]
  s.rubygems_version = "1.8.23"
  s.summary = "Spree extension to send product recommendations to friends"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<spree_core>, ["~> 2.0.0"])
      s.add_runtime_dependency(%q<recaptcha>, [">= 0.3.1"])
      s.add_development_dependency(%q<rspec-rails>, [">= 0"])
      s.add_development_dependency(%q<sqlite3>, [">= 0"])
      s.add_development_dependency(%q<factory_girl>, ["~> 4.2"])
    else
      s.add_dependency(%q<spree_core>, ["~> 2.0.0"])
      s.add_dependency(%q<recaptcha>, [">= 0.3.1"])
      s.add_dependency(%q<rspec-rails>, [">= 0"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
      s.add_dependency(%q<factory_girl>, ["~> 4.2"])
    end
  else
    s.add_dependency(%q<spree_core>, ["~> 2.0.0"])
    s.add_dependency(%q<recaptcha>, [">= 0.3.1"])
    s.add_dependency(%q<rspec-rails>, [">= 0"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
    s.add_dependency(%q<factory_girl>, ["~> 4.2"])
  end
end
