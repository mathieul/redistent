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
      end
    end
  end
end
