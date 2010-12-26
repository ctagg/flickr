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
    assert_equal "#{Flickr::HOST_URL}#{Flickr::API_PATH}/?method=flickr.someMethod&api_key=some_api_key", flickr.send(:request_url, 'someMethod')
    assert_equal "#{Flickr::HOST_URL}#{Flickr::API_PATH}/?method=flickr.someMethod&api_key=some_api_key&foo=bar", flickr.send(:request_url, 'someMethod', 'foo' => 'bar', 'foobar' => nil)
    assert_equal "#{Flickr::HOST_URL}#{Flickr::API_PATH}/?method=flickr.someMethod&api_key=some_api_key&foo=101", flickr.send(:request_url, 'someMethod', 'foo' => 101)
    assert_equal "#{Flickr::HOST_URL}#{Flickr::API_PATH}/?method=flickr.someMethod&api_key=some_api_key&foo=value+which%2Fneeds%26escaping", flickr.send(:request_url, 'someMethod', 'foo' => 'value which/needs&escaping')
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

  # photos_request tests
  def test_should_pass_photos_request_params_to_request
    f = flickr_client
    f.expects(:request).with('flickr.method', :one => 1, :two => "2").returns(dummy_photos_response)
    f.photos_request(        'flickr.method', :one => 1, :two => "2")
  end

  def test_should_instantiate_recent_photos_with_id_and_all_params_returned_by_flickr
    f = flickr_client
    f.expects(:request).returns(dummy_photos_response)
    Flickr::Photo.expects(:new).with("foo123",
                                     "some_api_key", { "key1" => "value1",
                                                       "key2" => "value2"})
    Flickr::Photo.expects(:new).with("bar456",
                                     "some_api_key", { "key3" => "value3"})
    photos = f.photos_request('some_method')
  end

  def test_should_parse_photos_response_into_flickr_photo_collection
    f = flickr_client
    f.expects(:request).returns(dummy_photos_response)
    assert_kind_of Flickr::PhotoCollection, f.photos_request('some_method')
  end

  def test_should_store_pagination_info_in_photo_collection
    f = flickr_client
    f.expects(:request).returns(dummy_photos_response)
    photos = f.photos_request('some_method')

    assert_equal "3", photos.page
    assert_equal "5", photos.pages
    assert_equal "10", photos.perpage
    assert_equal "42", photos.total
  end

  def test_should_return_collection_of_photos
    f = flickr_client
    f.expects(:request).returns(dummy_photos_response)
    photos = f.photos_request('some_method')
    assert_equal 2, photos.size
    assert_kind_of Flickr::Photo, photos.first
    assert_equal "foo123", photos.first.id
  end

  def test_should_work_with_single_result
    f = flickr_client
    f.expects(:request).returns(dummy_single_photo_response)
    photos = f.photos_request('some_method')
    assert_equal 1, photos.size
    assert_kind_of Flickr::Photo, photos.first
    assert_equal "foo123", photos.first.id
  end

  def test_should_work_with_empty_result
    f = flickr_client
    f.expects(:request).returns(dummy_zero_photo_response)
    photos = f.photos_request('some_method')
    assert_equal [], photos
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
    f.expects(:photos_search)
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

  def test_should_build_url_for_users_profile_page_using_user_id
    Flickr.any_instance.expects(:http_get).never
    assert_equal "http://www.flickr.com/people/foo123/", new_user.url
  end

  def test_should_build_url_for_users_photos_page_using_user_id
    Flickr.any_instance.expects(:http_get).never
    assert_equal "http://www.flickr.com/photos/foo123/", new_user.photos_url
  end

  def test_should_get_pretty_url_for_users_profile_page
    f = flickr_client
    f.expects(:urls_getUserProfile).returns({"user" => {"nsid" => "bar456", "url" => "http://www.flickr.com/people/killer_bob/"}})

    assert_equal "http://www.flickr.com/people/killer_bob/", new_user( 'client' => f ).pretty_url
  end

  def test_should_cache_pretty_url_for_users_profile_page
    f = flickr_client
    user = new_user( 'client' => f )
    f.expects(:urls_getUserProfile).returns({"user" => {"nsid" => "bar456", "url" => "http://www.flickr.com/people/killer_bob/"}}) # expects only one call

    user.pretty_url
    user.pretty_url
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

	def test_should_get_users_tags
		f = flickr_client
		user = new_user( 'client' => f )
		f.expects(:tags_getListUser).with('user_id'=>user.id).returns({"who"=>{"tags"=>{"tag"=>["offf08", "ruby", "rubyonrails", "timoteo", "wbs", "webreakstuff"]}, "id"=>"9259187@N05"}, "stat"=>"ok"})
		tags = user.tags
		assert_kind_of Array, tags
		assert_equal tags, ["offf08", "ruby", "rubyonrails", "timoteo", "wbs", "webreakstuff"]
	end

	def test_should_get_users_popular_tags
		f = flickr_client
		user = new_user( 'client' => f )
		f.expects(:tags_getListUserPopular).with('user_id' => user.id).with(anything).returns({"who"=>{"tags"=>{"tag"=>[{"content"=>"design", "count"=>"94"}, {"content"=>"offf08", "count"=>"94"}, {"content"=>"ruby", "count"=>"3"}, {"content"=>"rubyonrails", "count"=>"3"}, {"content"=>"wbs", "count"=>"3"}, {"content"=>"webreakstuff", "count"=>"97"}]}, "id"=>"9259187@N05"}, "stat"=>"ok"})
		pop_tags = user.popular_tags
		assert_kind_of Array, pop_tags
		assert_equal pop_tags, [{"tag"=>"design", "count"=>"94"}, {"tag"=>"offf08", "count"=>"94"}, {"tag"=>"ruby", "count"=>"3"}, {"tag"=>"rubyonrails", "count"=>"3"}, {"tag"=>"wbs", "count"=>"3"}, {"tag"=>"webreakstuff", "count"=>"97"}]
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
  # def test_contactsPhotos
  #   assert_kind_of Flickr::Photo, @u.contactsPhotos.first            # contacts' favorites
  # end

  # User#photos tests

  def test_should_get_users_public_photos
    client = mock
    client.expects(:photos_request).with('people.getPublicPhotos', {'user_id' => 'some_id'}).returns([new_photo, new_photo])
    Flickr.expects(:new).at_least_once.returns(client)

    user = Flickr::User.new("some_id", "some_user", nil, nil, "some_api_key")

    photos = user.photos
    assert_equal 2, photos.size
    assert_kind_of Flickr::Photo, photos.first
  end

  def test_should_instantiate_favorite_photos_with_id_and_all_params_returned_by_query
    client = mock
    client.expects(:photos_request).with('favorites.getPublicList', {'user_id' => 'some_id'})
    Flickr.expects(:new).at_least_once.returns(client)
    user = Flickr::User.new("some_id", "some_user", nil, nil, "some_api_key")
    user.favorites
  end

  def test_should_instantiate_contacts_photos_with_id_and_all_params_returned_by_query
    client = mock
    client.expects(:photos_request).with('photos.getContactsPublicPhotos', {'user_id' => 'some_id'})
    Flickr.expects(:new).at_least_once.returns(client)
    user = Flickr::User.new('some_id', "some_user", nil, nil, "some_api_key")
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

  def test_should_get_and_store_other_info_for_photo
    Flickr.any_instance.stubs(:http_get).returns(photo_info_xml_response)
    photo = Flickr::Photo.new('foo123', 'some_api_key')

    assert_equal "1964 120 amazon estate", photo.title # calling #title method triggers getting of info
    assert_equal "1964 120 amazon estate", photo.instance_variable_get(:@title)
    assert_equal "3142", photo.instance_variable_get(:@server)
    assert_equal "ae75bd3111", photo.instance_variable_get(:@secret)
    assert_equal "4", photo.instance_variable_get(:@farm)
    assert_equal "1204145093", photo.instance_variable_get(:@dateuploaded)
    assert_equal "photo", photo.instance_variable_get(:@media)
    assert_equal "0", photo.instance_variable_get(:@isfavorite)
    assert_equal "0", photo.instance_variable_get(:@license)
    assert_equal "0", photo.instance_variable_get(:@rotation)
    assert_equal "1964 Volvo 120 amazon estate spotted in derbyshire.", photo.instance_variable_get(:@description)
    assert_equal( { "w" => "50",
                    "x" => "10",
                    "y" => "10",
                    "authorname" => "Bees",
                    "author" => "12037949754@N01",
                    "id" => "313",
                    "content" => "foo",
                    "h" => "50" }, photo.instance_variable_get(:@notes))
    assert_equal "http://www.flickr.com/photos/rootes_arrow/2296968304/", photo.instance_variable_get(:@url)
    assert_equal [ { "id" => "9377979-2296968304-2228", "author" => "9383319@N05", "raw" => "volvo", "machine_tag" => "0", "content" => "volvo" },
                   { "id" => "9377979-2296968304-2229", "author" => "9383319@N06", "raw" => "amazon", "machine_tag" => "0", "content" => "amazon"
                   } ], photo.instance_variable_get(:@tags)
    assert_equal "1", photo.instance_variable_get(:@comments)
    assert_kind_of Flickr::User, owner = photo.instance_variable_get(:@owner)
    assert_equal "Rootes_arrow_1725", owner.username
  end

  def test_should_get_and_other_info_for_photo_when_some_attributes_missing
    Flickr.any_instance.stubs(:http_get).returns(sparse_photo_info_xml_response)
    photo = Flickr::Photo.new('foo123', 'some_api_key')

    assert_equal "1964 120 amazon estate", photo.title # calling #title method triggers getting of info
    assert_equal "1964 120 amazon estate", photo.instance_variable_get(:@title)
    assert_equal( {}, photo.instance_variable_get(:@description))
    assert_nil photo.instance_variable_get(:@notes)
    assert_nil photo.instance_variable_get(:@tags)
    assert_equal "1", photo.instance_variable_get(:@comments)
  end

  def test_should_not_get_info_more_than_once
    Flickr.any_instance.expects(:http_get).returns(photo_info_xml_response) # expects only one call
    photo = Flickr::Photo.new('foo123', 'some_api_key')

    photo.description # calling #description method triggers getting of info
    photo.instance_variable_set(:@description, nil) # set description to nil
    photo.description # call #description method again
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
                                                                      'notes' => {}, 'tags' => {}, 'urls' => {'url' => {'content' => 'http://prettyurl'}}})

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

  def test_image_source_uri_from_self_should_normalize_size
    photo = new_photo
    assert_equal photo.send(:image_source_uri_from_self, 'Large'),
                 photo.send(:image_source_uri_from_self, :large)
  end

  def test_uri_for_photo_from_self_should_normalize_size
    photo = new_photo
    assert_equal photo.send(:uri_for_photo_from_self, 'Large'),
                 photo.send(:uri_for_photo_from_self, :large)
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
    assert_equal "http://www.flickr.com/photos/abc123/1418878", photo.url
  end

  def test_should_return_main_page_for_photo_flickr_page_when_medium_size_requested_as_per_previous_version
    assert_equal "http://www.flickr.com/photos/abc123/1418878", new_photo.url('Medium')
  end

  def test_should_call_size_url_if_url_given_a_size
    photo = new_photo
    photo.expects(:size_url).with('Large')
    photo.url('Large')
  end

  def test_should_get_flickr_page_uri_by_building_from_self_if_possible_requesting_source_for_given_size
    photo = new_photo
    photo.expects(:uri_for_photo_from_self).with('Large').returns(true) # return any non-false-evaluating value so that sizes method isn't called
    photo.size_url('Large')
  end

  def test_should_get_flickr_page_uri_by_calling_sizes_method_if_no_luck_building_uri
    photo = new_photo
    photo.stubs(:uri_for_photo_from_self) # ...and hence returns nil
    photo.expects(:sizes).with('Large').returns({})
    photo.size_url('Large')
  end

  def test_should_allow_size_to_be_lowercase_or_symbol
    photo = new_photo
    assert_equal photo.normalize_size('Small'), 'Small'
    assert_equal photo.normalize_size('small'), 'Small'
    assert_equal photo.normalize_size(:small),  'Small'
    assert_equal photo.normalize_size(:Small),  'Small'
    assert_equal photo.normalize_size('smAlL'), 'Small'

    assert_equal photo.normalize_size(""), ""
    assert_nil photo.normalize_size(nil)
  end

  def test_size_url_should_normalize_size
    photo = new_photo
    assert_equal photo.size_url('Large'), photo.size_url(:large)
  end

  def test_url_should_normalize_size
    photo = new_photo
    assert_equal photo.url('Medium'), photo.url(:medium)
    assert_equal photo.url('Small'),  photo.url('small')
  end

  def test_source_should_normalize_size
    photo = new_photo
    assert_equal photo.source('Large'), photo.source(:large)
  end

  def test_sizes_should_normalize_size
    sizes = {'sizes' => {'size' => [{'label' => 'Small'}, {'label' => 'Large'}]}}
    photo = new_photo
    photo.client.expects(:photos_getSizes).at_least_once.returns(sizes)
    assert_equal photo.sizes('Large'), photo.sizes(:large)
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

  ## PHOTOSETS

  def test_should_initialize_photoset_from_id
    photoset = Flickr::Photoset.new("foo123")
    assert_equal "foo123", photoset.id
  end

  def test_should_initialize_photoset_from_id_and_api_key
    photoset = Flickr::Photoset.new("foo123", "some_api_key")
    assert_equal "some_api_key", photoset.instance_variable_get(:@api_key)
  end

  def test_should_get_photos_for_specified_photoset
    Flickr.any_instance.expects(:request).with('photosets.getPhotos', {'photoset_id' => 'some_id'}).returns(dummy_photoset_photos_response)
    photoset = Flickr::Photoset.new("some_id", "some_api_key")

    assert_kind_of Flickr::PhotoCollection, photos = photoset.getPhotos
    assert_equal 2, photos.size
    assert_kind_of Flickr::Photo, photos.first
  end


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

  def test_related_tags
    f = flickr_client
    tags_response = {
      "tags" => {
        "tag"    => [ "zoo", "animal" ],
        "source" => "monkey",
      },
      "stat" => "ok",
    }
    f.expects(:tags_getRelated).with('tag' => 'monkey').returns(tags_response)
    assert_equal f.related_tags('monkey'), %w(zoo animal)
  end

  # ##### Flickr::PhotoCollection tests
  #
  def test_should_subclass_array_as_photo_collection
     assert_equal Array, Flickr::PhotoCollection.superclass
  end

  def test_should_make_page_a_reader_method
    assert_equal "3", dummy_photo_collection.page
  end

  def test_should_make_pages_a_reader_method
    assert_equal "5", dummy_photo_collection.pages
  end

  def test_should_make_perpage_a_reader_method
    assert_equal "10", dummy_photo_collection.perpage
  end

  def test_should_make_total_a_reader_method
    assert_equal "42", dummy_photo_collection.total
  end

  def test_should_instantiate_photo_collection_from_photos_hash
    pc = Flickr::PhotoCollection.new(dummy_photos_response)
    assert_kind_of Flickr::PhotoCollection, pc
    assert_equal 2, pc.size
    assert_kind_of Flickr::Photo, pc.first
    assert_equal "foo123", pc.first["id"]
  end

  def test_should_instantiate_photo_collection_using_given_api_key
    photo = Flickr::PhotoCollection.new(dummy_photos_response, "some_api_key").first
    assert_equal "some_api_key", photo.instance_variable_get(:@api_key)
  end

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

  def dummy_photo_collection
    Flickr::PhotoCollection.new(dummy_photos_response)
  end

  def dummy_photos_response
    { "photos" =>
      { "photo" =>
        [{ "id" => "foo123",
           "key1" => "value1",
           "key2" => "value2" },
         { "id" => "bar456",
           "key3" => "value3"}],
        "page"=>"3",
        "pages"=>"5",
        "perpage"=>"10",
        "total"=>"42" } }
  end

  def dummy_single_photo_response
    { "photos" =>
      { "photo" =>
        { "id" => "foo123",
          "key1" => "value1",
          "key2" => "value2" } } }
  end

  def dummy_zero_photo_response
    { "photos" => { "total" => 0 } }
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

  def dummy_photoset_photos_response
    { "photoset" =>
      { "photo" =>
        [{ "id" => "foo123",
           "key1" => "value1",
           "key2" => "value2" },
         { "id" => "bar456",
           "key3" => "value3"}],
        "page"=>"3",
        "pages"=>"5",
        "perpage"=>"10",
        "total"=>"42" } }
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

  def photo_info_xml_response
    <<-EOF
    <?xml version="1.0" encoding="utf-8" ?>
    <rsp stat="ok">
      <photo id="22527834" secret="ae75bd3111" server="3142" farm="4" dateuploaded="1204145093" isfavorite="0" license="0" rotation="0" media="photo">
      	<owner nsid="9383319@N05" username="Rootes_arrow_1725" realname="John" location="U.K" />
      	<title>1964 120 amazon estate</title>
      	<description>1964 Volvo 120 amazon estate spotted in derbyshire.</description>
      	<visibility ispublic="1" isfriend="0" isfamily="0" />
      	<dates posted="1204145093" taken="2007-06-10 13:18:27" takengranularity="0" lastupdate="1204166772" />
      	<editability cancomment="0" canaddmeta="0" />
      	<usage candownload="0" canblog="0" canprint="0" />
      	<comments>1</comments>
      	<notes>
        	<note id="313" author="12037949754@N01" authorname="Bees" x="10" y="10" w="50" h="50">foo</note>
        </notes>
      	<tags>
      		<tag id="9377979-2296968304-2228" author="9383319@N05" raw="volvo" machine_tag="0">volvo</tag>
      		<tag id="9377979-2296968304-2229" author="9383319@N06" raw="amazon" machine_tag="0">amazon</tag>
      	</tags>
      	<urls>
      		<url type="photopage">http://www.flickr.com/photos/rootes_arrow/2296968304/</url>
      	</urls>
      </photo>
    </rsp>
    EOF
  end

  def sparse_photo_info_xml_response
    <<-EOF
    <?xml version="1.0" encoding="utf-8" ?>
    <rsp stat="ok">
      <photo id="22527834" secret="ae75bd3111" server="3142" farm="4" dateuploaded="1204145093" isfavorite="0" license="0" rotation="0" media="photo">
      	<owner nsid="9383319@N05" username="Rootes_arrow_1725" realname="John" location="U.K" />
      	<title>1964 120 amazon estate</title>
      	<description/>
      	<visibility ispublic="1" isfriend="0" isfamily="0" />
      	<dates posted="1204145093" taken="2007-06-10 13:18:27" takengranularity="0" lastupdate="1204166772" />
      	<editability cancomment="0" canaddmeta="0" />
      	<usage candownload="0" canblog="0" canprint="0" />
      	<comments>1</comments>
      	<notes/>
      	<tags/>
      	<urls>
      		<url type="photopage">http://www.flickr.com/photos/rootes_arrow/2296968304/</url>
      	</urls>
      </photo>
    </rsp>
    EOF
  end

end