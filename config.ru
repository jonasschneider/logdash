require 'sinatra'
require 'redis'
require 'syslog_protocol'
require 'json'

require_relative 'policy'

ENV["REDIS_URL"] ||= ENV["REDISTOGO_URL"]
ENV["REDIS_URL"] ||= "redis://localhost:6379"
uri = URI.parse(ENV["REDIS_URL"])
$redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
if (db_number = uri.path[1..-1]) && !db_number.empty?
  $redis.select(db_number.to_i)
end

get '/' do
  redirect '/index.html'
end


get '/recent' do
  all_keys = $redis.smembers("metrics") - ["postgres_db_size"]

  groups = [
    %w(request_service_time),
    %w(postgres_read_iops postgres_write_iops),
    %w(postgres_load_avg_1m),

    %w(postgres_index_cache_hit_rate postgres_table_cache_hit_rate),
    %w(postgres_current_transaction),
    %w(postgres_db_size),
    %w(postgres_tables),
    %w(postgres_active_connections postgres_waiting_connections),

    %w(postgres_memory_total postgres_memory_free postgres_memory_cached postgres_memory_postgres),
  ]

  groups = groups + (all_keys-groups.flatten).map {|metric| [metric] }

  group_graphs = groups.map do |keys|
    series = keys.map do |metric|
      points = $redis.lrange("data:#{metric}", 0, 100).map{|x| JSON.parse(x) }.map{|x| {time: x["time"], y: x["value"]} }.sort_by{|x| x[:time]}
      {label: metric, values: points}
    end

    { title: keys.join(" & "), series: series }
  end

  content_type 'application/json'

  group_graphs.to_json
end


class Handler < Struct.new(:policy)
  def deal_with_packet(packet)
    sample = policy.data_from_packet(packet)

    sample.each do |k, v|
      $redis.sadd("metrics", k)
      $redis.lpush("data:#{k}", { value: v, time: packet.time.utc.to_i }.to_json)
      $redis.ltrim("data:#{k}", 0, 99)
    end
  end
end

$handler = Handler.new(Policy.new)

OCTET_COUNTING_REGEXP = /^([0-9]+)\s+/

post '/' do
  buf = request.body.read
  orig_buf = buf.dup

  packets = []

  # https://tools.ietf.org/html/rfc6587#section-3.4.1
  while m = OCTET_COUNTING_REGEXP.match(buf)
    msg_len = m[1].to_i - 1
    len_len = m[1].length
    msg = buf.byteslice(len_len+1, msg_len)

    packets << SyslogProtocol.parse(msg)
    buf.slice!(0..(m[0].length + msg_len))
  end

  if packets.length != request.env["HTTP_LOGPLEX_MSG_COUNT"].to_i
    halt 400, "invalid message count"
  end

  packets.each do |x|
    $handler.deal_with_packet(x)
  end

  "ok"
end

use Rack::Static, :root => 'public'
run Sinatra::Application
