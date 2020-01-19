# frozen_string_literal: true

module MemoryDebug
  class Tracer
    def self.call(pid, &block)
      new(pid).call(&block)
    end

    def initialize(pid)
      @pid = pid
      @tracer = nil
    end

    def call
      raise ArgumentError, 'block required' unless block_given?

      require 'rbtrace'
      require 'rbtrace/rbtracer'

      @tracer = RBTracer.new(@pid)
      yield @tracer
    ensure
      @tracer&.detach
      @tracer = nil
    end
  end

  class Analyzer
    def self.call(filepath, command, *args)
      new(filepath).call(command, *args)
    end

    def initialize(filepath)
      @filepath = filepath
    end

    def call(command, *args)
      send("analyze_#{command}", *args)
    end

    private

    def analyze_generation(output_filename)
      filepath = "#{output_filename}.generation.txt"
      data = get_data
      grouped = data.group_by{ |row| row['generation'] }.sort_by { |a| a[0].to_i }

      File.open(filepath, 'w') do |f|
        grouped.each do |k, v|
          f.write "generation #{k} objects #{v.count}\n"
        end
      end
      log "MEMORY ANALYZED BY GENERATION at #{filepath}"
    end

    def analyze_obj_per_line(output_filename, gen = nil)
      gen = gen.presence
      gen = gen.to_i if gen
      filepath = "#{output_filename}.gen_classes.#{gen || 'nil'}.txt"
      data = get_data { |r| r['generation'] == gen }
      grouped = data.group_by { |row| "#{row['file']}:#{row['line']}" }.sort_by { |a| a[1].count }

      File.open(filepath, 'w') do |f|
        f.write "generation #{gen} objects #{data.count}\n\n"
        grouped.each do |k,v|
          f.write "#{k} * #{v.count}\n"
        end
      end

      log "MEMORY ANALYZED OBJ_PER_LINE for generation #{gen || 'nil'} at #{filepath}"
    end

    def log(msg)
      STDOUT.puts "[#{Time.now.to_s(:db)}] #{msg}"
    end
  end
end
