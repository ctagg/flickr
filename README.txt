= flickr

http://github.com/ctagg/flickr

== DESCRIPTION:

An insanely easy interface to the Flickr photo-sharing service. By Scott Raymond. (& updated May 08 by Chris Taggart, http://pushrod.wordpress.com)

== FEATURES/PROBLEMS:

The flickr gem (famously featured in a RubyonRails screencast) had broken with Flickr's new authentication scheme and updated API.
This has now been largely corrected, though not all current API calls are supported yet.

== SYNOPSIS:

require 'flickr'
flickr = Flickr.new('some_flickr_api_key')    # create a flickr client (get an API key from http://www.flickr.com/services/api/)
user = flickr.users('sco@scottraymond.net')   # lookup a user
user.name                                     # get the user's name
user.location                                 # and location
user.photos                                   # grab their collection of Photo objects...
user.groups                                   # ...the groups they're in...
user.contacts                                 # ...their contacts...
user.favorites                                # ...favorite photos...
user.photosets                                # ...their photo sets...
user.tags                                     # ...and their tags
recentphotos = flickr.photos                  # get the 100 most recent public photos
photo = recentphotos.first                    # or very most recent one
photo.url                                     # see its URL,
photo.title                                   # title,
photo.description                             # and description,
photo.owner                                   # and its owner.
File.open(photo.filename, 'w') do |file|
  file.puts p.file                            # save the photo to a local file
end
flickr.photos.each do |p|                     # get the last 100 public photos...
  File.open(p.filename, 'w') do |f|
    f.puts p.file('Square')                   # ...and save a local copy of their square thumbnail
  end
end

== REQUIREMENTS:

* Xmlsimple gem

== INSTALL:

* sudo gem install flickr

== LICENSE:

(The MIT License)

Copyright (c) 2008 Scott Raymond, Patrick Plattes, Chris Taggart

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.