require "tonkotsu"

module Tonkotsu
  module Smell
    refine Kernel do
      include Tonkotsu::Impl
    end
  end
end
