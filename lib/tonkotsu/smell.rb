require "tonkotsu"

module Tonkotsu
  module Smell
    # TODO: implement Refinement to introduce "defer" into Kernel
    refine Kernel do
      def defer(&block)
        # ...
      end
    end
  end
end
