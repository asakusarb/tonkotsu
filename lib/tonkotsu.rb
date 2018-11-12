require "tonkotsu/version"

begin
  RubyVM::AST.of(->(){ }) # TODO: update AST -> AbstractSyntaxTree
rescue
  raise NotImplementedError, "Use Ruby 2.6 or later"
end

module Tonkotsu
  module Impl
    NODE = Struct.new(:receiver, :method_name)

    def self.dig_find_first_method_call_with_receiver(node)
      return nil unless node.is_a?(RubyVM::AST::Node)

      if node.type == "NODE_CALL" && node.children[0].is_a?(RubyVM::AST::Node) && node.children[0].type == "NODE_DVAR"
        return NODE.new(node.children[0].children[0], node.children[1])
      end

      node.children.each do |n|
        r = dig_find_first_method_call_with_receiver(n)
        return r if r
      end

      nil
    end

    def self.find_first_method_call_with_receiver(node)
      if node.is_a?(Proc) || node.is_a?(Method)
        return dig_find_first_method_call_with_receiver(RubyVM::AST.of(node))
      end
      nil
    end

    def defer(&block_or_method)
      # TODO: struct virtual stack frame and hook the end of stack using TracePoint

      closer = Tonkotsu::Impl.find_first_method_call_with_receiver(block_or_method)
      receiver = block_or_method.binding.local_variable_get(closer.receiver)
      mod = Module.new
      mod.define_method(closer.method_name) do |*args, **kwargs|
        Fiber.yield
        super(*args, **kwargs)
      end
      receiver.singleton_class.prepend(mod)
      fiber = Fiber.new do
        block_or_method.call
      end
      fiber.resume
      fiber
    end
  end

  def defer(&block)
    Tonkotsu::Impl.defer(&block)
  end
end
