require "raken/version"
require "rake"
require "trace_tree"
require "json"

module Rake
  class Application
    alias_method :_standard_rake_options, :standard_rake_options

    def standard_rake_options
      [
        ['--trace-tree OPTS',
         'https://github.com/turnon/trace_tree',
         lambda { |value|
           options.trace_tree = keyworded(value)
         }
        ]
      ] + _standard_rake_options
    end

    def keyworded opt
      JSON.parse('{' + opt.gsub(/(\w+):/, '"\1":') + '}').tap do |hash|
        hash.keys.each do |k|
          v = hash.delete(k)
          hash[k.to_sym] = v
        end
      end
    rescue
      raise ArgumentError, "->#{opt}<- is not ruby keyword argument"
    end
  end

  class Task
    alias_method :_enhance, :enhance

    def enhance *args, &blk
      if block_given?
        _enhance *args do |*params|
          if ARGV.include?(name) && application.options.trace_tree
            binding.trace_tree(**application.options.trace_tree) do
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
