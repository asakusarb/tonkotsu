module Tonkotsu
  class StackFrame
    attr_reader :type, :id

    def initialize(type)
      @type = type
      @deferreds = []
    end

    def root?
      @type == :root
    end

    def add(deferred_fiber)
      @deferreds << deferred_fiber
    end

    def release!
      return if @deferreds.empty?
      @deferreds.reverse.each do |d|
        d.resume rescue nil
      end
      nil
    end

    def to_s
      "S[#{@type}]"
    end
  end
end
