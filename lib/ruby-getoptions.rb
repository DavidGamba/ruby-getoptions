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
    option_result, remaining_args = iterate_over_arguments(args, options[:mode])
    debug "option_result: '#{option_result}', remaining_args: '#{remaining_args}'"
    @log = nil
    [option_result, remaining_args]
  end

private

# This is how the instance variable @option_map looks like:
# @option_map:
# {
#   ["opt", "alias"] => {
#     :arg_spec=>"nflag",
#     :arg_opts=>["b", nil, nil],
#     :opt_dest=>:flag3,
#     :negated=> true
#   }
# }

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

    # Given an option definition, it extracts the aliases and puts them into an array.
    #
    # @: definition
    # return: [aliases, ...]
    def self.extract_spec_and_aliases(definition)
      m = definition.match(/^([^#{@valid_simbols}]+)([#{@valid_simbols}]?.*?)$/)
      return m[2], m[1].split('|')
    end

    def self.generate_extended_option_map(option_map)
      opt_map = {}
      definition_list = []
      option_map.each_pair do |k, v|
        if k.match(/^[=:+!]/)
          fail ArgumentError,
              "GetOptions option_map missing name in definition: '#{k}'"
        end
        opt_spec, definitions = extract_spec_and_aliases(k)
        arg_spec, *arg_opts = process_opt_spec(opt_spec)
        opt_map[definitions] = { :arg_spec => arg_spec, :arg_opts => arg_opts, :opt_dest => v }

        definition_list.push(*definitions)
      end
      fail_on_duplicate_definitions(definition_list)
      debug "opt_map: #{opt_map}"
      opt_map
    end

    def self.fail_on_duplicate_definitions(definition_list)
      definition_list.map!{ |x| x.downcase }
      unless definition_list.uniq.length == definition_list.length
        duplicate_elements = definition_list.find { |e| definition_list.count(e) > 1 }
        fail ArgumentError,
            "GetOptions option_map needs to have unique case insensitive options: '#{duplicate_elements}'"
      end
      true
    end


    # Checks an option specification string and returns an array with
    # argument_spec, type, destype and repeat.
    #
    # The Option Specification provides a nice, compact interface. This method
    # extracts the different parts from that.
    #
    # @: type definition
    # return arg_spec, type, destype, repeat
    def self.process_opt_spec(opt_spec)
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

      # Handle special cases
      case opt_spec
      when ''
        return 'flag', 'b', nil, nil
      when '!'
        return 'nflag', 'b', nil, nil
      when '+'
        return 'increment', 'i', nil, nil
      end

      opt_spec_regex = /^([=:])([siof])([@%]?)((?:\{[^}]+\})?)$/
      arg_spec = String.new
      type     = nil
      desttype = nil
      repeat   = nil

      matches = opt_spec.match(opt_spec_regex)
      if matches.nil?
        fail ArgumentError, "Wrong option specification: '#{opt_spec}'!"
      end
      case matches[1]
      when '='
        arg_spec = 'required'
      when ':'
        arg_spec = 'optional'
      end
      type = matches[2]
      if matches[3] != ''
        desttype = matches[3]
      end
      if matches[4] != ''
        r_matches = matches[4].match(/\{(\d+)?(?:,\s?(\d+)?)?\}/)
        min = r_matches[1]
        min ||= 1
        min = min.to_i
        max = r_matches[2]
        max = min if max.nil?
        max = max.to_i
        if min > max
          fail ArgumentError, "GetOptions repeat, max '#{max}' <= min '#{min}'"
        end
        repeat = [min, max]
      end
      return arg_spec, type, desttype, repeat
    end

    def self.iterate_over_arguments(args, mode)
      option_result = {}
      remaining_args = []
      while args.size > 0
        arg = args.shift
        options, argument = isOption?(arg, mode)
        if options.size >= 1 && options[0] == '--'
          remaining_args.push(*args)
          return option_result, remaining_args
        elsif options.size >= 1
          option_result, remaining_args, args = process_option(arg, option_result, args, remaining_args, options, argument)
        else
          remaining_args.push arg
        end
      end
      return option_result, remaining_args
    end

    def self.process_option(orig_opt, option_result, args, remaining_args, options, argument)
      options.each_with_index do |opt, i|
        # Make it obvious that find_option_matches is updating the instance variable
        opt_match, @option_map = find_option_matches(options[i])
        if opt_match.nil?
          remaining_args.push orig_opt
          return option_result, remaining_args, args
        end
        # Only pass argument to the last option in the options array
        args.unshift argument unless argument.nil? || argument == "" || i < (options.size - 1)
        debug "new args: #{args}"
        option_result, args = execute_option(opt_match, option_result, args)
        debug "option_result: #{option_result}"
      end
      return option_result, remaining_args, args
    end

    # find_option_matches_in_hash iterates over the option_map hash and returns
    # a list of entries that match the given option.
    #
    # NOTE: This method updates the given hash.
    #
    # @: option, hash, regex
    # return: matches, hash
    def self.find_option_matches_in_hash(opt, hash, regex)
      matches = []
      hash.each_pair do |k, v|
        local_matches = []
        k.map { |name| local_matches.push name if name.match(regex) }
        if v[:arg_spec] == 'nflag'
          k.map do |name|
            if opt.match(/^no-?/) && name.match(/^#{opt.gsub(/no-?/, '')}$/)
              # Update the given hash
              hash[k][:negated] = true
              local_matches.push name
              debug "hash: #{hash}"
            end
          end
        end
        matches.push(k) if local_matches.size > 0
      end
      return matches, hash
    end

    def self.find_option_matches(opt)
      matches = []
      m, @option_map = find_option_matches_in_hash(opt, @option_map, /^#{opt}$/)
      matches.push(*m)

      # If the strict match returns no results, lets be more permisive.
      if matches.size == 0
        m, @option_map = find_option_matches_in_hash(opt, @option_map, /^#{opt}/)
        matches.push(*m)
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
        abort "[ERROR] option '#{opt}' matches multiple names '#{matches.sort.inspect}'!"
      end
      debug "matches: #{matches}"
      [matches[0], @option_map]
    end

    # TODO: Some specs allow for Symbols and procedures, others only Symbols.
    #       Fail during init and not during run time.
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

    # process_option_type Given an arg, it checks what type is the option expecting and based on that saves
    def self.process_option_type(arg, opt_match, optional = false)
      case @option_map[opt_match][:arg_opts][0]
      when 's'
        arg = '' if optional && arg.nil?
      when 'i'
        arg = 0 if optional && arg.nil?
        type_error(arg, opt_match[0], 'Integer', lambda { |x| integer?(x) })
        arg = arg.to_i
      when 'f'
        arg = 0 if optional && arg.nil?
        type_error(arg, opt_match[0], 'Float', lambda { |x| numeric?(x) })
        arg = arg.to_f
      when 'o'
        # TODO
        abort "[ERROR] Unimplemented type 'o'!"
      end
      return arg
    end

    def self.type_error(arg, opt, type, func)
      unless func.call(arg)
        abort "[ERROR] argument for option '#{opt}' is not of type '#{type}'!"
      end
    end

    def self.process_desttype(option_result, args, opt_match, optional = false)
      opt_def = @option_map[opt_match]
      case opt_def[:arg_opts][1]
      when '@'
        unless option_result[opt_def[:opt_dest]].kind_of? Array
          option_result[opt_def[:opt_dest]] = []
        end
        # check for repeat
        if !opt_def[:arg_opts][2].nil?
          min = opt_def[:arg_opts][2][0]
          max = opt_def[:arg_opts][2][1]
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
        # check for repeat
        if !opt_def[:arg_opts][2].nil?
          min = opt_def[:arg_opts][2][0]
          max = opt_def[:arg_opts][2][1]
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

    # Check if the given string is an option (begins with -).
    # If the string is an option, it returns the options in that string as well
    # as any arguments in it.
    # @: s string, mode string
    # return: options []string, argument string
    def self.isOption?(s, mode)
      isOptionRegex = /^(--?)([^=]+)(=?)(.*?)$/
      # Handle special cases
      if s == '--'
        return ['--'], ''
      elsif s == '-'
        return ['-'], ''
      end
      options = Array.new
      argument = String.new
      matches = s.match(isOptionRegex)
      if !matches.nil?
        if matches[1] == '--'
          options.push matches[2]
          argument = matches[4]
        else
          case mode
          when 'bundling'
            options = matches[2].split('')
            argument = matches[4]
          when 'singleDash'
            options.push matches[2][0].chr
            argument = matches[2][1..-1] + matches[3] + matches[4]
          else
            options.push matches[2]
            argument = matches[4]
          end
        end
      end
      return options, argument
    end
end
