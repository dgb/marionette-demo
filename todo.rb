require 'rubygems'

require 'mustache/sinatra'
require 'sinatra'
require 'active_record'

# Database

ActiveRecord::Base.establish_connection({
  :adapter => 'sqlite3',
  :database => 'todo.sqlite3'
})

# TODO: Figure the common JSON schema out

ActiveRecord::Base.include_root_in_json = false

ActiveRecord::Schema.define do
  create_table :todos, :force => true do |t|
    t.string :title
    t.text :description
    t.datetime :due
    t.timestamps
  end
end unless ActiveRecord::Base.connection.table_exists? :todos

class Todo < ActiveRecord::Base
end

# Sinatra Settings

module Views
  class Index < Mustache
    def todos
      @todos
    end
  end
  class Show < Mustache
    def todo
      @todo
    end
  end
end

Sinatra::Application.register Mustache::Sinatra

set :mustache, {
  :templates => "views"
}

set :method_override, true


helpers do
  def xhr?
    env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
  end
  
  def json?
    env['HTTP_ACCEPT'] =~ /application\/json/
  end
  
  def json_template(template)
    response['X-Marionette-Template'] = template
  end
  
  def json_redirect(location)
    if json?
      response['X-Marionette-Location'] = location
    else
      redirect to(location)
    end
  end
end

# Send everything as JSON

before do
  content_type :json if json?
end

# List

get '/' do
  redirect to('/todos')
end

get '/todos' do
  @todos = Todo.all
  if json?
    json_template 'index'
    {:todos => @todos}.to_json
  else
    mustache 'index'
  end
end

get '/todos/new' do
  if xhr? && json?
    json_template 'new'
    nil.to_json
  else
    mustache 'new'
  end
end

# Create

post '/todos' do
  @todo = Todo.create(params[:todo])
  json_redirect to("/todos/#{@todo.id}")
end


# Read

get '/todos/:id' do
  @todo = Todo.find(params[:id])
  # TODO: check that caching works accross browsers
  # modified = @todo.updated_at || @todo.created_at
  # last_modified modified
  # cache_control :max_age => 3600
  if xhr? && json?
    json_template 'show'
    {:todo => @todo}.to_json
  else
    mustache 'show'
  end
end

# Update

put '/todos/:id' do
  @todo = Todo.find(params[:id])
  @todo.update(params[:todo])
  puts params
  json_redirect to("/todos/#{@todos.id}")
end

# Destroy

delete '/todos/:id' do
  @todo.delete
  json_redirect to("/todos")
end

# Template access

get '/templates' do
  templates = {}
  Dir["views/*.mustache"].each do |template|
    name = File.basename(template).split(".")[0..-2].join('.')
    templates[name] = File.read(template)
  end
  templates.to_json
end