ENV["RACK_ENV"] = "test"

require 'simplecov'
SimpleCov.start
require "minitest/autorun"
require "rack/test"

require_relative "../contacts"
require_relative "../contacts_database"

class DatabaseConnection
  def initialize
    @db = PG.connect(dbname: "contacts_test")
    schema = File.read("test_schema.sql")
    @db.exec(schema)
  end
  
  def cleanup
    @db.exec("DROP TABLE contacts;")
    @db.finish
  end
end

class TestApp < Minitest::Test
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def session
    last_request.env["rack.session"]
  end
  
  def setup
    @storage = DatabaseConnection.new
  end
  
  def teardown
    @storage.cleanup
  end
  
  def sample_contact
    {
      category: "friends",
      name: "Hello",
      address: "World",
      phone: "7853333456",
      email: "hello@world.com"
    }
  end
  
  def test_index_redirect
    get "/"
    
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    
    assert_includes last_response.body, %q(<button type="submit")
    assert_includes last_response.body, "Search by Category"
  end
  
  def test_index
    get "/contacts"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Search by Name"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_index_with_search_no_matches_found
    get "/contacts?query=billy"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Search by Name"
    assert_includes last_response.body, "Sorry, no matches were found."
  end
  
  def test_index_with_search_empty_string
    get "/contacts?query= "
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Search by Name"
    assert_includes last_response.body, "Sorry, no matches were found."
  end
  
  def test_index_with_search_match_found
    get "/contacts?query=jill"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Search by Name"
    assert_includes last_response.body, "Jill Thomas"
    assert_includes last_response.body, "Edit"
  end
  
  def test_category_search_friends
    get "/contacts?query=friends"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "..for 'Friends'"
    assert_includes last_response.body, "Gene C"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_category_search_family
    get "/contacts?query=family"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "..for 'Family'"
    assert_includes last_response.body, "Cara Ellerson"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_category_search_business
    get "/contacts?query=business"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "..for 'Business'"
    assert_includes last_response.body, "Linus Moore"
    assert_includes last_response.body, %q(<button type="submit")
    assert_includes last_response.body, "Edit"
  end
  
  def test_view_create_new_contact_page
    get "/contacts/add_contact"
    
    assert_equal 200, last_response.status
    
    assert_includes last_response.body, %q(<input type="radio")
    assert_includes last_response.body, "Contact Information"
    assert_includes last_response.body, "Submit"
  end
  
  def test_create_new_contact
    post "contacts/add_contact", sample_contact
    
    assert_equal 302, last_response.status
    assert_equal "Hello has been added to your directory.", session[:message]
    
    get last_response["Location"]
    
    assert_includes last_response.body, "Contacts"
    assert_includes last_response.body, "Search by Category"
  end
  
  def test_create_new_contact_no_phone
    post "contacts/add_contact", sample_contact.merge(phone: "")
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid phone number, please provide 10 digits."
    assert_includes last_response.body, "Hello"
    assert_includes last_response.body, "Contact Information:"
  end
  
  def test_create_new_contact_duplicate_name
    post "contacts/add_contact", sample_contact
    post "contacts/add_contact", sample_contact
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Contact 'Hello' already exists."
    assert_includes last_response.body, "Hello"
    assert_includes last_response.body, "Contact Information:"
  end
  
  def test_create_new_contact_invalid_phone
    post "contacts/add_contact", sample_contact.merge(phone: "1234567")
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid phone number, please provide 10 digits."
    assert_includes last_response.body, "Hello"
    assert_includes last_response.body, "Contact Information:"
  end
  
  def test_create_new_contact_no_name_no_phone
    post "contacts/add_contact", sample_contact.merge(name: "", phone: "")
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, "You must include a name and phone number."
    assert_includes last_response.body, "World"
    assert_includes last_response.body, "Contact Information:"
  end
  
  def test_create_new_contact_invalid_email_address
    post "contacts/add_contact", sample_contact.merge(email: "email.com")
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid email address. Please re-enter or leave blank."
    assert_includes last_response.body, "Hello"
    assert_includes last_response.body, "Contact Information:"
  end
  
  def test_viewing_edit_contacts_form
    get "/contacts/2/edit"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Contact Information:"
    assert_includes last_response.body, "Jill Thomas"
    assert_includes last_response.body, %q(<input type="submit")
  end
  
  def test_viewing_edit_contacts_form_invalid_id
    get "/contacts/5/edit"
    
    assert_equal 302, last_response.status
    assert_equal "Please select a valid contact.", session[:message]
    
    get last_response["Location"]
    
    assert_includes last_response.body, "Contacts"
    assert_includes last_response.body, "Search by Category"
  end
  
  def test_edit_contact
    post "/contacts/add_contact", sample_contact
    
    post "/contacts/5", sample_contact.merge(email: "hello@email.com")
    
    assert_equal 302, last_response.status
    assert_equal "Contact successfully updated.", session[:message]

    get "/contacts?query=friends"
    
    assert_includes last_response.body, "hello@email.com"
    refute_includes last_response.body, "hello@world.com"
  end
  
  def test_reset_database
    post "/contacts/add_contact", sample_contact
    
    post "/reset"
    
    assert_equal 302, last_response.status
    assert_equal "Thanks for resetting!", session[:message]
    
    get "/contacts?query=friends"
    
    assert_includes last_response.body, "Gene C"
    refute_includes last_response.body, "Hello"
  end
end
 