module RedisHelper
  def redis
    @redis ||= Redis.new(redis_config)
  end

  def config
    @config ||= begin
      Redistent::Config.new.tap do |config|
        config.add_model :musician do
          references :band
        end
        config.add_model :band
        config.add_model :song
      end
    end
  end
end
