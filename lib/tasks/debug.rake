# frozen_string_literal: true

require_relative '../memory_debug'

# https://samsaffron.com/archive/2015/03/31/debugging-memory-leaks-in-ruby
# sudo sysctl kernel.msgmnb=1048576

desc 'Debugging'
namespace :debug do
  desc 'Current memory usage of process'
  task :mem, [:pid] do |_t, args|
    require 'get_process_mem'
    mem = GetProcessMem.new(args.pid)
    # rss_bytes = `ps -f -p #{Process.pid} --no-headers -o rss`.to_i * 1024
    STDOUT.puts "PID: #{args.pid}\nMEMORY: #{mem.mb.round(4)} MB"
  end

  desc 'Save GC.stat of process to file'
  task :gc_stat_save, [:pid, :filepath] do |_t, args|
    filepath = File.absolute_path(args.filepath)
    code = <<-RUBY
      Thread.new do
        require 'json'
        File.open('#{filepath}', 'w') do |f| 
          f.write JSON.pretty_generate(GC.stat)
        end
      end
    RUBY
    Tracer.call(args.pid) do |tracer|
      res = tracer.eval(code)
      tracer.puts 'success' if res
      # tracer.puts ">> #{code}"
      # tracer.puts "=> #{res}"
    end
  end

  desc 'Print GC.stat of process'
  task :gc_stat, [:pid] do |_t, args|
    Tracer.call(args.pid) do |tracer|
      res = tracer.eval 'JSON.pretty_generate(GC.stat)'
      tracer.puts res
      tracer.puts 'failed' unless res
    end
  end

  desc 'Dump object space of process to file'
  task :dump, [:pid, :filepath] do |_t, args|
    filepath = File.absolute_path(args.filepath)
    code = <<-RUBY
      Thread.new do
        GC.start
        require 'objspace'
        File.open('#{filepath}', 'w') { |f| ObjectSpace.dump_all(output: f) }
      end
    RUBY
    Tracer.call(args.pid) do |tracer|
      res = tracer.eval(code)
      tracer.puts 'success' if res
    end
  end

  desc 'Analyze dump'
  namespace :analyze do

    desc 'Save how many objects was allocated on GC generation and still active'
    task :generation, [:dump_filepath, :output_filepath] do |_t, args|
      MemoryDebug::Analyzer.call(
          args.dump_filepath,
          :generation,
          args.output_filepath
      )
    end

    desc 'Save how many objects wass allocated per file:line for particular generation'
    task :obj_per_line, [:dump_filepath, :output_filepath, :generation] do |_t, args|
      MemoryDebug::Analyzer.call(
          args.dump_filepath,
          :obj_per_line,
          args.output_filepath,
          args.generation
      )
    end

  end
end
