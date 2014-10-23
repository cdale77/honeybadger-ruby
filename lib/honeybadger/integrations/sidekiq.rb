module Honeybadger
  module Integrations
    module Sidekiq
      class Middleware
        def call(worker, msg, queue)
          Honeybadger.context.clear!
          Honeybadger::Monitor::Trace.instrument("#{msg['class']}#perform", { :source => 'sidekiq', :jid => msg['jid'], :class => msg['class'] }) do
            yield
          end
        end
      end
    end
  end

  Dependency.register do
    requirement { defined?(::Sidekiq) }
    requirement { defined?(::Honeybadger::Monitor) }

    injection do
      ::Sidekiq.configure_server do |config|
        config.server_middleware do |chain|
          chain.add Integrations::Sidekiq::Middleware
        end
      end
    end
  end

  Dependency.register do
    requirement { defined?(::Sidekiq::VERSION) && ::Sidekiq::VERSION > '3' }

    injection do
      ::Sidekiq.configure_server do |config|
        config.error_handlers << Proc.new do |ex,context| 
                                   # Ignore errors below the configured threshold
                                   threshold = ::Honeybadger.configuration.sidekiq_job_attempt_threshold.to_i || 0
                                   retry_count = context['retry_count'].to_i || 0
                                   Honeybadger.notify_or_ignore(ex, :parameters => context) if retry_count > threshold
                                 end
      end
    end
  end
end
