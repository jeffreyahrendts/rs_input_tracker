#!/usr/bin/env ruby
#http://bogojoker.com/readline/

require 'yaml'
require 'json'
require 'pry'
require 'formatador'
require 'readline'
$DEBUG = true

@rightscale_credentials = YAML.load_file('rightscale.yml')[:rightscale]
@rs_accounts = @rightscale_credentials[:account_id]
$account_list = YAML.load_file('accounts.yml')[:accounts]
@valid_resources = ['arrays','inputs','accounts']


def write_yaml(data, filename)
  File.open("#{filename}.yml", 'w') { |f| f.write data.to_yaml }
end

def write_json(data, filename)
  File.open("#{filename}.json", 'w') { |f| f.write data.to_json }
end


def display_table(data_hash,order)
  if data_hash.empty?
    puts 'Empty set'
    return
  end
  Formatador.display_table(data_hash,order)
end

def valid_account?(acct_id)
  !!$account_list.detect {|account| account['ID'] == acct_id.to_i}
end

def list_arrays
  manifest = JSON.parse(IO.read("arrays/#{$account}/manifest.json"))
  arrays = []
  manifest.each do |array|
    arrays.push({ id: array[0], name: array[1]['name'], deployment: array[1]['deployment_name']})
  end
  arrays.select! {|i| yield(i)} if block_given?
  display_table(arrays,[:id,:name,:deployment])
end

def list_inputs
  inputs = JSON.parse(IO.read("arrays/#{$account}/#{$array_id}.json"))
  inputs_list = []
  inputs.each do |input|
    type,value = input[1].split(':')
    inputs_list.push({ type: type, name: input[0], value: value})
  end
  inputs_list.select! {|i| yield(i)} if block_given?
  display_table(inputs_list,[:type,:name,:value])
end

def define_account
  if $account == nil
    puts 'Please select an account and try again'
    process_command('list accounts')
  end
end

def is_filter(resource,lookup_column,lookup_value)
  self.send("list_#{resource}") do |i|
    # puts "comparing #{i[lookup_column.to_sym].downcase} to #{lookup_value.downcase}" if $DEBUG
    # puts "MATCH!!" if i[lookup_column.to_sym].downcase.include?(lookup_value.downcase) if $DEBUG
    i[lookup_column.to_sym].downcase.eql?(lookup_value.downcase)
  end
end

def like_filter(resource,lookup_column,lookup_value)
  self.send("list_#{resource}") do |i|
    # puts "comparing #{i[lookup_column.to_sym].downcase} to #{lookup_value.downcase}" if $DEBUG
    # puts "MATCH!!" if i[lookup_column.to_sym].downcase.include?(lookup_value.downcase) if $DEBUG
    i[lookup_column.to_sym].downcase.include?(lookup_value.downcase)
  end
end

def regex_search(resource,lookup_column,lookup_value,search_type)
  if search_type.downcase == 'is'
    is_filter(resource,lookup_column,lookup_value)
  elsif search_type.downcase == 'like'
    like_filter(resource,lookup_column,lookup_value)
  end
end

def define_array
  define_account
  if $array_id == nil
    puts 'please select an array and try again'
    process_command('list arrays')
  end
end


def process_command(command)
  case command
    when 'list accounts'
      display_table($account_list)
    when /^use account (.*)/i
      acct = $1
      if valid_account?(acct)
        puts "using account #{acct}"
        $account = acct
      else
        puts "Account #{acct} not found, use the list accounts command to view list of valid accounts"
      end
    when 'account?'
      if $account != nil
        puts $account
      else
        puts 'no account currently specified'
        puts "\n\n"
      end
    when 'list arrays'
      define_account
      list_arrays
    when /^use array (.*)/i
      array_id = $1
      puts "using array ID #{array_id}"
      $array_id = array_id
    when 'array?'
      if $array_id != nil
        puts $array_id
      else
        puts 'no array currently specified'
        puts "\n\n"
      end
    when 'list inputs','show inputs'
      define_array
      list_inputs
    when /^select (\w+) where (\w+) (is|like) (.*)/i
      resource =$1
      key =$2
      search_type = $3
      value =$4
      if @valid_resources.include?(resource)
        regex_search(resource,key,value,search_type)
      else
        puts "Error: unknown resource #{resource}"
      end
    when 'exit','quit'
      puts '😓 See you later'
      exit(0)
    else
      puts "-RS_CLI: #{command}: command not found"
  end
end


# to_yaml and to_json are available
system('clear')
$stdout.print "******Welcome to the Rightscale CLI  😎  ******\n"
$account = 44210 if $DEBUG
$array_id = '475568003' if $DEBUG
while command = Readline.readline('RS_CLI $ ', true)
  process_command(command)
end


