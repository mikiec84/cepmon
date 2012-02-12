require "cepmon/admin"
require "cepmon/engine"
require "cepmon/eventlistener/stdout"
require "cepmon/metric"
require "rubygems"
require "bunny"

module CEPMon
  class Mon
    def initialize(config)
      @config = config
      @engine = CEPMon::Engine.new
      @event_listener = CEPMon::EventListener::Stdout.new(@engine, true)
      @engine.add_statements(@config, @event_listener)
    end

    def run(args)
      Thread::abort_on_exception = true
      @admin = Thread.new do
        CEPMon::Admin.engine = @engine
        CEPMon::Admin.run!(:host => "0.0.0.0", :port => 8989)
      end

      amqp = Bunny.new(@config.amqp)
      amqp.start
      queue = amqp.queue("cepmon-#{Process.pid}", :auto_delete => true)
      exchange = amqp.exchange("stats", :type => :topic, :durable => true)
      queue.bind(exchange)
      queue.subscribe do |msg|
        msg[:payload].split("\n").each do |line|
          CEPMon::Metric.new(line).send(@engine)
        end
      end
    end # def run
  end # class Mon
end # module CEPMon
