require "tonkotsu/version"
require "tonkotsu/stack_frame"

begin
  RubyVM::AST.of(->(){ }) # TODO: update AST -> AbstractSyntaxTree
rescue
  raise NotImplementedError, "Use Ruby 2.6 or later"
end

module Tonkotsu
  module Impl
    module Backend
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

      def self.setup_barrier_fiber(block_or_method)
        closer = find_first_method_call_with_receiver(block_or_method)
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

    def defer(&block_or_method)
      raise ArgumentError, "deferred block is not specified" unless block_or_method

      fiber = Tonkotsu::Impl::Backend.setup_barrier_fiber(block_or_method)

      store = (Thread.current[:tonkotsu_store] ||= {})
      if !store.empty? && !store[:stack].empty?
        store[:stack].last.add(fiber)
        return
      end

      stack = store[:stack] = [Tonkotsu::StackFrame.new(:root)] # the first occurring of "defer"
      first_return = true
      stack_under_defer = false
      calling_release = false

      trace = TracePoint.new(:call, :return, :b_call, :b_return) do |tp|
        next if tp.defined_class.is_a?(Class) && tp.defined_class.to_s == "#<Class:Tonkotsu::Impl::Backend>"
        next if tp.defined_class == Tonkotsu::StackFrame
        if first_return && tp.event == :return && tp.defined_class == Tonkotsu::Impl && tp.method_id == :defer
          # not to invoke unexpected things to return from this method
          first_return = false
          next
        end

        case tp.event
        when :call, :b_call
          # not to make more stacks in deferred block
          next if stack_under_defer || calling_release
          if tp.defined_class == Tonkotsu::Impl && tp.method_id == :defer
            stack_under_defer = true
            next
          end

          stack << Tonkotsu::StackFrame.new(tp.event)

        when :return, :b_return
          if stack_under_defer && tp.defined_class == Tonkotsu::Impl && tp.method_id == :defer
            # exiting from deferred block
            stack_under_defer = false
            next
          end
          next if stack_under_defer || calling_release # nothing invoked in deferred block

          # invoke deferred blocks registered in returning context
          frame = stack.pop
          calling_release = true
          frame.release!
          calling_release = false

          if stack.empty?
            trace.disable
          end
        end
      end # TracePoint.new

      stack.last.add(fiber)
      trace.enable
      nil
    end
  end

  extend Impl
end
