#!/usr/bin/env ruby

require 'simplecov'
SimpleCov.start
require 'minitest'
require 'minitest/autorun'
$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')
require 'ruby-getoptions'

describe GetOptions do

  # Non-options

  it 'should leave non options alone' do
    options, remaining = GetOptions.parse(
      ['Hello', 'world!', 'Non-option', 'a--'],
      { 'Hello' => :hello,
        'world!' => :world,
        'Non-option' => :non_option,
        'a' => :a }
      )
    options.must_be_empty
    remaining.must_equal ['Hello', 'world!', 'Non-option', 'a--']
  end

  it 'should leave non-options in the remaining array' do
    options, remaining = GetOptions.parse(
      ['Hello', '--string', 'test', 'world!'],
      {'string=s' => :string}
    )
    options[:string].must_equal 'test'
    remaining.must_equal ['Hello', 'world!']
  end

  it 'should stop parsing stuff when -- is given' do
    options, remaining = GetOptions.parse(
      ['hello', '--world', 'test', '--', '--string', 'test'],
      {'world=s' => :world,
       'string=s' => :string}
    )
    options[:world].must_equal 'test'
    remaining.must_equal ['hello', '--string', 'test']
  end

  # Strings

  it 'should parse strings' do
    options, remaining = GetOptions.parse(
      ['--string', 'test'],
      {'string=s' => :string}
    )
    options[:string].must_equal 'test'
    remaining.must_be_empty
  end

  it 'should parse strings with equal sign' do
    options, remaining = GetOptions.parse(
      ['Hello', '--string=test', 'world!'],
      {'string=s' => :string}
    )
    options[:string].must_equal 'test'
    remaining.must_equal ['Hello', 'world!']
  end

  it 'should allow optional strings' do
    options, remaining = GetOptions.parse(
      ['--string', 'test', '--optional'],
      {'string:s' => :string, 'optional:s' => :optional}
    )
    options[:string].must_equal 'test'
    options[:optional].must_equal ''
    remaining.must_be_empty
  end

  it 'should allow optional strings in the middle' do
    options, remaining = GetOptions.parse(
      ['--string', '--test', '--optional'],
      {'string:s' => :string, 'test:s' => :test, 'optional:s' => :optional}
    )
    options[:string].must_equal ''
    options[:test].must_equal ''
    options[:optional].must_equal ''
    remaining.must_be_empty
  end

  it 'should fail if parameter is not there strings' do
    lambda {
      lambda {
        GetOptions.parse(
          ['--string', '--test'],
          {'string=s' => :string, 'test' => :test}
        )
      }.must_raise(SystemExit)
    }.must_output('', "[ERROR] missing argument for option 'string'!\n")
  end

  # Integers

  it 'should return integers for integer options' do
    options, remaining = GetOptions.parse(
      ['Hello', '--string=test', 'world!', '--integer', '12345'],
      {'string=s' => :string, 'integer=i' => :integer}
    )
    options[:string].must_equal 'test'
    options[:integer].must_equal 12_345
    options[:integer].must_be_kind_of Integer
    remaining.must_equal ['Hello', 'world!']

    options, remaining = GetOptions.parse(
      ['Hello', '--string=test', 'world!', '--integer', '+12345'],
      {'string=s' => :string, 'integer=i' => :integer}
    )
    options[:string].must_equal 'test'
    options[:integer].must_equal 12345
    options[:integer].must_be_kind_of Integer
    remaining.must_equal ['Hello', 'world!']
  end

  it 'allows integers with - symbols' do
    options, remaining = GetOptions.parse(
      ['Hello', '--string=test', 'world!', '--integer', '-12345'],
      {'string=s' => :string, 'integer=i' => :integer}
    )
    options[:string].must_equal 'test'
    options[:integer].must_equal(-12345)
    options[:integer].must_be_kind_of Integer
    remaining.must_equal ['Hello', 'world!']
  end

  it 'should abort with non integers for integer options' do
    lambda {
      lambda {
        GetOptions.parse(
          ['Hello', '--string=test', 'world!', '--integer', '12h45'],
          {'string=s' => :string, 'integer=i' => :integer}
        )
      }.must_raise(SystemExit)
    }.must_output("", "[ERROR] argument for option 'integer' is not of type 'Integer'!\n")
    lambda {
      lambda {
        GetOptions.parse(
          ['Hello', '--string=test', 'world!', '--integer', '12.45'],
          {'string=s' => :string, 'integer=i' => :integer}
        )
      }.must_raise(SystemExit)
    }.must_output("", "[ERROR] argument for option 'integer' is not of type 'Integer'!\n")
  end

  it 'should allow optional integers' do
    options, remaining = GetOptions.parse(
      ['--integer'],
      {'integer:i' => :integer}
    )
    options[:integer].must_equal 0
    options[:integer].must_be_kind_of Integer
    remaining.must_equal []
  end

  # Floats

  it 'should return float for float options' do
    options, remaining = GetOptions.parse(
      ['Hello', '--string=test', 'world!', '--float', '12.345'],
      {'string=s' => :string, 'float=f' => :float}
    )
    options[:string].must_equal 'test'
    options[:float].must_equal 12.345
    options[:float].must_be_kind_of Float
    remaining.must_equal ["Hello", "world!"]

    options, remaining = GetOptions.parse(
      ['Hello', '--string=test', 'world!', '--float', '-12.345'],
      {'string=s' => :string, 'float=f' => :float}
    )
    options[:string].must_equal 'test'
    options[:float].must_equal(-12.345)
    options[:float].must_be_kind_of Float
    remaining.must_equal ['Hello', 'world!']

    options, remaining = GetOptions.parse(
      ['Hello', '--string=test', 'world!', '--float', '12'],
      {'string=s' => :string, 'float=f' => :float}
    )
    options[:string].must_equal 'test'
    options[:float].must_equal 12
    options[:float].must_be_kind_of Float
    remaining.must_equal ['Hello', 'world!']

    options, remaining = GetOptions.parse(
      ['--f1=123.45e1', '--f2', '123.45E2'],
      {'f1=f' => :f1, 'f2=f' => :f2}
    )
    options[:f1].must_equal 1234.5
    options[:f2].must_equal 12345.0
    options[:f1].must_be_kind_of Float
    options[:f2].must_be_kind_of Float
  end

  it 'should fail with non floats for float options' do
    lambda {
      lambda {
        GetOptions.parse(
          ['Hello', '--string=test', 'world!', '--float', '12h45'],
          {'string=s' => :string, 'float=f' => :float}
        )
      }.must_raise(SystemExit)
    }.must_output("", "[ERROR] argument for option 'float' is not of type 'Float'!\n")
  end

  it 'should allow optional floats' do
    options, remaining = GetOptions.parse(
      ['--float'],
      {'float:f' => :float}
    )
    options[:float].must_equal 0
    options[:float].must_be_kind_of Float
    remaining.must_equal []
  end

  # procedures

  it 'should call procedures' do
    lambda {
      GetOptions.parse(
        ['Hello', '--string=test', 'world!', '--procedure'],
        {'string=s' => :string, 'procedure' => lambda { puts 'Hello world! :-)' }}
      )
    }.must_output("Hello world! :-)\n")
  end

  # flags

  it 'should work with flags' do
    options, remaining = GetOptions.parse(
      ['--flag'],
      {'flag' => :flag, 'flag2' => :flag2}
    )
    options[:flag].must_equal true
    options[:flag2].must_equal nil
    remaining.must_equal []
  end

  it 'should work with negatable flags' do
    options, remaining = GetOptions.parse(
      ['--no-flag', '--flag2'],
      {'flag!' => :flag, 'flag2!' => :flag2, 'flag3!' => :flag3}
    )
    options[:flag].must_equal false
    options[:flag2].must_equal true
    options[:flag3].must_equal nil
    remaining.must_equal []
  end

  # Option definition

  it 'should warn on unknown options passed in the command line' do
    lambda {
      GetOptions.parse(
        ['Hello', '-h', 'world!'],
        {'test' => :flag2}
      )
    }.must_output('', "[WARNING] Option 'h' not found!\n")
  end

  it 'should fail on unknown options passed in the command line' do
    lambda {
      lambda {
        GetOptions.parse(
          ['Hello', '-h', 'world!'],
          {'test' => :flag2},
          {:fail_on_unknown => true}
        )
      }.must_raise(SystemExit)
    }.must_output('', "[ERROR] Option 'h' not found!\n")
  end

  it 'should pass_through on unknown options passed in the command line' do
    lambda {
        GetOptions.parse(
          ['Hello', '-h', 'world!'],
          {'test' => :flag2},
          {:pass_through => true}
        )
    }.must_output('', '')

    options, remaining = GetOptions.parse(
        ['Hello', '-h', 'world!'],
        {'test' => :flag2},
        {:pass_through => true}
    )
    options.must_be_empty
    remaining.must_equal ['Hello', '-h', 'world!']
  end

  it 'must allow several levels of pass_through' do
    options, remaining = GetOptions.parse(
        ['Hello', '-h', 'world!', '-t', 'test'],
        {'t=s' => :t},
        {:pass_through => true}
    )
    options[:t].must_equal 'test'
    remaining.must_equal ['Hello', '-h', 'world!']
    new_options, new_remaining = GetOptions.parse(remaining,
        {'h=s' => :hello}
    )
    new_remaining.must_equal ['Hello']
    new_options[:hello].must_equal 'world!'
  end

  it 'should check the option_map for hash key uniqness / duplicates' do
    # Unfortunatelly Ruby allows to create a Hash with the same key on the same
    # line, there is no way to check for that that works consistently for me.
    lambda {
      GetOptions.parse(
        ['Hello', 'world!'],
        { 'flag' => :flag, 'hello|flag' => :hello }
      )
    }.must_raise(ArgumentError)
  end

  it 'should allow multiple definitions, aliases, for a single entry' do
    options, remaining = GetOptions.parse(
      ['Hello', '--test', 'world!'],
      { 'flag' => :flag, 'hello|test!' => :test, }
    )
    options[:test].must_equal true
    options[:flag].must_equal nil
    remaining.must_equal ['Hello', 'world!']
  end

  it 'should fail if name not defined' do
    lambda {
      GetOptions.parse(
        ['Hello', '--test'],
        { '=s@{3}' => :missing_name }
      )
    }.must_raise(ArgumentError)
  end

  it 'should abort if option matches multiple names' do
    lambda {
      lambda {
        GetOptions.parse(
          ['Hello', '-t', 'world!'],
          {'testing' => :flag, 'test' => :flag2}
        )
      }.must_raise(SystemExit)
    }.must_output('',
                  "[ERROR] option 't' matches multiple names '[[\"test\"], [\"testing\"]]'!\n")
  end

  it 'should allow case sensitive matching' do
    options, remaining = GetOptions.parse(
      ['Hello', '--test', 'happy', '--Test', 'world!'],
      { 'flag' => :flag, 'test!' => :test, 'Test!' => :Test }
    )
    options[:test].must_equal true
    options[:Test].must_equal true
    options[:flag].must_equal nil
    remaining.must_equal ['Hello', 'happy', 'world!']

    options, remaining = GetOptions.parse(
      ['Hello', '--test', 'world!'],
      { 'flag' => :flag, 'test!' => :test, 'Test!' => :Test }
    )
    options[:test].must_equal true
    options[:Test].must_equal nil
    options[:flag].must_equal nil
    remaining.must_equal ['Hello', 'world!']

    options, remaining = GetOptions.parse(
      ['-v'],
      { 'v|verbose!' => :v, 'V|Version!' => :V }
    )
    options[:v].must_equal true
    options[:V].must_equal nil
    remaining.must_equal []

    options, remaining = GetOptions.parse(
      ['-V'],
      { 'v|verbose!' => :v, 'V|Version!' => :V }
    )
    options[:v].must_equal nil
    options[:V].must_equal true
    remaining.must_equal []
  end

  it 'should allow @ definition' do
    options, remaining = GetOptions.parse(
      ['-t', 'hello', '-t', 'world!'],
      { 't=s@' => :string }
    )
    options[:string].must_equal ['hello', 'world!']
    remaining.must_equal []

    options, remaining = GetOptions.parse(
      ['-t', '1', '-t', '3'],
      { 't=i@' => :int }
    )
    options[:int].must_equal [1, 3]
    remaining.must_equal []

    options, remaining = GetOptions.parse(
      ['-t', '1.5', '-t', '3.2'],
      { 't=f@' => :float }
    )
    options[:float].must_equal [1.5, 3.2]
    remaining.must_equal []
  end

  it 'should allow repeat definition' do
    options, remaining = GetOptions.parse(
      ['-t', 'hello', 'happy', 'world!', ':-)'],
      { 't=s@{3}' => :string }
    )
    options[:string].must_equal ['hello', 'happy', 'world!']
    remaining.must_equal [':-)']
  end

  it 'should allow repeat definition with min and max' do
    options, remaining = GetOptions.parse(
      ['-t', 'hello', 'happy', 'world!', ':-)'],
      { 't=s@{2, 3}' => :string }
    )
    options[:string].must_equal ['hello', 'happy', 'world!']
    remaining.must_equal [':-)']
  end

  it 'should abort if repeat cannot be met' do
    lambda {
      lambda {
        _options, _remaining = GetOptions.parse(
          ['-t', 'hello', 'happy', 'world!', ':-)'],
          { 't=s@{5}' => :string }
        )
      }.must_raise(SystemExit)
    }.must_output("", "[ERROR] missing argument for option 't'!\n")

    lambda {
      lambda {
        _options, _remaining = GetOptions.parse(
          ['-t', 'hello=world', 'happy=life', 'world=tour', 'smile=:-)'],
          { 't=s%{5}' => :string }
        )
      }.must_raise(SystemExit)
    }.must_output("", "[ERROR] missing argument for option 't'!\n")
  end

  it 'should fail if repeat definition is wrong' do
    lambda {
      _options, _remaining = GetOptions.parse(
        [],
        { 't=s@{5,3}' => :string }
      )
    }.must_raise(ArgumentError)
    lambda {
      _options, _remaining = GetOptions.parse(
        [],
        { 't=s@{}' => :string }
      )
    }.must_raise(ArgumentError)
    lambda {
      _options, _remaining = GetOptions.parse(
        [],
        { 't=s@{2' => :string }
      )
    }.must_raise(ArgumentError)
  end

  it 'should allow hash options' do
    options, remaining = GetOptions.parse(
      ['-t', 'os=linux', '-t', 'editor=vim', ':-)'],
      { 't=s%' => :hash }
    )
    options[:hash].must_equal({"os"=>"linux", "editor"=>"vim"})
    remaining.must_equal [":-)"]
  end

  it 'should allow hash options with integer type' do
    options, remaining = GetOptions.parse(
      ['-t', 'os=3', '-t', 'editor=7', ':-)'],
      { 't=i%' => :hash }
    )
    options[:hash].must_equal({"os"=>3, "editor"=>7})
    remaining.must_equal [":-)"]
  end

  it 'should check hash options key value type' do
    lambda {
      lambda {
        GetOptions.parse(
          ['-t', 'os', '-t', 'editor=vim', ':-)'],
          { 't=s%' => :hash }
        )
      }.must_raise(SystemExit)
    }.must_output("", "[ERROR] argument for option 't' must be of type key=value!\n")
  end

  it 'should allow hash options with repeat' do
    options, remaining = GetOptions.parse(
      ['-t', 'os=linux', 'editor=vim', ':-)'],
      { 't=s%{2}' => :hash }
    )
    options[:hash].must_equal({"os"=>"linux", "editor"=>"vim"})
    remaining.must_equal [":-)"]

    options, remaining = GetOptions.parse(
      ['-t', 'os=linux', 'editor=vim', ':-)'],
      { 't=s%{1, 2}' => :hash }
    )
    options[:hash].must_equal({"os"=>"linux", "editor"=>"vim"})
    remaining.must_equal [":-)"]
  end

  # Bundling

  it 'should support bundling' do
    options, remaining = GetOptions.parse(
      ['-opt', 'arg', 'test'],
      {'o' => :o, 'p' => :p, 't=s' => :t},
      {:mode => 'bundling'}
    )
    options[:o].must_equal true
    options[:p].must_equal true
    options[:t].must_equal 'arg'
    remaining.must_equal ["test"]

    options, remaining = GetOptions.parse(
      ['-opt=arg', 'test'],
      {'o' => :o, 'p' => :p, 't=s' => :t},
      {:mode => 'bundling'}
    )
    options[:o].must_equal true
    options[:p].must_equal true
    options[:t].must_equal 'arg'
    remaining.must_equal ["test"]
  end

  # Enforce Single Dash

  it 'should support single dash mode' do
    options, remaining = GetOptions.parse(
      ['-opt', 'arg', 'test'],
      {'o=s' => :o},
      {:mode => 'single_dash'}
    )
    options[:o].must_equal 'pt'
    remaining.must_equal ["arg", "test"]

    options, remaining = GetOptions.parse(
      ['-opt=arg', 'test'],
      {'o=s' => :o},
      {:mode => 'single_dash'}
    )
    options[:o].must_equal 'pt=arg'
    remaining.must_equal ["test"]
  end

  # Internal methods

  it 'should check if isOption?' do
    # each test = [s, mode, options, argument]
    t = []
    # No opt
    t.push ['opt=arg', 'normal', [], '']
    t.push ['opt=arg', 'bundling', [], '']
    t.push ['opt=arg', 'singleDash', [], '']
    # Special cases
    t.push ['-', 'normal', ['-'], '']
    t.push ['-', 'bundling', ['-'], '']
    t.push ['-', 'singleDash', ['-'], '']
    t.push ['--', 'normal', ['--'], '']
    t.push ['--', 'bundling', ['--'], '']
    t.push ['--', 'singleDash', ['--'], '']
    # double dash behaves the same in all modes
    t.push ['--opt', 'normal', ['opt'], '']
    t.push ['--opt', 'bundling', ['opt'], '']
    t.push ['--opt', 'singleDash', ['opt'], '']
    t.push ['--opt=arg', 'normal', ['opt'], 'arg']
    t.push ['--opt=arg', 'bundling', ['opt'], 'arg']
    t.push ['--opt=arg', 'singleDash', ['opt'], 'arg']
    # single dash varies by mode
    t.push ['-opt', 'normal', ['opt'], '']
    t.push ['-opt', 'bundling', ['o', 'p', 't'], '']
    t.push ['-opt', 'singleDash', ['o'], 'pt']
    t.push ['-opt=arg', 'normal', ['opt'], 'arg']
    t.push ['-opt=arg', 'bundling', ['o', 'p', 't'], 'arg']
    t.push ['-opt=arg', 'singleDash', ['o'], 'pt=arg']
    t.each do |test|
      options, argument = GetOptions.isOption?(test[0], test[1])
      options.must_equal test[2]
      argument.must_equal test[3]
    end
  end

  it 'should expand option specification' do
    # each test = [opt_spec, [arg_spec, type, destype, [repeat min, max]]]
    t = []
    t.push ["" , ["flag", 'b', nil, nil ]]
    t.push ["!" , ["nflag", 'b', nil, nil ]]
    t.push ["+" , ["increment", 'i', nil, nil ]]
    t.push ["=i" , ["required", 'i', nil, nil ]]
    t.push ["=s" , ["required", 's', nil, nil ]]
    t.push ["=f" , ["required", 'f', nil, nil ]]
    t.push ["=o" , ["required", 'o', nil, nil ]]
    t.push ["=i@" , ["required", 'i', '@', nil ]]
    t.push ["=s@" , ["required", 's', '@', nil ]]
    t.push ["=f@" , ["required", 'f', '@', nil ]]
    t.push ["=o@" , ["required", 'o', '@', nil ]]
    t.push ["=i%" , ["required", 'i', '%', nil ]]
    t.push ["=s%" , ["required", 's', '%', nil ]]
    t.push ["=f%" , ["required", 'f', '%', nil ]]
    t.push ["=o%" , ["required", 'o', '%', nil ]]
    t.push ["=i@{2}" , ["required", 'i', '@', [2, 2] ]]
    t.push ["=i@{2,}" , ["required", 'i', '@', [2, 2] ]]
    t.push ["=i@{,3}" , ["required", 'i', '@', [1, 3] ]]
    t.push ["=i@{2,3}" , ["required", 'i', '@', [2, 3] ]]
    t.push ["=s@{2,3}" , ["required", 's', '@', [2, 3] ]]
    t.push ["=f@{2,3}" , ["required", 'f', '@', [2, 3] ]]
    t.push ["=o@{2,3}" , ["required", 'o', '@', [2, 3] ]]
    t.each do |test|
      arg_opts = GetOptions.process_opt_spec(test[0])
      arg_opts.must_equal test[1]
    end
  end

  it 'should extract aliases from definition' do
    # each test = [opt_spec, [arg_spec, [aliases, ...]]
    t = []
    t.push ["flag" , ["", ["flag"]]]
    t.push ["flag|f" , ["", ["flag", "f"]]]
    t.push ["flag|f|f" , ["", ["flag", "f", "f"]]]
    t.push ["f|flag|f|f" , ["", ["f", "flag", "f", "f"]]]
    t.push ["nf|nflag!" , ["!", ["nf", "nflag"]]]
    t.push ["if|iflag+" , ["+", ["if", "iflag"]]]
    t.push ["i|int=i" , ["=i", ["i", 'int']]]
    t.push ["s|string=s" , ["=s", ["s", 'string']]]
    t.push ["float|f=f" , ["=f", ["float", 'f']]]
    t.push ["other|o=o" , ["=o", ["other", 'o']]]
    t.push ["array|a=i@" , ["=i@", ["array", 'a']]]
    t.push ["hash|h=i%" , ["=i%", ["hash", 'h']]]
    t.push ["repeat|r=i@{2,3}" , ["=i@{2,3}", ["repeat", 'r']]]
    t.each do |test|
      arg_opts = GetOptions.extract_spec_and_aliases(test[0])
      arg_opts.must_equal test[1]
    end
  end

  it 'should fail on duplicate definitions' do
    GetOptions.fail_on_duplicate_definitions(
      ['Hello', 'world!']
    ).must_equal true
    GetOptions.fail_on_duplicate_definitions(
      ['Hello', 'world!', 'hello']
    ).must_equal true
    GetOptions.fail_on_duplicate_definitions(
      ['Hello', 'world!', 'He']
    ).must_equal true
    lambda {
      GetOptions.fail_on_duplicate_definitions(
        ['Hello', 'world!', 'Hello']
      )
    }.must_raise(ArgumentError)
  end

end
