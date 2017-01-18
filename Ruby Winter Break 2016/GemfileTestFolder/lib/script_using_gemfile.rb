def load_gem(name, version=nil)
  # needed if your ruby version is less than 1.9
  require 'rubygems'

  begin
    gem name, version
  rescue LoadError
    version = "--version '#{version}'" unless version.nil?
    system("gem install #{name} #{version}")
    Gem.clear_paths
    retry
  end

  require name
end

load_gem 'selenium-webdriver'
load_gem 'browsermob-proxy'
load_gem 'google_drive'
load_gem 'chromedriver-helper', '~> 1.0'
