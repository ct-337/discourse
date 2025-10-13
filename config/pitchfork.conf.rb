# frozen_string_literal: true

discourse_path = File.expand_path(File.expand_path(File.dirname(__FILE__)) + "/../")
enable_logstash_logger = ENV["ENABLE_LOGSTASH_LOGGER"] == "1"
unicorn_stderr_path = "#{discourse_path}/log/unicorn.stderr.log"

if enable_logstash_logger
  require_relative "../lib/discourse_logstash_logger"
  FileUtils.touch(unicorn_stderr_path) if !File.exist?(unicorn_stderr_path)
  logger DiscourseLogstashLogger.logger(
           logdev: unicorn_stderr_path,
           type: :unicorn,
           customize_event: lambda { |event| event["@timestamp"] = ::Time.now.utc },
         )
else
  logger Logger.new(STDOUT)
end

worker_processes (ENV["UNICORN_WORKERS"] || 3).to_i

# stree-ignore
listen ENV["UNICORN_LISTENER"] || "#{(ENV["UNICORN_BIND_ALL"] ? "" : "127.0.0.1:")}#{(ENV["UNICORN_PORT"] || 3000).to_i}"

if ENV["RAILS_ENV"] == "production"
  # nuke workers after 30 seconds instead of 60 seconds (the default)
  timeout 30
else
  # we want a longer timeout in dev cause first request can be really slow
  timeout(ENV["UNICORN_TIMEOUT"] && ENV["UNICORN_TIMEOUT"].to_i || 60)
end

check_client_connection false

before_fork { |server| Discourse.redis.close }

after_mold_fork do |server, mold|
  Discourse.preload_rails! if mold.generation.zero?
  Discourse.redis.close
  Discourse.before_fork
end

after_worker_fork do |server, worker|
  DiscourseEvent.trigger(:web_fork_started)
  Discourse.after_fork
  SignalTrapLogger.instance.after_fork
end
