require 'rubygems'
require 'right_api_client'
require 'yaml'
require 'json'



class InputAuditor
  def initialize(account = nil)
    @rightscale_credentials = YAML.load_file('./jobs/rightscale.yml')[:rightscale]
    @threads = []
    @mutex = Mutex.new
    @rightscale_credentials[:account_id] = [account] unless account.nil?
  end

  def run
    rs_email = @rightscale_credentials[:email]
    rs_password = @rightscale_credentials[:password]
    rs_accounts = @rightscale_credentials[:account_id]
    rs_accounts.each do |rs_account|
      puts "connecting to RS account #{rs_account}"
      rs_client = RightApi::Client.new(:email => rs_email, :password => rs_password, :account_id => rs_account, :timeout => nil)
      @threads.push(Thread.new { process_inputs(rs_client, rs_account) })
    end
    @threads.each { |thread| thread.join }
  end

  def process_inputs(rs_connection, account_id)
    #get account name
    account_name = rs_connection.accounts(:id => account_id).show.name
    #update or store new account in Accounts table
    Account.store({:id => account_id, :name => account_name})
    server_arrays = rs_connection.server_arrays.index
    manifest = []
    server_arrays.each do |array|
      manifest.push({:array_id => array.href.split('/').last,:name => array.name})
    end
    ServerArray.create_batch(account_id,manifest)
    server_arrays.each do |server_array|
      array_id = server_array.href.split('/').last
      puts "processing #{array_id}@#{account_id}"
      inputs = server_array.show.next_instance.show.inputs.index
      sorted_inputs = extract_and_sort_inputs(inputs)
      @mutex.synchronize do
        write_audit(sorted_inputs, array_id, account_id)
      end
    end
  end


  def extract_and_sort_inputs(inputs)
    array_inputs = {}
    inputs.each do |input|
      array_inputs[input.name] = input.value
    end
    return array_inputs.sort_by { |k, v| k }.to_h
  end

  def write_audit(sorted_inputs, array_id, account_id)
    Input.create_batch(sorted_inputs,array_id,account_id)
  end
end