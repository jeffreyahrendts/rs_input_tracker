require 'rubygems'
require 'right_api_client'
require 'yaml'
require 'json'
require 'fileutils'


class InputAuditor
  def initialize
    @rightscale_credentials = YAML.load_file('rightscale.yml')[:rightscale]
    @threads = []
  end

  def run
    rs_email = @rightscale_credentials[:email]
    rs_password = @rightscale_credentials[:password]
    rs_accounts = @rightscale_credentials[:account_id]
    rs_accounts.each do |rs_account|
      puts "connecting to RS account #{rs_account}"
      #deployment details can be split out into single deployment details file per account
      rs_client = RightApi::Client.new(:email => rs_email, :password => rs_password, :account_id => rs_account, :timeout => nil)
      @threads.push(Thread.new { process_inputs(rs_client, rs_account) })
    end
    @threads.each { |thread| thread.join }
  end

  def process_inputs(rs_connection, account_id)
    server_arrays = rs_connection.server_arrays.index
    manifest = {}
    server_arrays.each do |array|
      manifest[array.href.split('/').last] = {:name => array.name, :href => array.href, :deployment_name => array.deployment.show.name}
    end
    server_arrays.each do |server_array|
      array_id = server_array.href.split('/').last
      puts "processing #{array_id}@#{account_id}"
      inputs = server_array.show.next_instance.show.inputs.index
      sorted_inputs = extract_and_sort_inputs(inputs)
      write_audit_to_file(sorted_inputs, array_id, account_id)
    end
    sorted_manifest = manifest.sort_by { |k, v| k }.to_h
    write_audit_to_file(sorted_manifest, 'manifest', account_id)
  end


  def extract_and_sort_inputs(inputs)
    array_inputs = {}
    inputs.each do |input|
      array_inputs[input.name] = input.value
    end
    return array_inputs.sort_by { |k, v| k }.to_h
  end

  def write_audit_to_file(sorted_inputs, filename, account_id)
    path = "arrays/#{account_id}/#{filename}.json"
    FileUtils.mkdir_p("./arrays/#{account_id}") unless Dir.exist?("./arrays/#{account_id}")
    File.open(path, 'w') do |f|
      f.write(JSON.pretty_generate(sorted_inputs))
    end
  end

end

class GitCommit
  def initialize

  end

  def run_shell_command(cmd)
    res=`#{cmd}`
    res
  end

  def push_changes
    puts 'preparing commit'
    cmd = 'git pull'
    run_shell_command(cmd)
    cmd = 'git add -A'
    run_shell_command(cmd)
    cmd = "git commit -a -m \'autocommit from input auditor\'"
    run_shell_command(cmd)
    cmd = 'git push'
    run_shell_command(cmd)
  end
end


InputAuditor.new.run
#GitCommit.new.push_changes