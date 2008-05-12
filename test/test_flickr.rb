require 'rubygems'
require 'flickr'
require 'test/unit'
require 'mocha'

class TestFlickr < Test::Unit::TestCase

  # Flickr client tests
  # 
  # instantiation tests
  def test_should_instantiate_new_flickr_client
    Flickr.any_instance.stubs(:login)
    flickr = Flickr.new('some_api_key', 'email@test.com', 'some_password', 'some_shared_secret')
    
    assert_equal 'some_api_key', flickr.api_key
    assert_equal 'some_shared_secret', flickr.instance_variable_get(:@shared_secret)
  end
  
  def test_should_try_to_login_using_old_api_if_email_and_password_passed
    Flickr.any_instance.expects(:login).with('email@test.com', 'some_password') # checks email and password have been set
    flickr = Flickr.new('some_api_key', 'email@test.com', 'some_password', 'some_shared_secret')
  end
  
  def test_should_instantiate_new_flickr_client_on_new_api
    flickr = Flickr.new('api_key' => 'some_api_key', 'email' => 'email@test.com', 'password' => 'some_password', 'shared_secret' => 'some_shared_secret', 'foo' => 'bar')
    
    assert_equal 'some_api_key', flickr.api_key
    assert_equal 'some_shared_secret', flickr.instance_variable_get(:@shared_secret)
    assert_nil flickr.instance_variable_get(:@foo) # should ignore other params
  end
  
  def test_should_not_try_to_login_using_old_api_when_instantiate_new_flickr_client_on_new_api
    Flickr.any_instance.expects(:login).never # doesn't bother trying to login with new api -- it'll fail in any case
    flickr = Flickr.new('api_key' => 'some_api_key', 'email' => 'email@test.com', 'password' => 'some_password', 'shared_secret' => 'some_shared_secret', 'foo' => 'bar')
  end
  
  # signature_from method tests
  def test_should_return_signature_from_given_params
    assert_equal Digest::MD5.hexdigest('shared_secret_codea_param1234xb_param5678yc_param97531t'), 
                   authenticated_flickr_client.send(:signature_from, {:b_param => '5678y', 'c_param' => '97531t', :a_param => '1234x', :d_param => nil})
  end
  
  def test_should_return_nil_for_signature_when_no_shared_secret
    assert_nil flickr_client.send(:signature_from, {:b_param => '5678y', :c_param => '97531t', :a_param => '1234x'})
  end
  
  # request_url method tests
  def test_should_get_signature_for_params_when_building_url
    f = authenticated_flickr_client
    f.expects(:signature_from).with( 'method' => 'flickr.someMethod', 
                                     'api_key' => 'some_api_key', 
                                     'foo' => 'value which/needs&escaping', 
                                     'auth_token' => 'some_auth_token').returns("foo123bar456")
    
    url =  f.send(:request_url, 'someMethod', 'foo' => 'value which/needs&escaping')
  end

  def test_should_build_url_from_params_with_signature
    f = authenticated_flickr_client
    f.stubs(:signature_from).returns("foo123bar456")
    
    url =  f.send(:request_url, 'someMethod', 'foo' => 'value which/needs&escaping')
    [ "#{Flickr::HOST_URL}#{Flickr::API_PATH}", 
      'api_key=some_api_key',
      'method=flickr.someMethod',
      'foo=value+which%2Fneeds%26escaping',
      'auth_token=some_auth_token',
      'api_sig=foo123bar456'].each do |kv_pair|
      assert_match Regexp.new(Regexp.escape(kv_pair)), url
    end
  end

  def test_should_build_url_from_params_when_signature_returns_nil
    flickr = flickr_client
    flickr.stubs(:signature_from)
    assert_equal "#{Flickr::HOST_URL}#{Flickr::API_PATH}/?api_key=some_api_key&method=flickr.someMethod", flickr.send(:request_url, 'someMethod')
    assert_equal "#{Flickr::HOST_URL}#{Flickr::API_PATH}/?api_key=some_api_key&method=flickr.someMethod&foo=bar", flickr.send(:request_url, 'someMethod', 'foo' => 'bar', 'foobar' => nil)
    assert_equal "#{Flickr::HOST_URL}#{Flickr::API_PATH}/?api_key=some_api_key&method=flickr.someMethod&foo=101", flickr.send(:request_url, 'someMethod', 'foo' => 101)
    assert_equal "#{Flickr::HOST_URL}#{Flickr::API_PATH}/?api_key=some_api_key&method=flickr.someMethod&foo=value+which%2Fneeds%26escaping", flickr.send(:request_url, 'someMethod', 'foo' => 'value which/needs&escaping')
  end
  
  # method_missing tests
  def test_should_generate_flickr_method_from_unkown_method_on_flickr_client
    f = flickr_client    
    f.expects(:request).with('some.unknown.methodForFlickr', {})
    f.some_unknown_methodForFlickr
  end
  
  # request method tests
  def test_should_make_successful_request
    f = flickr_client    
    f.expects(:http_get).with('some.url').returns(successful_xml_response)
    f.expects(:request_url).with('some_method', 'foo' => 'bar').returns("some.url")
    
    f.send(:request, 'some_method', 'foo' => 'bar') # request is protected
  end
  
  def test_should_raise_exception_on_unsuccessful_request
    f = flickr_client    
    f.expects(:http_get).returns(unsuccessful_xml_response)
    
    assert_raise(RuntimeError) { f.send(:request, 'some_method', 'foo' => 'bar') }
  end
  
  def test_should_parse_returned_xml_in_successful_request
    f = flickr_client
    f.stubs(:http_get).returns(successful_xml_response)
    expected_response = { "contacts" => { "perpage" => "1000", 
                                          "contact" => [{ "nsid"=>"12037949629@N01", 
                                                          "username"=>"Eric", 
                                                          "ignored"=>"1", 
                                                          "family"=>"0", 
                                                          "friend"=>"1", 
                                                          "realname"=>"Eric Costello", 
                                                          "iconserver"=>"1"}, 
                                                        { "nsid"=>"12037949631@N01", 
                                                          "username"=>"neb", 
                                                          "ignored"=>"0", 
                                                          "family"=>"0", 
                                                          "friend"=>"0", 
                                                          "realname"=>"Ben Cerveny", 
                                                          "iconserver"=>"1"}], 
                                          "total" => "2", 
                                          "pages"=> "1", 
                                          "page"=>"1" }, 
                          "stat"=>"ok" }
    
    assert_equal expected_response, f.send(:request, 'some_method', 'foo' => 'bar')
  end
  
  def test_should_generate_login_url
    f = flickr_client
    f.expects(:signature_from).with('api_key' => 'some_api_key', 'perms' => 'write').returns('validsignature')
    assert_equal 'http://flickr.com/services/auth/?api_key=some_api_key&perms=write&api_sig=validsignature', f.login_url('write')
  end
  
  def test_should_get_token_from_frob
    f = flickr_client
    f.expects(:request).with('auth.getToken',:frob => 'some_frob').returns({'auth' => {'token' => 'some_auth_token', 'user' => {}}})
    
    auth_token = f.get_token_from('some_frob')
    assert_equal 'some_auth_token', auth_token
  end
  
  def test_should_store_auth_token_in_client
    f = flickr_client
    f.expects(:request).returns({'auth' => {'token' => 'some_auth_token','user' => {}}})
    f.get_token_from('some_frob')
    assert_equal 'some_auth_token', f.auth_token
  end
  
  def test_should_store_authenticated_user_details_in_client
    f = flickr_client
    f.expects(:request).returns({ 'auth' => { 'token' => 'some_auth_token', 
                                                            'user' => { 'nsid' => 'foo123', 
                                                                        'username' => 'some_user', 'fullname' => 'Some User'}}})
    f.get_token_from('some_frob')
    assert_kind_of Flickr::User, user = f.user
    assert_equal 'foo123', user.id
    assert_equal 'some_user', user.username
    assert_equal 'Some User', user.name
    assert_equal f, user.client
  end
  
  # photos method tests
  def test_should_get_recent_photos_if_no_params_for_photos
    f = flickr_client
    f.expects(:photos_getRecent).returns({"photos" => {"photo" => []}})
    f.photos
  end
  
  def test_should_instantiate_recent_photos_with_id_and_all_params_returned_by_flickr
    f = flickr_client
    f.expects(:photos_getRecent).returns(dummy_photos_response)
    Flickr::Photo.expects(:new).with("foo123", 
                                     "some_api_key", { "key1" => "value1", 
                                                       "key2" => "value2"})
    Flickr::Photo.expects(:new).with("bar456", 
                                     "some_api_key", { "key3" => "value3"})
    f.photos
  end
  
  # photos_search method tests
  def test_should_search_photos
    f = authenticated_flickr_client
    f.expects(:request).with('photos.search', anything).returns(dummy_photos_response)
    photos = f.photos_search
    assert_kind_of Flickr::Photo, photos.first
  end
  
  # users method tests
  def test_should_find_user_from_email
    f = flickr_client
    f.expects(:request).with('people.findByEmail', anything).returns(dummy_user_response)
    assert_kind_of Flickr::User, user = f.users("email@test.com")
    assert_equal "12037949632@N01", user.id
    assert_equal "Stewart", user.username
  end
  
  def test_should_find_user_from_username_if_fails_to_get_from_email
    f = flickr_client
    f.expects(:request).with('people.findByEmail', anything).raises
    f.expects(:request).with('people.findByUsername', anything).returns(dummy_user_response)
    assert_kind_of Flickr::User, f.users("email@test.com")
  end
  
  def test_should_pass_on_flickr_client_when_finding_user
    f = flickr_client
    f.stubs(:request).returns(dummy_user_response)
    user = f.users("email@test.com")
    assert_equal f, user.client
  end
  
  # groups method tests
  def test_should_search_for_given_group
    f = flickr_client
    f.expects(:request).with("groups.search", {"text" => "foo"}).returns(dummy_groups_response)
    f.groups("foo")
  end
  
  def test_should_search_for_given_group_with_additional_params
    f = flickr_client
    f.expects(:request).with("groups.search", {"text" => "foo", "per_page" => "1"}).returns(dummy_groups_response)
    f.groups("foo", "per_page" => "1")
  end
  
  def test_should_instantiate_groups_from_search_response
    f = flickr_client
    f.stubs(:request).returns(dummy_groups_response)
    assert_kind_of Array, groups = f.groups("foo")
    assert_kind_of Flickr::Group, group = groups.first
    assert_equal "group1", group.id
    assert_equal "Group One", group.name
    assert_equal "0", group.eighteenplus
    assert_equal f, group.client
  end
  
  def test_should_instantiate_groups_from_search_response_with_single_group_returned
    f = flickr_client
    f.stubs(:request).returns(dummy_single_group_response)
    assert_kind_of Array, groups = f.groups("foo")
    assert_equal 1, groups.size
    assert_equal "group1", groups.first.id
  end
  
  # ##### DIRECT MODE
  # 
  # def test_test_echo
  #   assert_equal @f.test_echo['stat'], 'ok'
  # end
  # def test_test_login
  #   assert_equal @f.test_login['stat'], 'ok'
  # end
  # 
  # 
  # ##### BASICS
  # 
  # def test_login
  #   assert_equal @username, @f.user.getInfo.username
  # end
  # 
  # def test_find_by_url
  #   assert_equal @group_id, @f.find_by_url(@group_url).getInfo.id     # find group by URL
  #   assert_equal @user_id, @f.find_by_url(@user_url).getInfo.id       # find user by URL
  # end
  # 
  # def test_licenses
  #   assert_kind_of Array, @f.licenses                   # find all licenses
  # end
  # 
  
  # 
  # Flickr#photos tests
  # 
  
  
  # ##### Flickr::User tests
  # 
  def test_should_instantiate_user
    user = new_user
    assert_equal 'foo123', user.id
    assert_equal 'some_user', user.username
    assert_equal 'bar', user.instance_variable_get(:@foo) # should collect all other params up and store as instance variables
  end
  
  def test_should_instantiate_new_user_with_old_api
    Flickr.any_instance.stubs(:login) # stub logging in
    user = Flickr::User.new('foo123', 
                            'some_user', 
                            'email@test.com', # email irrelevant since Flickr API no longer supports authentication in this way
                            'password', # password irrelevant since Flickr API no longer supports authentication in this way
                            'bar456')
    assert_equal 'foo123', user.id
    assert_equal 'some_user', user.username
    assert_equal 'email@test.com', user.instance_variable_get(:@email)
    assert_equal 'password', user.instance_variable_get(:@password)
    assert_equal 'bar456', user.client.api_key
  end
  
  def test_should_instantiate_new_client_when_instantiating_user_if_no_client_passed_in_params
    f = flickr_client
    Flickr.expects(:new).returns(f)
    user = new_user( 'api_key' => 'an_api_key' )
    assert_equal f, user.client
  end
  
  def test_should_not_instantiate_new_client_when_instantiating_user_if_client_passed_in_params
    f = flickr_client
    Flickr.expects(:new).never
    user = new_user( 'client' => f )
    assert_equal f, user.client
  end
  
  def test_should_not_instantiate_client_if_no_api_key_passed
    Flickr.expects(:new).never
    user = new_user
    assert_nil user.client
  end
  
  def test_should_get_users_public_groups
    f = flickr_client
    f.expects(:request).with("people.getPublicGroups", anything).returns(dummy_groups_response)
    new_user( 'client' => f ).groups
  end
  
  def test_should_instantiate_users_public_groups
    f = flickr_client
    f.stubs(:request).returns(dummy_groups_response)
    user = new_user( 'client' => f )

    groups = user.groups
    assert_equal 2, groups.size
    assert_kind_of Flickr::Group, group = groups.first
    assert_equal "group1", group.id
    assert_equal "Group One", group.name
    assert_equal "0", group.eighteenplus
    assert_equal f, group.client
  end
  
  def test_should_instantiate_users_public_groups_when_only_one_returned
    f = flickr_client
    f.stubs(:request).returns(dummy_single_group_response)
    user = new_user( 'client' => f )
    groups = user.groups
    assert_equal 1, groups.size
  end
  # def test_getInfo
  #   @u.getInfo
  #   assert_equal @username, @u.username
  # end
  # 
  # def test_groups
  #   assert_kind_of Flickr::Group, @u.groups.first                   # public groups
  # end
  # 
  # 
  # def test_contacts
  #   assert_kind_of Flickr::User, @u.contacts.first                   # public contacts
  # end
  # 
  # def test_favorites
  #   assert_kind_of Flickr::Photo, @u.favorites.first                 # public favorites
  # end
  # 
  # def test_photosets
  #   assert_kind_of Flickr::Photoset, @u.photosets.first              # public photosets
  # end
  # 
  # def test_tags
  #   assert_kind_of Array, @u.tags                                    # tags
  # end
  # 
  # def test_contactsPhotos
  #   assert_kind_of Flickr::Photo, @u.contactsPhotos.first            # contacts' favorites
  # end
  
  # User#photos tests
  
  def test_should_get_users_public_photos
    Flickr.expects(:new).at_least_once.returns(photos_response_stubber(:people_getPublicPhotos))
    user = Flickr::User.new(nil, "some_user", nil, nil, "some_api_key")

    photos = user.photos
    assert_equal 2, photos.size
    assert_kind_of Flickr::Photo, photos.first
  end
  
  def test_should_get_users_public_photos_when_only_one_returned
    Flickr.expects(:new).at_least_once.returns(photos_response_stubber(:people_getPublicPhotos, dummy_single_photo_response))
    user = Flickr::User.new(nil, "some_user", nil, nil, "some_api_key")

    photos = user.photos
    assert_equal 1, photos.size
    assert_kind_of Flickr::Photo, photos.first
  end
  
  def test_should_instantiate_photos_with_id_and_all_params_returned_by_query_and_username
    Flickr.stubs(:new).returns(photos_response_stubber(:people_getPublicPhotos))
    user = Flickr::User.new(nil, "some_user", nil, nil, "some_api_key")
    Flickr::Photo.expects(:new).with("foo123", 
                                     "some_api_key", { "key1" => "value1", 
                                                       "key2" => "value2",
                                                       "owner" => user})
    Flickr::Photo.expects(:new).with("bar456", 
                                     "some_api_key", { "key3" => "value3", 
                                                       "owner" => user})
    user.photos
  end
  
  def test_should_instantiate_favorite_photos_with_id_and_all_params_returned_by_query
    user = Flickr::User.new(nil, "some_user", nil, nil, "some_api_key")
    Flickr.stubs(:new).returns(photos_response_stubber(:favorites_getPublicList))
    user = Flickr::User.new(nil, "some_user", nil, nil, "some_api_key")
    Flickr::Photo.expects(:new).with("foo123", 
                                     "some_api_key", { "key1" => "value1", 
                                                       "key2" => "value2"})
    Flickr::Photo.expects(:new).with("bar456", 
                                     "some_api_key", { "key3" => "value3"})
    
    user.favorites
  end
  
  def test_should_instantiate_contacts_photos_with_id_and_all_params_returned_by_query
    user = Flickr::User.new(nil, "some_user", nil, nil, "some_api_key")
    Flickr.stubs(:new).returns(photos_response_stubber(:photos_getContactsPublicPhotos))
    user = Flickr::User.new(nil, "some_user", nil, nil, "some_api_key")
    Flickr::Photo.expects(:new).with("foo123", 
                                     "some_api_key", { "key1" => "value1", 
                                                       "key2" => "value2"})
    Flickr::Photo.expects(:new).with("bar456", 
                                     "some_api_key", { "key3" => "value3"})
    
    user.contactsPhotos
  end
  
  # ##### Flickr::Photo tests

  def test_should_initialize_photo_from_id
    photo = Flickr::Photo.new("foo123")
    assert_equal "foo123", photo.id
  end

  def test_should_save_extra_params_as_instance_variables
    photo = Flickr::Photo.new('foo123', 'some_api_key', { 'key1' => 'value1', 'key2' => 'value2'})
    assert_equal 'value1', photo.instance_variable_get(:@key1)
    assert_equal 'value2', photo.instance_variable_get(:@key2)
  end
  
  def test_should_be_able_to_access_instance_variables_through_hash_like_interface
    photo = Flickr::Photo.new
    photo.instance_variable_set(:@key1, 'value1')
    assert_equal 'value1', photo['key1']
    assert_equal 'value1', photo[:key1]
    assert_nil photo[:key2]
    assert_nil photo['key2']
  end
  
  # 
  # owner tests
  def test_should_return_owner_when_flickr_user
    user = Flickr::User.new
    photo = new_photo("owner" => user)

    assert_equal user, photo.owner
  end
  
  def test_should_get_info_on_owner_if_not_known
    photo = new_photo("owner" => nil)
    # stubbing private methods causes problems so we mock client method, which is what Photo#getInfo users to make API call
    Flickr.any_instance.expects(:photos_getInfo).returns('photo' => { 'owner'=>{'nsid'=>'abc123', 'username'=>'SomeUserName', 'realname'=>"", 'location'=>''}, 
                                                                      'notes' => {}}) 

    owner = photo.owner
    assert_kind_of Flickr::User, owner
    assert_equal 'abc123', owner.id
    assert_equal 'SomeUserName', owner.username
  end
  
  def test_should_instantiate_flickr_user_from_owner_id_if_we_have_it
    photo = Flickr::Photo.new
    photo.instance_variable_set(:@owner, "some_user_id")
    Flickr.any_instance.expects(:photos_getInfo).never
    
    user = photo.owner
    assert_kind_of Flickr::User, user
    assert_equal "some_user_id", user.id
  end
  
  def test_should_cache_owner_when_instantiated
    user = Flickr::User.new
    photo = Flickr::Photo.new
    photo.instance_variable_set(:@owner, "some_user_id")
    Flickr::User.expects(:new).returns(user)
    
    photo.owner
    photo.owner # call twice but mock expects only one call
  end
  
  # 
  # image_source_uri_from_self tests
  def test_should_build_image_source_uri_from_self
    assert_equal "http://farm1.static.flickr.com/2/1418878_1e92283336.jpg",
                   new_photo.send(:image_source_uri_from_self) # no size specified
  end
  
  def test_should_build_image_source_uri_from_self_for_given_size
    assert_equal "http://farm1.static.flickr.com/2/1418878_1e92283336_m.jpg",
                   new_photo.send(:image_source_uri_from_self, "Small") # size specified
  end
  
  def test_should_build_image_source_uri_from_self_for_default_size_when_explicitly_asked_for
    assert_equal "http://farm1.static.flickr.com/2/1418878_1e92283336.jpg",
                   new_photo.send(:image_source_uri_from_self, "Medium") # medium size specified -- the default
  end
  
  def test_should_build_image_source_uri_from_self_for_default_size_when_unknown_size_asked_for
    assert_equal "http://farm1.static.flickr.com/2/1418878_1e92283336.jpg",
                   new_photo.send(:image_source_uri_from_self, "Dummy") # bad size specified
  end
  
  def test_should_return_nil_for_image_source_uri_if_no_attributes
    assert_nil Flickr::Photo.new.send(:image_source_uri_from_self) 
  end
  
  def test_should_return_nil_for_image_source_uri_if_missing_required_attributes
    assert_nil Flickr::Photo.new("1418878", nil, "farm" => "1").send(:image_source_uri_from_self)
  end
  
  def test_should_get_source_uri_by_building_from_self_if_possible
    photo = Flickr::Photo.new
    photo.expects(:image_source_uri_from_self).with('Medium').returns(true) # return any non-false-evaluating value so that sizes method isn't called
    photo.source
  end
  
  def test_should_get_source_uri_by_building_from_self_if_possible_requesting_source_for_given_size
    photo = Flickr::Photo.new
    photo.expects(:image_source_uri_from_self).with('Large').returns(true) # return any non-false-evaluating value so that sizes method isn't called
    photo.source('Large')
  end
  
  def test_should_get_source_uri_by_calling_sizes_method_if_no_luck_building_uri
    photo = Flickr::Photo.new
    photo.stubs(:image_source_uri_from_self) # ...and hence returns nil
    photo.expects(:sizes).with('Medium').returns({})
    photo.source
  end
  
  def test_should_build_uri_for_photo_from_self
    assert_equal "http://www.flickr.com/photos/abc123/1418878", new_photo.send(:uri_for_photo_from_self) 
  end
  
  def test_should_build_uri_for_photo_from_self_when_owner_is_a_string
    assert_equal "http://www.flickr.com/photos/789user321/1418878", new_photo('owner' => "789user321").send(:uri_for_photo_from_self) 
  end
  
  def test_should_build_uri_for_photo_from_self_for_given_size
    assert_equal "http://www.flickr.com/photos/abc123/1418878/sizes/s/", new_photo.send(:uri_for_photo_from_self, "Small")
  end
  
  def test_should_build_uri_for_photo_from_self_with_unknown_size
    assert_equal "http://www.flickr.com/photos/abc123/1418878", new_photo.send(:uri_for_photo_from_self, "Dummy")
  end
  
  def test_should_return_nil_for_uri_for_photo_when_no_user_id
    assert_nil Flickr::Photo.new("1418878", nil).send(:uri_for_photo_from_self)
  end

  def test_should_return_nil_for_uri_for_photo_when_no_photo_id
    assert_nil Flickr::Photo.new.send(:uri_for_photo_from_self)
  end
  
  def test_should_get_uri_for_photo_flickr_page
    photo = new_photo
    assert_equal "http://flickr.com/photos/some_user/1418878", photo.url
  end
  
  def test_should_return_main_page_for_photo_flickr_page_when_medium_size_requested_as_per_previous_version
    photo = new_photo
    assert_equal "http://flickr.com/photos/some_user/1418878", photo.url("Medium")
  end
  
  def test_should_get_flickr_page_uri_by_building_from_self_if_possible_requesting_source_for_given_size
    photo = new_photo
    photo.expects(:uri_for_photo_from_self).with('Large').returns(true) # return any non-false-evaluating value so that sizes method isn't called
    photo.url('Large')
  end
  
  def test_should_get_flickr_page_uri_by_calling_sizes_method_if_no_luck_building_uri
    photo = new_photo
    photo.stubs(:uri_for_photo_from_self) # ...and hence returns nil
    photo.expects(:sizes).with('Large').returns({})
    photo.url('Large')
  end
  
  # Photo#context tests
  def test_should_call_photos_getContext_to_get_context_photos
    Flickr.any_instance.expects(:photos_getContext).returns({'prevphoto' => {}, 'nextphoto' => {}})
    new_photo.context
  end
  
  def test_should_instantiate_context_photos_with_id_and_all_params_returned_by_query
    photo = new_photo
    Flickr.any_instance.expects(:photos_getContext).returns({ 'prevphoto' => {'id' => '123', 'key_1' => 'value_1' }, 
                                                              'nextphoto' => {'id' => '456', 'key_2' => 'value_2'}})
    Flickr::Photo.expects(:new).with("123", "foo123", { "key_1" => "value_1"})
    Flickr::Photo.expects(:new).with("456", "foo123", { "key_2" => "value_2"})
    
    photo.context
  end
  
  def test_should_not_instantiate_context_photos_with_id_of_0
    photo = new_photo
    Flickr.any_instance.expects(:photos_getContext).returns({ 'prevphoto' => {'id' => '123', 'key_1' => 'value_1' }, 
                                                              'nextphoto' => {'id' => '0', 'key_2' => 'value_2'}})
    Flickr::Photo.expects(:new).with("123", anything, anything)
    Flickr::Photo.expects(:new).with("0", anything, anything).never
    
    photo.context
  end
  
  # ##### Flickr::Group tests
  # 
  def test_should_instantiate_group_from_id
     group = Flickr::Group.new("group1")
     assert_equal "group1", group.id
  end
  
  # tests old api for instantiating groups
  def test_should_instantiate_group_from_id_and_api_key
    f = flickr_client
    Flickr.expects(:new).with("some_api_key").returns(f)
    group = Flickr::Group.new("group1", "some_api_key")
    assert_equal f, group.client
  end
  
  # new api for instantiating groups
  def test_should_instantiate_group_from_params_hash
    group = Flickr::Group.new("id" => "group1", "name" => "Group One", "eighteenplus" => "1", "foo" => "bar")
    assert_equal "group1", group.id
    assert_equal "Group One", group.name
    assert_equal "1", group.eighteenplus
    assert_equal "bar", group.instance_variable_get(:@foo)
  end
  
  def test_should_use_flickr_client_passed_in_params_hash_when_instantiating_group
    f = flickr_client
    Flickr.expects(:new).never
    group = Flickr::Group.new("id" => "group1", "name" => "Group One", "client" => f)
    assert_equal f, group.client
  end
  
  def test_should_provide_id_name_eighteenplus_description_members_online_privacy_reader_methods_for_group
    g = Flickr::Group.new
    %w(id name eighteenplus description members online privacy).each do |m|
      g.instance_variable_set("@#{m}", "foo_#{m}")
      assert_equal "foo_#{m}", g.send(m)
    end
  end
  
  # def test_should_initialize_photo_from_id
  #   photo = Flickr::Photo.new("foo123")
  #   assert_equal "foo123", photo.id
  # end
  # 
  # def test_should_save_extra_params_as_instance_variables
  #   photo = Flickr::Photo.new('foo123', 'some_api_key', { 'key1' => 'value1', 'key2' => 'value2'})
  #   assert_equal 'value1', photo.instance_variable_get(:@key1)
  #   assert_equal 'value2', photo.instance_variable_get(:@key2)
  # end
  # 
  # def test_should_be_able_to_access_instance_variables_through_hash_like_interface
  #   photo = Flickr::Photo.new
  #   photo.instance_variable_set(:@key1, 'value1')
  #   assert_equal 'value1', photo['key1']
  #   assert_equal 'value1', photo[:key1]
  #   assert_nil photo[:key2]
  #   assert_nil photo['key2']
  # end
  
  # ##### PHOTOSETS
  #  
  #  #def setup
  #  #  super
  #  #  @photoset = @f.photosets_create('title'=>@title, 'primary_photo_id'=>@photo_id)
  #  #  @photoset_id = @photoset['photoset']['id']
  #  #end
  #  #def teardown
  #  #  @f.photosets_delete('photoset_id'=>@photoset_id)
  #  #end
  # 
  #  def test_photosets_editMeta
  #    assert_equal @f.photosets_editMeta('photoset_id'=>@photoset_id, 'title'=>@title)['stat'], 'ok'
  #  end
  # 
  #  def test_photosets_editPhotos
  #    assert_equal @f.photosets_editPhotos('photoset_id'=>@photoset_id, 'primary_photo_id'=>@photo_id, 'photo_ids'=>@photo_id)['stat'], 'ok'
  #  end
  # 
  #  def test_photosets_getContext
  #    assert_equal @f.photosets_getContext('photoset_id'=>@photoset_id, 'photo_id'=>@photo_id)['stat'], 'ok'
  #  end
  # 
  #  def test_photosets_getContext
  #    assert_equal @f.photosets_getContext('photoset_id'=>@photoset_id, 'photo_id'=>@photo_id)['stat'], 'ok'
  #  end
  # 
  #  def test_photosets_getInfo
  #    assert_equal @f.photosets_getInfo('photoset_id'=>@photoset_id)['stat'], 'ok'
  #  end
  # 
  #  def test_photosets_getList
  #    assert_equal @f.photosets_getList['stat'], 'ok'
  #  end
  # 
  #  def test_photosets_getPhotos
  #    assert_equal @f.photosets_getPhotos('photoset_id'=>@photoset_id)['stat'], 'ok'
  #  end
  # 
  #  def test_photosets_orderSets
  #    assert_equal @f.photosets_orderSets('photoset_ids'=>@photoset_id)['stat'], 'ok'
  #  end
    

  private
  def flickr_client
    Flickr.new("some_api_key")
  end
  
  def authenticated_flickr_client
    f = Flickr.new('api_key' => 'some_api_key', 'shared_secret' => 'shared_secret_code')
    f.instance_variable_set(:@auth_token, 'some_auth_token')
    f
  end
  
  def new_user(options={})
    Flickr::User.new({ 'id' => 'foo123',
                       'username' => 'some_user',
                       'name' => 'Some User', 
                       'foo' => 'bar', 
                       'auth_token' => 'foobar789'}.merge(options))
    
  end
  def new_photo(options={})
    Flickr::Photo.new("1418878", 
                      "foo123",
                      { "farm" => "1",
                        "server" => "2",
                        "secret" => "1e92283336",
                        "owner" => Flickr::User.new("abc123", "some_user", nil, nil, "some_api_key") }.merge(options))
  end
  
  def photos_response_stubber(method_name, response = dummy_photos_response)
    stub(method_name => response)
  end
  
  def dummy_photos_response
    { "photos" => 
      { "photo" => 
        [{ "id" => "foo123", 
           "key1" => "value1", 
           "key2" => "value2" },
         { "id" => "bar456", 
           "key3" => "value3"}] } }
  end
  
  def dummy_single_photo_response
    { "photos" => 
      { "photo" => 
        { "id" => "foo123", 
          "key1" => "value1", 
          "key2" => "value2" } } }
  end
  
  def dummy_user_response
    { "user" => 
      { "nsid" => "12037949632@N01",
        "username" => "Stewart" }
    }
  end
  
  def dummy_groups_response
    { "groups" => 
      { "group" => 
        [{ "nsid" => "group1", 
           "name" => "Group One", 
           "eighteenplus" => "0" },
         { "nsid" => "group2", 
           "name" => "Group Two",
           "eighteenplus" => "1"}] } }
  end
  
  def dummy_single_group_response
    { "groups" => 
      { "group" => 
        { "nsid" => "group1", 
           "name" => "Group One", 
           "eighteenplus" => "0" } } }
  end
  
  def successful_xml_response
    <<-EOF
      <?xml version="1.0" encoding="utf-8" ?>
      <rsp stat="ok">
      	<contacts page="1" pages="1" perpage="1000" total="2">
        	<contact nsid="12037949629@N01" username="Eric" iconserver="1"
        		realname="Eric Costello"
        		friend="1" family="0" ignored="1" /> 
        	<contact nsid="12037949631@N01" username="neb" iconserver="1"
        		realname="Ben Cerveny"
        		friend="0" family="0" ignored="0" /> 
         </contacts>
      </rsp>
    EOF
  end
  
  def unsuccessful_xml_response
    <<-EOF
      <?xml version="1.0" encoding="utf-8" ?>
      <rsp stat="fail">
      	<err code="[error-code]" msg="[error-message]" />
      </rsp>
    EOF
  end

end