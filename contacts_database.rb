require 'pg'

class ContactsDatabase
  
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          elsif ENV["RACK_ENV"] == "test"
            PG.connect(dbname: "contacts_test")
          else
            PG.connect(dbname: "contacts")
          end
    @logger = logger
  end
  
  def reset
    @db.exec("DROP TABLE contacts")
    schema = if ENV["RACK_ENV"] == "test"
               File.read("test_schema.sql")
             else
               File.read("schema.sql")
             end
    @db.exec(schema)
  end
  
  def disconnect
    @db.close
  end
  
  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end
  
  def duplicate_contact_name?(name)
    sql = "SELECT * FROM contacts WHERE name = $1;"
    result = query(sql, "#{name}")
    result.values.size > 0
  end
  
  def find_contact_by_name(name)
    sql = "SELECT * FROM contacts WHERE name ILIKE $1;"
    result = query(sql, "%#{name}%")
    
    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end
  
  def add_contact(contact_info)
    sql = <<~SQL
     INSERT INTO contacts (category, name, address, phone_number, email)
     VALUES ($1, $2, $3, $4, $5);
     SQL
    query(sql, *contact_info.values)
  end
  
  def find_contacts_in_category(category)
    sql = "SELECT * FROM contacts WHERE category = $1"
    result = query(sql, category)
    
    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end
  
  def find_contact_by_id(id)
    sql = "SELECT * FROM contacts WHERE id = $1"
    result = query(sql, id)
    
    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end
  
  def update_contact(contact_info, id)
    sql = <<~SQL
     UPDATE contacts SET category = $1,
     name = $2,
     address = $3,
     phone_number = $4,
     email = $5 WHERE id = $6;
     SQL
     updated_info = contact_info.values << id
    query(sql, *updated_info)
  end
  
  def id_list
    sql = "SELECT id FROM contacts;"
    query(sql).values.flatten.map(&:to_i)
  end
  
  def delete_contact(id)
    sql = "DELETE FROM contacts WHERE id = $1"
    query(sql, id)
  end
  
  def tuple_to_list_hash(tuple)
    { id:       tuple["id"].to_i,
      category: tuple["category"],
      name:     tuple["name"],
      phone:    tuple["phone_number"],
      address:  tuple["address"],
      email:    tuple["email"]
    }
  end
end
