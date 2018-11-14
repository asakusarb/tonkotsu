require "test/unit"
require "tonkotsu/smell"

using Tonkotsu::Smell

class DeferTest < ::Test::Unit::TestCase
  class Underlying
    def initialize(arg_name, buffer)
      @arg_name = arg_name
      @buffer = buffer      
    end

    def close(num)
      @buffer << "#{@arg_name}#{num};"
    end
  end

  class Consumer
    def yay(buffer, a, b, c)
      close_arg = "0"
      defer{ a.close(close_arg) }
      defer{ b.close(close_arg) }
      a = Underlying.new("x", buffer)
      close_arg = "1"
      defer{ a.close(close_arg) }
      b = Underlying.new("y", buffer)
      close_arg = "2"
      defer{ b.close(close_arg) }
      defer{ c.close(close_arg) }
      # c2;y2;x1;b0;a0;
      nil
    end
  end

  test 'defer works with blocks' do
    s = String.new
    b = ->(){
      u = Underlying.new("a", s)
      defer { u.close("0") }
      1.times do |i|
        u1 = Underlying.new("b", s)
        defer { u1.close(i.to_s) }
      end
    }
    b.call
    assert_equal "b0;a0;", s
  end

  test 'defer works with methods' do
    buffer = String.new
    a = Underlying.new("a", buffer)
    b = Underlying.new("b", buffer)
    c = Underlying.new("c", buffer)
    Consumer.new.yay(buffer, a, b, c)

    assert_equal "c2;y2;x1;b0;a0;", buffer
  end

  test 'defer works well even when #close raises exception' do
    s = String.new
    b = ->(){
      u = Underlying.new("a", s)
      defer { u.close("0") }
      1.times do |i|
        u1 = Underlying.new("b", s)
        u1.singleton_class.define_method(:close) do |*args|
          raise "exception"
        end
        defer { u1.close(i.to_s) }
      end
    }
    b.call
    assert_equal "a0;", s
  end
end

