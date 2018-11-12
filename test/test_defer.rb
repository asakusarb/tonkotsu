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

  # TODO: fix test case name
  # test 'toplevel defer works as expected' do
  #   buffer = String.new
  #   a = Underlying.new("a", buffer)
  #   b = Underlying.new("b", buffer)
  #   c = Underlying.new("c", buffer)
  #   Consumer.new.yay(buffer, a, b, c)

  #   assert_equal "c2;y2;x1;b0;a0;"
  # end

  test 'trying raw defer' do
    b = String.new
    u0 = Underlying.new("v", b)
    f = defer { u0.close(1 + 2) }
    assert_equal "", b
    f.resume
    assert_equal "v3;", b
  end
end

