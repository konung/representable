require 'representable/binding'
require 'representable/hash/binding.rb'

module Representable
  module XML
    module_function
    class Binding < Representable::Binding
      def self.build_for(definition)
        return Collection.new(definition)      if definition.array?
        return Hash.new(definition)            if definition.hash? and not definition[:use_attributes] # FIXME: hate this.
        return AttributeHash.new(definition)   if definition.hash? and definition[:use_attributes]
        return Attribute.new(definition)       if definition[:attribute]
        return Content.new(definition)         if definition[:content]
        new(definition)
      end

      def write(parent, fragments, as)
        wrap_node = parent

        # if wrap = self[:wrap]
        #   parent << wrap_node = XML::Node(parent, wrap)
        # end

        XML::Append(
          wrap_node,
          serialize_node(fragments, parent, as)
        )
      end

      # For parsing, we use the Oga gem.
      def read(node, options)
        nodes = find_nodes(node, options)
        return FragmentNotFound if nodes.size == 0 # TODO: write dedicated test!

        content_for(nodes, options)
      end


      def serialize_node(value, parent, as)
        return value if typed?
        #   value.name = as if as != self[:name]
        XML::Node(as, {}, value) # <name>Rancid</name>
      end

      # DISCUSS: why is this public?
      def serialize_method
        :to_node
      end

      def deserialize_method
        :from_node
      end

    private
      def find_nodes(node, options:, as:, **)
        selector  = as

        node.xpath(selector)
      end

      def content_for(nodes, options) # TODO: move this into a ScalarDecorator.
        node = nodes.first

        return node if typed? # <logo ..>
        scalar_content(node, options)
      end

      def scalar_content(node, options) # FIXME.
        node.text
      end


      class Collection < Binding
        def content_for(nodes, options)
          nodes.collect { |node| super([node], options) } # FIXME, super sucks.
        end

        def write(parent, nodes, as) # FIXME!
          wrap_node = parent

          if wrap = self[:wrap]
            parent << wrap_node = XML::Node(parent, wrap)
          end




          nodes.each { |node|

            XML::Append(
              wrap_node,
              serialize_node(node, parent, as)
            )

           }
        end
      end


      class Hash < Collection
        def serialize_for(value, parent, as)
          set_for(parent, value.collect do |k, v|
            node = XML::_Node(parent, k)
            serialize_node(node, v, as)
          end)
        end

        def deserialize_from(nodes)
          hash = {}
          nodes.children.each do |node|
            hash[node.name] = content_for node
          end

          hash
        end
      end

      class AttributeHash < Collection
        # DISCUSS: use AttributeBinding here?
        def write(parent, value, as)  # DISCUSS: is it correct overriding #write here?
          value.collect do |k, v|
            parent[k] = v.to_s
          end
          parent
        end

        # FIXME: this is not tested!
        def deserialize_from(node)
          HashDeserializer.new(self).deserialize(node)
        end
      end


      # Binding for an attribute: `<.. id="1">`
      class Attribute < Binding
        def read(node, as:, **)
          node.get(as)
        end

        def write(parent, value, as)
          XML::Merge(parent, as => value)
        end
      end

      # Represents tag content.
      class Content < self
        def read(node, as)
          node.content
        end

        def serialize_for(value, parent)
          parent.content = value.to_s
        end

        def write(parent, value, as)
          serialize_for(value, parent)
        end
      end
    end # Binding
  end
end
