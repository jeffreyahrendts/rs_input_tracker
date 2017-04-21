require 'sinatra'
require 'coffee-script'
require_relative 'input_audit.rb'
require_relative 'db.rb'

get '/' do
  account_list = Account.list
  erb :index, :locals => {:accounts => account_list}
end

get '/accounts/:account_id/' do
  account_id = params['account_id']
  array_list = ServerArray.list(account_id)
  account_name = Account.get_name(account_id)
  erb :array_list, :locals => {:arrays => array_list,
                               :account => {:name => account_name, :id => account_id}}
end

get '/accounts/:account_id/arrays/:array_id/' do
  account_id = params['account_id']
  array_id = params['array_id']
  input_list = Input.list(account_id,array_id)
  array_data = ServerArray.where(:array_id => array_id,:account_id => account_id).first
  account_name = Account.get_name(account_id)
  erb :input_list, :locals => {:inputs => input_list,
                               :array => array_data,
                               :account => {:name => account_name, :id => account_id}}
end

get '/accounts/:account_id/arrays/:array_id/:input_name/?' do
  account_id = params[:account_id]
  array_id = params[:array_id]
  input_name = params[:input_name]
  input_versions = Input.list_versions(account_id,array_id,input_name)
  array_data = ServerArray.where(:array_id => array_id,:account_id => account_id).first
  account_name = Account.get_name(account_id)
  erb :input_versions, :locals => {:versions => input_versions,
                                   :input_name => input_name,
                                   :array => array_data,
                                   :account => {:name => account_name, :id => account_id}}
end

get '/app.js' do
  coffee :app
end

get '/update' do
  InputAuditor.new.run
  status 200
end

get '/update/:account_id/?' do
  InputAuditor.new(params[:account_id]).run
  redirect to('/')
end

get '/report/:input_name/' do
  input_name = params[:input_name]
  account_list = Account.list
  server_arrays = ServerArray.full_list(account_list)
  inputs = Input.audit_input(account_list, input_name)
  erb :input_report, :locals => {:inputs => inputs,
                                 :arrays => server_arrays,
                                 :input_name => input_name}
end
