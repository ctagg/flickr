Gem::Specification.new do |s|
  s.name = %q{flickr}
  s.version = "1.0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Scott Raymond, Patrick Plattes"]
  s.autorequire = %q{flickr}
  s.date = %q{2008-09-10}
  s.email = %q{patrick@erdbeere.net}
  s.files = ["History.txt", "LICENSE", "README.txt", "TODO", "lib/flickr.rb", "test/test_flickr.rb"]
  s.homepage = %q{http://flickr.rubyforge.org/}
  s.require_paths = ["lib"]
  s.requirements = ["Flickr developers API key"]
  s.rubyforge_project = %q{flickr}
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{An insanely easy interface to the Flickr photo-sharing service. By Scott Raymond. Maintainer: Patrick Plattes}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
      s.add_runtime_dependency(%q<xml-simple>, [">= 1.0.7"])
    else
      s.add_dependency(%q<xml-simple>, [">= 1.0.7"])
    end
  else
    s.add_dependency(%q<xml-simple>, [">= 1.0.7"])
  end
end
