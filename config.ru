require 'sinatra'

get '/' do

end

use Rack::Static, :urls => [""], :root => 'public', :index => 'index.html'
run Sinatra::Application
