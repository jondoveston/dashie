require 'dashing'

CONFIG = YAML.load_file('config.yml')

configure do
  set :auth_token, 'YOUR_AUTH_TOKEN'

  # See http://www.sinatrarb.com/intro.html > Available Template Languages on
  # how to add additional template languages.
  set :template_languages, %i[html erb]
  set :show_exceptions, false
  set :default_dashboard, 'systems'

  helpers do
    def protected!
      # Put any authentication code you want in here.
      # This method is run before accessing any resource.
    end
  end

  get '/wol/:system' do
    protected!
    redirect '/' + params[:system]
  end

  get /\/host\/(#{CONFIG.keys.join('|')})/ do
    protected!

    params[:host] = params[:captures].first
    settings.template_languages.each do |language|
      file = File.join(settings.views, "host.#{language}")
      return render(language, :host) if File.exist?(file)
    end

    halt 404
  end

  # The smashing JS uses a relative path for the events endpoint
  get '/host/events' do
    status, headers, body = call env.merge('PATH_INFO' => '/events')
    [status, headers, body]
  end
end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

run Sinatra::Application
