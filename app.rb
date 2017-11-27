require 'sinatra/base'
require 'sinatra/contrib'
require "sinatra/reloader"
require 'slim'
require 'sequel'
require 'twilio-ruby'
require 'open-uri'
require 'nokogiri'
require 'pdfkit'
require 'erb'
#require 'wkhtmltopdf'

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
      @db = Sequel.postgres('tmnct-news-subscribers', connect_opt)
    else
      @db = Sequel.connect(ENV['DATABASE_URL'])
    end

    unless @db.table_exists?(:subscribers)
      @db.create_table :subscribers do
        String :email, primary_key: true
      end
    end
  end

  after do
    if defined?(@db)
      @db.disconnect
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
      if @db[:subscribers].where(email: request["email"]).first.nil?
        @db.transaction { @db[:subscribers].insert(request["email"]) }
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
      if @db[:subscribers].where(email: request["email"]).first.nil?
        @title = "配信解除"
        @error = "このメールアドレスは登録されていません。"
        slim :unsubscribe
      else
        @db.transaction { @db[:subscribers].where(email: request["email"]).delete }
        @message = "配信解除が完了しました。"
        slim :index
      end
    end
  end

  get '/twilio' do
    params[:title] ||= 'タイトルがありません'
    Twilio::TwiML::Response.new do |r|
      r.Say '苫小牧高専ニュース', { language: 'ja-JP', voice: 'alice' }
      r.Pause length: '1'
      r.Say URI.unescape(params[:title]), { language: 'ja-JP', voice: 'alice' }
    end.text
  end

  get '/fax' do
    path = "#{params[:category]}/#{params[:post_id]}.html"
    url = "http://www.tomakomai-ct.ac.jp/#{path}"
    doc = Nokogiri::HTML(open(url))
    title = doc.title
    post = doc.search('.post.clearfix')[0].to_html
    erb = ERB.new(File.read(Dir.pwd + '/views/fax.html.erb'))
    html = erb.result(binding)

    pdf = PDFKit.new(html, encoding: 'UTF-8')
    content_type 'application/pdf'
    pdf.to_pdf
  end

  helpers do
    def page_title(title = nil)
      @title = title if title
      @title ? "#{@title} - 苫小牧高専News" : "苫小牧高専News"
    end
  end

  run! if app_file == $0
end
