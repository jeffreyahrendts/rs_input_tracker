require 'rubygems'
require 'sinatra'
require 'active_record'

#todo, create indexes for tables


ActiveRecord::Base.establish_connection(
    :adapter => 'mysql2',
    :host => ENV['DBHOSTS'],
    :username => ENV['DBUSER'],
    :password => ENV['DBPASS'],
    :database => ENV['DBNAME']
)


class Input < ActiveRecord::Base
  def self.create_batch(sorted_inputs, array_id, account_id)
    create_table(account_id) unless ActiveRecord::Base.connection.table_exists? "#{account_id}"
    Input.table_name = account_id
    latest_inputs = Input.most_recent(account_id, array_id)
    sorted_inputs.each do |name, value|
      matched_input = latest_inputs.select { |input| input.input_name == name }
      raise("input #{name} for #{array_id} returned multiple values") if matched_input.count > 1
      unless matched_input.empty?
        unless matched_input.first.input_value == value
          new_version = matched_input.first.version + 1
          Input.create(:account_id => account_id, :array_id => array_id, :input_name => name, :input_value => value, :version => new_version)
          puts "updated #{name} to version #{new_version}"
        else
          puts "Input #{name} in array:#{array_id} unchanged, skipping"
        end
      else
        Input.create(:account_id => account_id, :array_id => array_id, :input_name => name, :input_value => value, :version => 1)
        puts "saved new input name #{name}"
      end
    end
  end

  def self.list(account_id, array_id)
    Input.table_name = account_id
    Input.most_recent(account_id, array_id)
  end

  def self.list_versions(account_id, array_id, input_name)
    Input.table_name = account_id
    Input.where(:account_id => account_id, :array_id => array_id, :input_name => input_name)
  end


  def self.most_recent(account_id, array_id)
    query = <<-SQL
      SELECT * FROM `#{account_id}` t WHERE
        array_id = t.array_id
          AND input_name = t.input_name
          AND version = (SELECT MAX(version)
            FROM
              `#{account_id}`
          WHERE
              array_id = t.array_id
                  AND input_name = t.input_name)
      AND array_id = #{array_id} AND account_id = #{account_id}
    SQL
    self.find_by_sql(query)
  end

  def self.as_of(account_id, array_id, datetime)
    query = <<-SQL
      SELECT * FROM `#{account_id}` t WHERE
        array_id = t.array_id
          AND input_name = t.input_name
          AND version = (SELECT MAX(version)
            FROM
              `#{account_id}`
          WHERE
              array_id = t.array_id
                  AND input_name = t.input_name AND created_at <= datetime )
      AND array_id = #{array_id} AND account_id = #{account_id}
    SQL
    self.find_by_sql(query)
  end

  def self.audit_account_input(account_id, input_name)
    query = <<-SQL
      SELECT ANY_VALUE(id) as id, ANY_VALUE(account_id) as account_id,
        array_id, ANY_VALUE(input_value) as input_value,
        MAX(version) as version, ANY_VALUE(created_at) as created_at,
        ANY_VALUE(updated_at) as updated_at
        FROM `#{account_id}` WHERE array_id IN (
          SELECT DISTINCT array_id FROM `#{account_id}`
          WHERE input_name = '#{input_name}' )
      AND input_name = '#{input_name}' GROUP BY array_id;
    SQL
    self.find_by_sql(query)
  end

  def self.audit_input(accounts, input_name)
    # Declare a variable to hold results
    results = Hash.new
    accounts.each do | account |
      Input.table_name = account.account_id
      results.store( account.account_name, audit_account_input(account.account_id , input_name) )
    end
    return results
  end

  def self.create_table(account_id)
    ActiveRecord::Base.connection.create_table "#{account_id}".to_sym do |t|
      t.integer :account_id, :null => false
      t.integer :array_id, :null => false
      t.string :input_name, :null => false
      t.text :input_value, :null => false
      t.integer :version, :null => false
      t.timestamps :null => false
    end
  end
end

class ServerArray < ActiveRecord::Base
  def self.list(account_id)
    ServerArray.where(:account_id => account_id)
  end

  def self.full_list(accounts)
    # Declare a variable to hold results
    results = Hash.new
    accounts.each do | account |
      temp_hash = Hash.new
      list( account.account_id ).each do | server_array |
        temp_hash.store( server_array.array_id, server_array.array_name )
      end
      results.store( account.account_name, temp_hash )
    end
    return results
  end

  def self.create_batch(account_id, arrays)
    create_table unless ActiveRecord::Base.connection.table_exists? 'server_arrays'
    arrays.each do |array_details|
      ServerArray.find_or_create_by(:account_id => account_id, :array_id => array_details[:array_id], :array_name => array_details[:name])
    end
  end

  def self.create_table
    ActiveRecord::Base.connection.create_table :server_arrays do |t|
      t.integer :account_id, :null => false
      t.integer :array_id, :null => false
      t.string :array_name, :null => false
      t.timestamps :null => false
    end

  end
end

class RawInput < ActiveRecord::Base
end

class Account < ActiveRecord::Base
  def self.store(account_hash)
    create_table unless ActiveRecord::Base.connection.table_exists? 'accounts'
    Account.find_or_create_by(:account_id => account_hash[:id], :account_name => account_hash[:name])
  end

  def self.list
    Account.all
  end

  def self.get_name(account_id)
    account = Account.where(:account_id => account_id).first
    account.account_name
  end

  def self.create_table
    ActiveRecord::Base.connection.create_table :accounts do |t|
      t.integer :account_id, :null => false
      t.string :account_name, :null => false
      t.timestamps :null => false
    end

  end
end
