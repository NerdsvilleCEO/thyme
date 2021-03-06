require "../thyme"
require "option_parser"

class Thyme::Command
  private getter args : Array(String)
  private getter io : IO
  private getter foreground : Bool = false

  def initialize(@args = ARGV, @io = STDOUT)
  end

  def run
    config = Config.parse
    # see https://github.com/crystal-lang/crystal/issues/5338
    # OptionParser can't handle optional flag argument for now
    config.set_repeat if args.any?(Set{"-r", "--repeat"})

    parser = OptionParser.parse(args) do |parser|
      parser.banner = "Usage: thyme [options]"

      parser.on("-h", "--help", "print help message") { print_help(parser); exit }
      parser.on("-v", "--version", "print version") { print_version; exit }
      parser.on("-f", "--foreground", "run in foreground") { @foreground = true }
      parser.on("-r", "--repeat [count]", "repeat timer") { |r| config.set_repeat(r) }
      parser.on("-s", "--stop", "stop timer") { stop; exit }
      config.options.each do |option|
        parser.on(
          option.flag,
          option.flag_long,
          option.description
      ) { |flag| option.call({ flag: flag, args: args.join(" ") }); exit }
      end
    end

    if args.size > 0
      print_help(parser)
    elsif ProcessHandler.running?
      SignalHandler.send_toggle
    else
      start(config)
    end
  rescue error : OptionParser::InvalidOption | OptionParser::MissingOption | Error
    io.puts(error)
  end

  private def start(config : Config)
    Daemon.start! unless foreground
    ProcessHandler.write_pid

    timer = Timer.new(config)
    SignalHandler.on_stop { timer.stop }
    SignalHandler.on_toggle { timer.toggle }
    timer.run
  rescue error : Error
    io.puts(error)
    ProcessHandler.delete_pid
  end

  private def stop
    SignalHandler.send_stop if ProcessHandler.running?
  ensure
    ProcessHandler.delete_pid
  end

  private def print_help(parser)
    io.puts(parser)
  end

  private def print_version
    io.puts(VERSION)
  end
end
