# Build a RESTful JSON API With Rails 5 - Part Three

In part two of this tutorial, we added token-based authentication with JWT (JSON Web Tokens) to our todo API.

In this final part of the series, we'll wrap with the following:

- Versioning
- Serializers
- Pagination

# Versioning
When building an API whether public or internal facing, it's highly recommended that you version it. This might seem trivial when you have total control over all clients. However, when the API is public facing, you want to establish a contract with your clients. Every breaking change should be a new version. Convincing enough? Great, let's do this!

---
## Table of Contents
 Versioning
 Serializers
Pagination
 Conclusion
In order to version a Rails API, we need to do two things:

Add a route constraint - this will select a version based on the request headers
Namespace the controllers - have different controller namespaces to handle different versions.
Rails routing supports advanced constraints. Provided an object that responds to matches?, you can control which controller handles a specific route.

We'll define a class ApiVersion that checks the API version from the request headers and routes to the appropriate controller module. The class will live in app/lib since it's non-domain-specific.

# create the class file
$ touch app/lib/api_version.rb
Implement ApiVersion

# app/lib/api_version.rb
class ApiVersion
  attr_reader :version, :default

  def initialize(version, default = false)
    @version = version
    @default = default
  end

  # check whether version is specified or is default
  def matches?(request)
    check_headers(request.headers) || default
  end

  private

  def check_headers(headers)
    # check version from Accept headers; expect custom media type `todos`
    accept = headers[:accept]
    accept && accept.include?("application/vnd.todos.#{version}+json")
  end
end
The ApiVersion class accepts a version and a default flag on initialization. In accordance with Rails constraints, we implement an instance method matches?. This method will be called with the request object upon initialization. From the request object, we can access the Accept headers and check for the requested version or if the instance is the default version. This process is called content negotiation. Let's add some more context to this.

Content Negotiation
REST is closely tied to the HTTP specification. HTTP defines mechanisms that make it possible to serve different versions (representations) of a resource at the same URI. This is called content negotiation.

Our ApiVersion class implements server-driven content negotiation where the client (user agent) informs the server what media types it understands by providing an Accept HTTP header.

Related Course: Getting Started with JavaScript for Web Development
According to the Media Type Specification, you can define your own media types using the vendor tree i.e. application/vnd.example.resource+json.

The vendor tree is used for media types associated with publicly available products. It uses the "vnd" facet.

Thus, we define a custom vendor media type application/vnd.todos.{version_number}+json giving clients the ability to choose which API version they require.

Cool, now that we have the constraint class, let's change our routing to accommodate this. Since we don't want to have the version number as part of the URI (this is argued as an anti-pattern), we'll make use of the module scope to namespace our controllers.

Let's move the existing todos and todo-items resources into a v1 namespace.

# config/routes
Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # namespace the controllers without affecting the URI
  scope module: :v1, constraints: ApiVersion.new('v1', true) do
    resources :todos do
      resources :items
    end
  end

  post 'auth/login', to: 'authentication#authenticate'
  post 'signup', to: 'users#create'
end
We've set the version constraint at the namespace level. Thus, this will be applied to all resources within it. We've also defined v1 as the default version; in cases where the version is not provided, the API will default to v1. In the event we were to add new versions, they would have to be defined above the default version since Rails will cycle through all routes from top to bottom searching for one that matches(till method matches? resolves to true).

Next up, let's move the existing todos and items controllers into the v1 namespace. First, create a module directory in the controllers folder.

$ mkdir app/controllers/v1
Move the files into the module folder.


$ mv app/controllers/{todos_controller.rb,items_controller.rb} app/controllers/v1
That's not all, let's define the controllers in the v1 namespace. Let's start with the todos controller.

# app/controllers/v1/todos_controller.rb
module V1
  class TodosController < ApplicationController
  # [...]
  end
end
Do the same for the items controller.

# app/controllers/v1/items_controller.rb
module V1
  class ItemsController < ApplicationController
  # [...]
  end
end
Let's fire up the server and run some tests.

# get auth token
$ http :3000/auth/login email=foo@bar.com password=foobar
# get todos from API v1
$ http :3000/todos Accept:'application/vnd.todos.v1+json' Authorization:'ey...AWH3FNTd3T0jMB7HnLw2bYQbK0g'
# attempt to get from API v2
$ http :3000/todos Accept:'application/vnd.todos.v2+json' Authorization:'ey...AWH3FNTd3T0jMB7HnLw2bYQbK0g'


In case we attempt to access a nonexistent version, the API will default to v1 since we set it as the default version. For testing purposes, let's define v2.

Generate a v2 todos controller


$ rails g controller v2/todos
Define the namespace in the routes.

#config/routes.rb
Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # module the controllers without affecting the URI
  scope module: :v2, constraints: ApiVersion.new('v2') do
    resources :todos, only: :index
  end

  scope module: :v1, constraints: ApiVersion.new('v1', true) do
    # [...]
  end
  # [...]
