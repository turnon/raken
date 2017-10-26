require "raken/version"
require "rake"
require "trace_tree"
require "json"
require "pry"

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
        ],
        ['--pry [csnfe]',
         'invoke pry-byebug before task. `csnf` to enable stepping alias and `e` to repeat last command by hitting Enter',
         lambda { |value|
           options.pry_debug = true
           pry_debug_alias value
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

    def pry_debug_alias opt
      return unless opt
      {c: 'continue', s: 'step', n: 'next', f: 'finish'}.each_pair do |ali, cmd|
        Pry.commands.alias_command(ali, cmd) if opt.include?(ali.to_s)
      end
      Pry::Commands.command /^$/, "repeat last command" do
          _pry_.run_command Pry.history.to_a.last
      end if opt.include?('e')
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
          elsif ARGV.include?(name) && application.options.pry_debug
            binding.pry
            blk.call *params
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
