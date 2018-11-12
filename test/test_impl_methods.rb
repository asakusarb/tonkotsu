require "test/unit"
require "tonkotsu"

class DeferImplTest < ::Test::Unit::TestCase
  def test_find_first_method_call_with_receiver
    t = Tonkotsu::Impl
    assert_nil t.find_first_method_call_with_receiver(->(){ })
    assert_nil t.find_first_method_call_with_receiver(->(){ p "yay" })
    assert_nil t.find_first_method_call_with_receiver(->(){ say("hello") })
    assert_nil t.find_first_method_call_with_receiver(->(){ p("yay"); say("hello") })
    assert_nil t.find_first_method_call_with_receiver(->(){ 1 + 1 })
    assert_nil t.find_first_method_call_with_receiver(->(){ "yay".upcase; 1.to_s })
    assert_nil t.find_first_method_call_with_receiver(->(){ a.to_s })

    b = "1"
    r = t.find_first_method_call_with_receiver(->(){ b.to_s })
    assert_not_nil r
    assert_equal :b, r.receiver
    assert_equal :to_s, r.method_name

    c = 1
    r = t.find_first_method_call_with_receiver(->(){ c.to_i ; b.to_s })
    assert_not_nil r
    assert_equal :c, r.receiver
    assert_equal :to_i, r.method_name

    d = "0"
    d.define_singleton_method(:add) do |arg|
      d.sub!(/\z/, arg)
    end
    r = t.find_first_method_call_with_receiver(->(){ d.add("1" + "2") })
    assert_not_nil r
    assert_equal :d, r.receiver
    assert_equal :add, r.method_name
  end
end
