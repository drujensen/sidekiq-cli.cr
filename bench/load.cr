#!/usr/bin/env crystal

require "redis"
require "../src/sidekiq/server/cli"

# This benchmark is an integration test which creates and
# executes 100,000 no-op jobs through Sidekiq.  This is
# useful for determining job overhead and raw throughput
# on different platforms.
#
# Requirements:
#  - Redis running on localhost:6379
#  - `crystal deps`
#  - `crystal run --release bench/load.cr
#

puts "Compiled with #{{{`crystal -v`.stringify}}}"
puts "Running on #{`uname -a`}"

r = Redis.new
r.flushdb

class LoadWorker
  include Sidekiq::Worker

  perform_types Int64
  def perform(idx)
  end
end

def Process.rss
  `ps -o rss= -p #{Process.pid}`.chomp.to_i
end

iter = 10
count = 10_000_i64
total = iter * count

a = Time.now
iter.times do
  args = [] of Array(Int64)
  count.times do |idx|
    args << [idx]
  end
  LoadWorker.async.perform_bulk(args)
end
puts "Created #{count*iter} jobs in #{Time.now - a}"

require "../src/sidekiq/server"
a = Time.now

spawn do
  loop do
    count = r.llen("queue:default")
    if count == 0
      b = Time.now
      puts "Done in #{Time.now - a}: #{"%.3f" % (total / (b - a).to_f)} jobs/sec"
      exit
    end
    p [Time.now, count, Process.rss]
    sleep 0.5
  end
end

devnull = ::Logger.new(File.open("/dev/null", "w"))
s = Sidekiq::CLI.new
x = s.configure(devnull) do |config|
  # nothing
end
s.run(x)
