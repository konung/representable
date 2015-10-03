
module Representable
  # serialize -> serialize! -> marshal. # TODO: same flow in deserialize.
  class Serializer
    def initialize(binding)
      @binding = binding
    end
    def call(object, &block)
      return object if object.nil? # DISCUSS: move to Object#serialize ?

      serialize(object, @binding.user_options, &block)
    end

  private
    def serialize(object, user_options, &block)
      return yield if @binding.evaluate_option(:skip_render, object) # this will jump out of #render_fragment. introduce Skip object here.

      serialize!(object, user_options)
    end

    # Serialize one object by calling to_json etc. on it.
    def serialize!(object, user_options)
      object = Prepare.(result: object, binding: @binding)

      return object unless @binding.representable?

      @binding.evaluate_option(:serialize, object) do
        marshal(object, user_options)
      end
    end

    #   0.33      0.004     0.004     0.000     0.000    20001   Hash#merge!
    #   0.00      0.000     0.000     0.000     0.000        1   Hash#merge!
    def marshal(object, user_options)
      object.send(@binding.serialize_method, user_options)
    end


    class Collection < self
      def serialize(array, *args)
        collection = [] # TODO: unify with Deserializer::Collection.

        array.each do |item|
          next if @binding.evaluate_option(:skip_render, item) # TODO: allow skipping entire collections? same for deserialize.

          collection << serialize!(item, *args)
        end # TODO: i don't want Array but Forms here - what now?

        collection
      end
    end


    class Hash < self
      def serialize(hash, *args)
        {}.tap do |hsh|
          hash.each { |key, obj| hsh[key] = super(obj, *args) }
        end
      end
    end
  end
end