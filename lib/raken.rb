require "raken/version"
require "rake"
require "trace_tree"

module Rake
  class Task
    alias_method :_enhance, :enhance

    def enhance *args, &blk
      if block_given?
        _enhance *args do |*params|
          if ARGV.include? name
            binding.trace_tree do
              blk.call *params
            end
          else
            blk.call *params
          end
        end
      else
        _enhance *args
      end
    end
  end
end
