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
          puts "no need to update #{name} for #{array_id} unchanged"
        end
      else
        Input.create(:account_id => account_id, :array_id => array_id, :input_name => name, :input_value => value, :version => 1)
        puts "saved new input name #{name}"
      end
    end
  end

  def self.list(account_id,array_id)
    Input.table_name = account_id
    Input.most_recent(account_id,array_id)
  end

  def self.list_versions(account_id,array_id,input_name)
    Input.table_name = account_id
    Input.where(:account_id => account_id, :array_id => array_id, :input_name => input_names)
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

  def self.as_of(account_id, array_id,datetime)
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

  def self.create_table
    ActiveRecord::Base.connection.create_table :accounts do |t|
      t.integer :account_id, :null => false
      t.string :account_name, :null => false
      t.timestamps :null => false
    end

  end
end