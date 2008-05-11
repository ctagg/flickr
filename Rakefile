require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rubygems'

task :default => [ :gem, :rdoc ]

Rake::TestTask.new("test") { |t|
  t.test_files = FileList['test*.rb']
}

Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.rdoc_files.include('flickr.rb')
}

spec = Gem::Specification.new do |s|
  s.add_dependency('xml-simple', '>= 1.0.7')
  s.name = 'flickr'
  s.version = "1.0.2"
  s.platform = Gem::Platform::RUBY
  s.summary = "An insanely easy interface to the Flickr photo-sharing service. By Scott Raymond. Maintainer: Patrick Plattes"
  s.requirements << 'Flickr developers API key'
  s.files = Dir.glob("*").delete_if { |item| item.include?("svn") }
  s.require_path = '.'
  s.autorequire = 'flickr'
  s.author = "Scott Raymond, Patrick Plattes"
  s.email = "patrick@erdbeere.net"
  s.rubyforge_project = "flickr"
  s.homepage = "http://flickr.rubyforge.org/"
end
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