end
Remember, non-default versions have to be defined above the default version.

Since this is test controller, we'll define an index controller with a dummy response.

# app/controllers/v2/todos_controller.rb
class V2::TodosController < ApplicationController
  def index
    json_response({ message: 'Hello there'})
  end
end
Note the namespace syntax, this is shorthand in Ruby to define a class within a namespace. Great, now fire up the server once more and run some tests.

# get todos from API v1
$ http :3000/todos Accept:'application/vnd.todos.v1+json' Authorization:'eyJ0e...Lw2bYQbK0g'
# get todos from API v2
$ http :3000/todos Accept:'application/vnd.todos.v2+json' Authorization:'eyJ0e...Lw2bYQbK0g'


Voila! Our API responds to version 2!

# Serializers
At this point, if we wanted to get a todo and its items, we'd have to make two API calls. Although this works well, it's not ideal.



We can achieve this with serializers. Serializers allow for custom representations of JSON responses. Active model serializers make it easy to define which model attributes and relationships need to be serialized. In order to get todos with their respective items, we need to define serializers on the Todo model to include its attributes and relationships.

First, let's add active model serializers to the Gemfile:


# Gemfile
# [...]
  gem 'active_model_serializers', '~> 0.10.0'
# [...]
Run bundle to install it:

$ bundle install
Generate a serializer from the todo model:

$ rails g serializer todo
This creates a new directory app/serializers and adds a new file todo_serializer.rb. Let's define the todo serializer with the data that we want it to contain.

# app/serializers/todo_serializer.rb
class TodoSerializer < ActiveModel::Serializer
  # attributes to be serialized  
  attributes :id, :title, :created_by, :created_at, :updated_at
  # model association
  has_many :items
end
We define a whitelist of attributes to be serialized and the model association (only defined attributes will be serialized). We've also defined a model association to the item model, this way the payload will include an array of items. Fire up the server, let's test this.


# create an item for todo with id 1
$ http POST :3000/todos/1/items name='Listen to Don Giovanni' Accept:'application/vnd.todos.v1+json' Authorization:'ey...HnLw2bYQbK0g'
# get all todos
$ http :3000/todos Accept:'application/vnd.todos.v1+json' Authorization:'ey...HnLw2bYQbK0g'


This is great. One request to rule them all!

# Pagination
Our todos API has suddenly become very popular. All of a sudden everyone has something to do. Our data set has grown substantially. To make sure the requests are still fast and optimized, we're going to add pagination; we'll give clients the power to say what portion of data they require.

To achieve this, we'll make use of the will_paginate gem.

Let's add it to the Gemfile:

# Gemfile
# [...]
  gem 'will_paginate', '~> 3.1.0'
# [...]
Install it:

$ bundle install
Let's modify the todos controller index action to paginate its response.

# app/controllers/v1/todos_controller.rb
module V1
  class TodosController < ApplicationController
  # [...]
  # GET /todos
  def index
    # get paginated current user todos
    @todos = current_user.todos.paginate(page: params[:page], per_page: 20)
    json_response(@todos)
  end
  # [...]
end
The index action checks for the page number in the request params. If provided, it'll return the page data with each page having twenty records each. As always, let's fire up the Rails server and run some tests.


# request without page
$ http :3000/todos Accept:'application/vnd.todos.v1+json' Authorization:'eyJ0...nLw2bYQbK0g'
# request for page 1
$ http :3000/todos page==1 Accept:'application/vnd.todos.v1+json' Authorization:'eyJ0...nLw2bYQbK0g'
# request for page 2
$ http :3000/todos page==2 Accept:'application/vnd.todos.v1+json' Authorization:'eyJ0...nLw2bYQbK0g'


The page number is part of the query string. Note that when we request the second page, we get an empty array. This is because we don't have more that 20 records in the database. Let's seed some test data into the database.

Add faker and install faker gem. Faker generates data at random.

# Gemfile
# [...]
  gem 'faker'
# [...]
In db/seeds.rb let's define seed data.

# db/seeds.rb
# seed 50 records
50.times do
  todo = Todo.create(title: Faker::Lorem.word, created_by: User.first.id)
  todo.items.create(name: Faker::Lorem.word, done: false)
end
Seed the database by running:

$ rake db:seed
Awesome, fire up the server and rerun the HTTP requests. Since we have test data, we're able to see data from different pages.



# Conclusion
Congratulations for making it this far! We've come a long way! We've gone through generating an API-only Rails application, setting up a test framework, using TDD to implement the todo API, adding token-based authentication with JWT, versioning our API, serializing with active model serializers, and adding pagination features.

Having gone through this series, I believe you should be able to build a RESTful API with Rails 5. Feel free to leave any feedback you may have in the comments section below. If you found the tutorial helpful, don't hesitate to hit that share button. Cheers!

#### Credits

[Austin Kabiru](https://scotch.io/tutorials/build-a-restful-json-api-with-rails-5-part-three)
