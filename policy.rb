class Policy
  def data_from_packet(packet)
    puts packet.inspect
    structlog_matches = Hash[packet.content.scan(/([^ ]+)=([^ ]+)/)]
    structlog_matches

    heroku_source = packet.content.split(" ")[3]


    if heroku_source == "router"
      # 2014-07-01T13:26:27.707433+00:00 host heroku router - at=info method=GET path=\"/assets/fontawesome-webfont-4f60293ab9070fc842510705b90cb6b7.woff\" host=qa.telpit.de request_id=f87a9543-afef-4e5b-a908-44f84609e90d fwd=\"109.193.92.70, 108.162.254.177\" dyno=web.1 connect=0ms service=122ms status=200 bytes=83989
      {
        "request_connect_time" => structlog_matches["connect"].to_i,
        "request_service_time" => structlog_matches["service"].to_i,
      }
    elsif heroku_source == "heroku-postgres"
      # 2014-07-01T13:41:38+00:00 host app heroku-postgres - source=HEROKU_POSTGRESQL_GRAY sample#current_transaction=237168 sample#db_size=73492664bytes sample#tables=16 sample#active-connections=4 sample#waiting-connections=0 sample#index-cache-hit-rate=0.9997 sample#table-cache-hit-rate=0.99995 sample#load-avg-1m=0.865 sample#load-avg-5m=0.965 sample#load-avg-15m=0.965 sample#read-iops=67.908 sample#write-iops=5.401 sample#memory-total=7629452kB sample#memory-free=83480kB sample#memory-cached=6846472kB sample#memory-postgres=543284k
      mapping = {
        "postgres_current_transaction" => "sample#current_transaction",
        "postgres_db_size" => "sample#db_size",
        "postgres_tables" => "sample#tables",
        "postgres_active_connections" => "sample#active-connections",
        "postgres_waiting_connections" => "sample#waiting-connections",
        "postgres_index_cache_hit_rate" => "sample#index-cache-hit-rate",
        "postgres_table_cache_hit_rate" => "sample#table-cache-hit-rate",
        "postgres_load_avg_1m" => "sample#load-avg-1m",
        "postgres_load_avg_5m" => "sample#load-avg-5m",
        "postgres_load_avg_15m" => "sample#load-avg-15m",
        "postgres_read_iops" => "sample#read-iops",
        "postgres_write_iops" => "sample#write-iops",
        "postgres_memory_total" => "sample#memory-total",
        "postgres_memory_free" => "sample#memory-free",
        "postgres_memory_cached" => "sample#memory-cached",
        "postgres_memory_postgres" => "sample#memory-postgres",
      }

      Hash[mapping.map { |metric, logkey| [metric, structlog_matches[logkey].to_f] }]
    else
      {}
    end
  end
end
