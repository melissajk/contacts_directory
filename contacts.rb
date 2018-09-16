require 'sinatra'
require 'tilt/erubis'

require_relative 'contacts_database'

CATEGORIES = ["family", "friends", "business"]

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "contacts_database.rb"
end

before do
  @storage = ContactsDatabase.new(logger)
end

helpers do
  def phone_number(digits)
    area_code = digits[0, 3]
    prefix = digits[3, 3]
    last_four = digits[6, 4]
    "(#{area_code})#{prefix}-#{last_four}"
  end
end

def contact_info
  {
    category: params[:category],
    name: params[:name].strip,
    address: params[:address].strip,
    phone: params[:phone].gsub(/[^0-9]/, ''),
    email: params[:email].strip
  }
end

def required_fields_error
  if [contact_info[:name], contact_info[:phone]].all?(&:empty?)
    "You must include a name and phone number."
  elsif contact_info[:name].empty?
    "You must include a name."
  else
    nil
  end
end

def invalid_phone_number
  message = "Invalid phone number, please provide 10 digits."

  contact_info[:phone].size == 10 ? nil : message
end

def invalid_email_address
  return nil if contact_info[:email].empty?
  message = "Invalid email address. Please re-enter or leave blank."

  contact_info[:email].match(/^\w+@\w+.\w+$/) ? nil : message
end

def error_for_contact_info
  required_fields_error ||
  invalid_phone_number  ||
  invalid_email_address ||
  nil
end

def find_contacts(query)
  return @storage.find_contacts_in_category(query) if CATEGORIES.include?(query)
  query.strip.empty? ? [] : @storage.find_contact_by_name(query)
end

after do
  @storage.disconnect
end

get "/" do
  redirect "/contacts"
end

get "/contacts" do
  @results = find_contacts(params[:query]) if params[:query]
  erb :index
end

get "/contacts/add_contact" do
  erb :new_contact
end

post "/contacts/add_contact" do
  error = error_for_contact_info
  
  if error
    session[:message] = error
    status 422
    erb :new_contact
  else
    @storage.add_contact(contact_info)
    session[:message] = "#{contact_info[:name]} has been added to your directory."
    redirect "/contacts"
  end
end

get "/contacts/:id/edit" do
  id = params[:id].to_i
  if @storage.id_list.include?(id)
    @contact = @storage.find_contact_by_id(id).first
    erb :edit_contact
  else
    session[:message] = "Please select a valid contact."
    redirect "/contacts"
  end
end

post "/contacts/:id" do
  id = params[:id].to_i
  @contact = @storage.find_contact_by_id(id).first

  error = error_for_contact_info
  if error
    session[:message] = error
    status 422
    erb :edit_contact
  else
    id = params[:id].to_i
    @storage.update_contact(contact_info, id)
    session[:message] = "Contact successfully updated."
    redirect "/contacts"
  end
end

post "/contacts/:id/delete" do
  id = params[:id].to_i
  @storage.delete_contact(id)
  session[:message] = "Contact has been deleted."
  redirect "/contacts"
end

post "/reset" do
  @storage.reset
  session[:message] = "Thanks for resetting!"
  redirect "/contacts"
end
