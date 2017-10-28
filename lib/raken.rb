require "raken/version"
require "rake"
require "trace_tree"
require "json"
require "pry"

module Rake
  class Application
    alias_method :_standard_rake_options, :standard_rake_options
    alias_method :_run, :run

    def standard_rake_options
      [
        ['--time [all]',
         'time tasks',
         lambda { |value|
           options.time = value || true
         }
        ],
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

    def run
      _run
    ensure
      tasks.each do |t|
        next unless t.beginning
        puts "#{t.name} #{t.beginning} -> #{t.ending} = #{t.duration}"
      end if options.time
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
    attr_reader :beginning, :ending

    def enhance *args, &blk
      if block_given?
        _enhance *args do |*params|
          apply_task_body blk, *params
        end
      else
        _enhance *args
      end
    end

    def apply_task_body blk, *params
      if application.options.time &&
          (application.options.time == 'all' || ARGV.include?(name))
        org_blk = blk
        blk = lambda { |*args|
          begin
            @beginning = Time.now
            org_blk.call *args
          ensure
            @ending = Time.now
          end
        }
      end

      return blk.call *params unless ARGV.include?(name)

      if application.options.trace_tree
        binding.trace_tree(**application.options.trace_tree) do
          blk.call *params
        end
      elsif application.options.pry_debug
        binding.pry
        blk.call *params
      else
        blk.call *params
      end
    end

    def duration
      @ending - @beginning
    end

  end
end
