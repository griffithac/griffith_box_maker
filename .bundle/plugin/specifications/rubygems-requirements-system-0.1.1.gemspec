# -*- encoding: utf-8 -*-
# stub: rubygems-requirements-system 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "rubygems-requirements-system".freeze
  s.version = "0.1.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sutou Kouhei".freeze]
  s.date = "1980-01-02"
  s.description = "Users need to install system packages to install an extension library\nthat depends on system packages. It bothers users because users need to\ninstall system packages and an extension library separately.\n\nrubygems-requirements-system helps to install system packages on \"gem install\".\nUsers can install both system packages and an extension library by one action,\n\"gem install\".".freeze
  s.email = ["kou@clear-code.com".freeze]
  s.homepage = "https://github.com/ruby-gnome/rubygems-requirements-system".freeze
  s.licenses = ["LGPL-3.0-or-later".freeze]
  s.rubygems_version = "3.6.7".freeze
  s.summary = "Users can install system packages automatically on \"gem install\"".freeze

  s.installed_by_version = "3.6.2".freeze
end
