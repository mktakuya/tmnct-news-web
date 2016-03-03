require 'sinatra/base'
require 'sinatra/contrib'
require "sinatra/reloader"
require 'slim'
require 'sequel'

class TmNCTNewsWeb < Sinatra::Base
  register Sinatra::Contrib

  VALID_EMAIL = /\A[a-zA-Z0-9_\#!$%&`'*+\-{|}~^\/=?\.]+@[a-zA-Z0-9][a-zA-Z0-9\.-]+\z/

  configure :development do
    register Sinatra::Reloader
  end

  configure :production do
    set :server, :puma
  end

  before do
    if ENV['DATABASE_URL'].nil?
      connect_opt = YAML.load_file("./db.yml")
      DB = Sequel.postgres('tmnct-news-subscribers', connect_opt)
    else
      DB = Sequel.connect(ENV['DATABASE_URL'])
    end

    unless DB.table_exists?(:subscribers)
      DB.create_table :subscribers do
        String :email, primary_key: true
      end
    end
  end

  after do
    if defined?(DB)
      DB.disconnect
    end
  end

  get '/' do
    slim :index
  end

  post '/subscribe' do
    if VALID_EMAIL !~ request["email"]
      @error = "不正なメールアドレスです"
      slim :index
    else
      if DB[:subscribers].where(email: request["email"]).first.nil?
        DB.transaction { DB[:subscribers].insert(request["email"]) }
        @title = "登録完了"
        slim :subscribe
      else
        @error = "既に登録されているメールアドレスです。"
        slim :index
      end
    end
  end

  get '/unsubscribe' do
    @title = "配信解除"
    slim :unsubscribe
  end

  post '/unsubscribe' do
    if VALID_EMAIL !~ request["email"]
      @title = "配信解除"
      @error = "不正なメールアドレスです"
      slim :unsubscribe
    else
      if DB[:subscribers].where(email: request["email"]).first.nil?
        @title = "配信解除"
        @error = "このメールアドレスは登録されていません。"
        slim :unsubscribe
      else
        DB.transaction { DB[:subscribers].where(email: request["email"]).delete }
        @message = "配信解除が完了しました。"
        slim :index
      end
    end
  end

  helpers do
    def page_title(title = nil)
      @title = title if title
      @title ? "#{@title} - 苫小牧高専News" : "苫小牧高専News"
    end
  end
end
