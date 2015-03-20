# The MIT License (MIT)
#
# Copyright (c) 2014-2015 David Gamba
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class GetOptions
  # argument_specification:
  # [ '',
  #   '!',
  #   '+',
  #   '= type [destype] [repeat]',
  #   ': number [destype]',
  #   ': + [destype]'
  #   ': type [destype]',
  # ]
  # type: [ 's', 'i', 'o', 'f']
  # destype: ['@', '%']
  # repeat: { [ min ] [ , [ max ] ] }

  # External method, this is the main interface
  def self.parse(args, option_map = {}, options = {})
    @options = options
    set_initial_values()
    set_logging()
    info "input args: '#{args}'"
    info "input option_map: '#{option_map}'"
    info "input options: '#{options}'"
    @option_map = generate_extended_option_map(option_map)
    option_result, remaining_args = process_arguments(args, {}, [])
    debug "option_result: '#{option_result}', remaining_args: '#{remaining_args}'"
    @log = nil
    [option_result, remaining_args]
  end

private
    def self.set_initial_values()
      # Regex definitions
      @end_processing_regex = /^--$/
      @type_regex           = /[siof]/
      @desttype_regex       = /[@%]/
      @repeat_regex         = /\{\d+(?:,\s?\d+)?\}/
      @valid_simbols        = '=:+!'
      @is_option_regex      = /^--?[^\d]/

      # Instance variables
      @option_map = {}
      @level = 2
    end

    def self.info(msg)
      STDERR.puts "INFO  |" + msg if @level <= 1
    end

    def self.debug(msg)
      STDERR.puts "DEBUG |" + msg if @level <= 0
    end

    def self.set_logging()
      case @options[:debug]
      when true
        @level = 0
      when 'debug'
        @level = 0
      when 'info'
        @level = 1
      else
        @level = 2
      end
    end

    def self.generate_extended_option_map(option_map)
      opt_map = {}
      unique_options = []
      option_map.each_pair do |k, v|
        if k.match(/^[=:+!]/)
          fail ArgumentError,
              "GetOptions option_map missing name in definition: '#{k}'"
        end
        definitions = k.match(/^([^#{@valid_simbols}]+)[#{@valid_simbols}]?(.*?)$/)[1].split('|')
        unique_options.push(*definitions)
        arg_spec, *arg_opts = process_type(k.match(/^[^#{@valid_simbols}]+([#{@valid_simbols}]?(.*?))$/)[1])
        opt_map[definitions] = { :arg_spec => arg_spec, :arg_opts => arg_opts, :opt_dest => v }
      end
      unless unique_options.uniq.length == unique_options.length
        duplicate_elements = unique_options.find { |e| unique_options.count(e) > 1 }
        fail ArgumentError,
            "GetOptions option_map needs to have unique options: '#{duplicate_elements}'"
      end
      debug "opt_map: #{opt_map}"
      opt_map
    end

    def self.process_type(type_str)
      # argument_specification:
      # [ '',
      #   '!',
      #   '+',
      #   '= type [destype] [repeat]',
      #   ': number [destype]',
      #   ': + [destype]'
      #   ': type [destype]',
      # ]
      # type: [ 's', 'i', 'o', 'f']
      # destype: ['@', '%']
      # repeat: { [ min ] [ , [ max ] ] }

      # flag: ''
      if type_str.match(/^$/)
        ['flag']
      # negatable flag: '!'
      elsif type_str.match(/^!$/)
        ['nflag']
      # incremental int: '+'
      elsif type_str.match(/^\+$/)
        ['increment']
      # required: '= type [destype] [repeat]'
      elsif (matches = type_str.match(/^=(#{@type_regex})(#{@desttype_regex}?)(#{@repeat_regex}?)$/))
        ['required', matches[1], matches[2], matches[3]]
      # optional with default: ': number [destype]'
      elsif (matches = type_str.match(/^:(\d+)(#{@desttype_regex}?)$/))
        ['optional_with_default', matches[1], matches[2]]
      # optional with increment: ': + [destype]'
      elsif (matches = type_str.match(/^:(\+)(#{@desttype_regex}?)$/))
        ['optional_with_increment', matches[1], matches[2]]
      # optional: ': type [destype]'
      elsif (matches = type_str.match(/^:(#{@type_regex})(#{@desttype_regex}?)$/))
        ['optional', matches[1], matches[2]]
      else
        fail ArgumentError, "Unknown option type: '#{type_str}'!"
      end
    end

    def self.process_arguments(args, option_result, remaining_args)
      if args.size > 0
        arg = args.shift
        if arg.match(@end_processing_regex)
          remaining_args.push(*args)
          return option_result, remaining_args
        elsif option? arg
          option_result, args, remaining_args = process_option(arg, option_result, args, remaining_args)
          option_result, remaining_args = process_arguments(args, option_result, remaining_args)
        else
          remaining_args.push arg
          option_result, remaining_args = process_arguments(args, option_result, remaining_args)
        end
      end
      return option_result, remaining_args
    end

    def self.process_option(orig_opt, option_result, args, remaining_args)
      opt = orig_opt.gsub(/^-+/, '')
      # Check if option has a value defined with an equal sign
      if (matches = opt.match(/^([^=]+)=(.*)$/))
        opt = matches[1]
        arg = matches[2]
      end
      # Make it obvious that find_option_matches is updating the instance variable
      opt_match, @option_map = find_option_matches(opt)
      if opt_match.nil?
        remaining_args.push orig_opt
        return option_result, args, remaining_args
      end
      args.unshift arg unless arg.nil?
      debug "new args: #{args}"
      option_result, args = execute_option(opt_match, option_result, args)
      debug "option_result: #{option_result}"
      return option_result, args, remaining_args
    end

    def self.find_option_matches(opt)
      matches = []
      @option_map.each_pair do |k, v|
        local_matches = []
        k.map { |name| local_matches.push name if name.match(/^#{opt}$/) }
        if v[:arg_spec] == 'nflag'
          k.map do |name|
            if opt.match(/^no-?/) && name.match(/^#{opt.gsub(/no-?/, '')}$/)
              # Update the instance variable
              @option_map[k][:negated] = true
              local_matches.push name
            end
          end
        end
        matches.push(k) if local_matches.size > 0
      end
      # FIXME: Too much repetition.
      # If the strict match returns no results, lets be more permisive.
      if matches.size == 0
        @option_map.each_pair do |k, v|
          local_matches = []
          k.map { |name| local_matches.push name if name.match(/^#{opt}/) }
          if v[:arg_spec] == 'nflag'
            k.map do |name|
              if opt.match(/^no-?/) && name.match(/^#{opt.gsub(/^no-?/, '')}/)
                # Update the instance variable
                @option_map[k][:negated] = true
                local_matches.push name
              end
            end
          end
          matches.push(k) if local_matches.size > 0
        end
      end

      if matches.size == 0
        if @options[:fail_on_unknown]
          abort "[ERROR] Option '#{opt}' not found!"
        else
          debug "Option '#{opt}' not found!"
          $stderr.puts "[WARNING] Option '#{opt}' not found!" unless @options[:pass_through]
          return [nil, @option_map]
        end
      elsif matches.size > 1
        abort "[ERROR] option '#{opt}' matches multiple names '#{matches.inspect}'!"
      end
      debug "matches: #{matches}"
      [matches[0], @option_map]
    end

    def self.execute_option(opt_match, option_result, args)
      opt_def = @option_map[opt_match]
      debug "#{opt_def[:arg_spec]}"
      case opt_def[:arg_spec]
      when 'flag'
        if opt_def[:opt_dest].kind_of? Symbol
          option_result[opt_def[:opt_dest]] = true
        else
          debug "Flag definition is a function"
          opt_def[:opt_dest].call
        end
      when 'nflag'
        if opt_def[:negated]
          option_result[opt_def[:opt_dest]] = false
        else
          option_result[opt_def[:opt_dest]] = true
        end
      when 'increment'
        # TODO
        abort "[ERROR] Unimplemented option definition 'increment'"
      when 'required'
        option_result, args = process_desttype(option_result, args, opt_match, false)
      when 'optional_with_default'
        # TODO
        abort "[ERROR] Unimplemented option definition 'optional_with_default'"
      when 'optional_with_increment'
        # TODO
        abort "[ERROR] Unimplemented option definition 'optional_with_increment'"
      when 'optional'
        option_result, args = process_desttype(option_result, args, opt_match, true)
      end
      [option_result, args]
    end

    def self.process_option_type(arg, opt_match, optional = false)
      case @option_map[opt_match][:arg_opts][0]
      when 's'
        arg = '' if optional && arg.nil?
      when 'i'
        arg = 0 if optional && arg.nil?
        unless integer?(arg)
          abort "[ERROR] argument for option '#{opt_match[0]}' is not of type 'Integer'!"
        end
        arg = arg.to_i
      when 'f'
        arg = 0 if optional && arg.nil?
        unless numeric?(arg)
          abort "[ERROR] argument for option '#{opt_match[0]}' is not of type 'Float'!"
        end
        arg = arg.to_f
      when 'o'
        # FIXME
        abort "[ERROR] Unimplemented type 'o'!"
      end
      return arg
    end

    def self.process_desttype(option_result, args, opt_match, optional = false)
      opt_def = @option_map[opt_match]
      case opt_def[:arg_opts][1]
      when '@'
        unless option_result[opt_def[:opt_dest]].kind_of? Array
          option_result[opt_def[:opt_dest]] = []
        end
        # check for repeat specifier {min, max}
        if (matches = opt_def[:arg_opts][2].match(/\{(\d+)(?:,\s?(\d+))?\}/))
          min = matches[1].to_i
          max = matches[2]
          max = min if max.nil?
          max = max.to_i
          if min > max
            fail ArgumentError, "GetOptions repeat, max '#{max}' <= min '#{min}'"
          end
          while min > 0
            debug "min: #{min}, max: #{max}"
            min -= 1
            max -= 1
            abort "[ERROR] missing argument for option '#{opt_match[0]}'!" if args.size <= 0
            args, arg = process_desttype_arg(args, opt_match, optional)
            option_result[opt_def[:opt_dest]].push arg
          end
          while max > 0
            debug "min: #{min}, max: #{max}"
            max -= 1
            break if args.size <= 0
            args, arg = process_desttype_arg(args, opt_match, optional, true)
            break if arg.nil?
            option_result[opt_def[:opt_dest]].push arg
          end
        else
          args, arg = process_desttype_arg(args, opt_match, optional)
          option_result[opt_def[:opt_dest]].push arg
        end
      when '%'
        unless option_result[opt_def[:opt_dest]].kind_of? Hash
          option_result[opt_def[:opt_dest]] = {}
        end
        # check for repeat specifier {min, max}
        if (matches = opt_def[:arg_opts][2].match(/\{(\d+)(?:,\s?(\d+))?\}/))
          min = matches[1].to_i
          max = matches[2]
          max = min if max.nil?
          max = max.to_i
          if min > max
            fail ArgumentError, "GetOptions repeat, max '#{max}' <= min '#{min}'"
          end
          while min > 0
            debug "min: #{min}, max: #{max}"
            min -= 1
            max -= 1
            abort "[ERROR] missing argument for option '#{opt_match[0]}'!" if args.size <= 0
            args, arg, key = process_desttype_hash_arg(args, opt_match, optional)
            option_result[opt_def[:opt_dest]][key] = arg
          end
          while max > 0
            debug "min: #{min}, max: #{max}"
            max -= 1
            break if args.size <= 0
            break if option?(args[0])
            args, arg, key = process_desttype_hash_arg(args, opt_match, optional)
            option_result[opt_def[:opt_dest]][key] = arg
          end
        else
          args, arg, key = process_desttype_hash_arg(args, opt_match, optional)
          option_result[opt_def[:opt_dest]][key] = arg
        end
      else
        args, arg = process_desttype_arg(args, opt_match, optional)
        option_result[opt_def[:opt_dest]] = arg
      end
      [option_result, args]
    end

    def self.process_desttype_arg(args, opt_match, optional, required = false)
      if !args[0].nil? && option?(args[0])
        debug "args[0] option"
        if required
          return args, nil
        end
        arg = process_option_type(nil, opt_match, optional)
      else
        arg = process_option_type(args.shift, opt_match, optional)
      end
      debug "arg: '#{arg}'"
      if arg.nil?
        debug "arg is nil"
        abort "[ERROR] missing argument for option '#{opt_match[0]}'!"
      end
      [args, arg]
    end

    def self.process_desttype_hash_arg(args, opt_match, optional)
      if args[0].nil? || (!args[0].nil? && option?(args[0]))
        abort "[ERROR] missing argument for option '#{opt_match[0]}'!"
      end
      input = args.shift
      if (matches = input.match(/^([^=]+)=(.*)$/))
        key = matches[1]
        arg = matches[2]
      else
        abort "[ERROR] argument for option '#{opt_match[0]}' must be of type key=value!"
      end
      debug "key: '#{key}', arg: '#{arg}'"
      arg = process_option_type(arg, opt_match, optional)
      debug "arg: '#{arg}'"
      if arg.nil?
        debug "arg is nil"
        abort "[ERROR] missing argument for option '#{opt_match[0]}'!"
      end
      [args, arg, key]
    end

    def self.integer?(obj)
      obj.to_s.match(/\A[+-]?\d+?\Z/) == nil ? false : true
    end

    def self.numeric?(obj)
      obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
    end

    def self.option?(arg)
      result = !!(arg.match(@is_option_regex))
      debug "Is option? '#{arg}' #{result}"
      result
    end
end
