module RedisHelper
  def redis
    @redis ||= Redis.new(redis_config)
  end

  def config
    @config ||= begin
      Redistent::Config.new.tap do |config|
        config.set_namespace MusicClasses
        config.add_model :musician do
          references :band
        end
        config.add_model :band do
          collection :songs, sort_by: :popularity
        end
        config.add_model :song do
          references :band
        end
      end
    end
  end
end
