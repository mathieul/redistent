module Redistent
  class Collection
    include HasModelKeys

    attr_reader :accessor, :model, :description

    def initialize(accessor, model, description)
      @accessor    = accessor
      @model       = model
      @description = description
      add_abilities(description.type)
    end

    private

    def add_abilities(type)
      case type
      when :referenced
        extend(ReferencedAbilities)
      when :indirect
        extend(IndirectAbilities)
      when :sorted
        extend(SortedAbilities)
      end
    end

    def key
      accessor.key
    end

    def collection_key
      index_key(description.model, description.attribute)[model.uid]
    end

    module ReferencedAbilities
      def count
        accessor.with_lock { collection_key.scard }
      end

      def uids
        accessor.with_lock { collection_key.smembers }
      end

      def all
        uids.map { |uid| accessor.read(description.model, uid) }
      end
    end

    module IndirectAbilities
      def count
        uids.length
      end

      def uids
        accessor.with_lock {
          collection_key.sort(
            by: "nosort",
            get: reference_keys(description.model, description.target_attribute)
          )
        }
      end

      def all
        uids.map { |uid| accessor.read(description.target, uid) }
      end
    end

    module SortedAbilities
      def uids
        accessor.with_lock {
          reference = description.reference
          the_key = sorted_key(reference.model, model.uid, description.attribute)
          the_key.zrange(0, -1)
        }
      end

      def all
        uids.map { |uid| accessor.read(description.model, uid) }
      end
    end
  end
end
