require "json"
require "./put-io"
require "pretty_print"

class PutIO
  class CLI
    enum Commands
      Help
      AccountInfo
      List
      Get
      Path
    end
    enum OutputFormat
      Unset
      Auto
      JSON
      ASCII
      ANSI
    end

    @@DEFAULT_PROFILE = "default"

    property configfile : Path
    property dbfile : Path
    property verbose : Bool = false
    property profile : String
    property application_secret : String?
    property client_id : Int64?
    property token : String
    property command : Commands
    property putio : PutIO
    property output_format : OutputFormat = OutputFormat::Auto
    property io : IO = STDOUT
    property output_file : Path? = nil
    property get_ids : Array(Int64) = [] of Int64
    property paths : Array(String) = [] of String

    def initialize(*args : String)
      initialize argv: args
    end

    def initialize(argv : Array(String) = ARGV)
      configfile : Path? = nil
      dbfile : Path? = nil
      profile : String? = nil
      command : Commands? = nil

      while argv.size > 0
        arg = argv.shift
        case arg
        when "--configfile", "-c"
          configfile = Path[argv.shift]
        when "--dbfile", "-D"
          dbfile = Path[argv.shift]
        when "--profile", "-p"
          profile = argv.shift
        when "--verbose", "-v"
          verbose = true
          PutIO.verbose true
        when "--color", "-C", "--ansi"
          @output_format = OutputFormat::ANSI
        when "--no-color", "--ascii"
          @output_format = OutputFormat::ASCII
        when "--auto-format"
          @output_format = OutputFormat::Auto
        when "--json"
          @output_format = OutputFormat::JSON
        when "--format"
          raise "#{arg}: missing argument" if argv.size == 0
          format_name = argv.shift
          case format_name.downcase
          when "json"
            @output_format = OutputFormat::JSON
          when "color", "ansi"
            @output_format = OutputFormat::ANSI
          when "no-color", "nocolor", "no_color", "plain", "text", "ascii"
            @output_format = OutputFormat::ASCII
          else
            raise "#{format_name}: unknown output format"
          end
        when "--output", "-o"
          @output_file = Path[argv.shift]
        when "account_info", "account-info", "info"
          command = Commands::AccountInfo
        when "list"
          command = Commands::List
        when "get"
          command = Commands::Get
        when "path"
          command = Commands::Path
        else
          if command == Commands::Get && arg.match(%r{^\d+$})
            @get_ids << arg.to_i64
          elsif command == Commands::Path
            paths << arg.to_s
          else
            raise "#{PROGRAM_NAME}: #{arg}: unknown option"
          end
        end
      end

      @command = command || Commands::Help

      configfile ||= Path.[ENV["PUTIO_CONFIG"]? || "#{ENV["HOME"]}/.config/putio.json"]
      @configfile = case configfile
                    when Path
                      configfile
                    when String
                      Path[configfile]
                    else
                      raise "no configfile defined"
                    end
      @dbfile = dbfile = Path[dbfile || ENV["PUTIO_DB"]? || "#{ENV["HOME"]}/Library/Put.IO/putio.sqlite3"]
      @profile = profile = (profile || ENV["PUTIO_PROFILE"]? || @@DEFAULT_PROFILE).to_s
      if @output_format == OutputFormat::Auto
        if @output_file
          @output_format = OutputFormat::JSON
        elsif STDOUT.tty?
          @output_format = OutputFormat::ANSI
        else
          @output_format = OutputFormat::ASCII
        end
      end

      if verbose
        STDERR.puts "configfile: #{configfile}"
        STDERR.puts "dbfile: #{@dbfile}"
      end

      # read the config file
      config = File.open(configfile) do |input|
        JSON.parse(input)
      end
      raise "#{PROGRAM_NAME}: #{configfile}: profile '#{@profile}' not found" unless config[profile]?
      while config[profile].as_s?
        new_profile = config[profile].as_s
        raise "#{PROGRAM_NAME}: #{configfile}: profile '#{new_profile}' not found from 'use' directive in profile '#{profile}'" unless config[new_profile]?
        STDERR.puts "use profile: #{profile} -> #{new_profile}" if verbose
        @profile = profile = new_profile
      end

      STDERR.puts "profile: #{@profile}" if verbose
      ["token"].each do |required_key|
        raise "#{PROGRAM_NAME}: #{@configfile}: profile '#{@profile}': #{required_key} not defined" unless config[profile][required_key]?
      end
      @application_secret = config[profile]["application_secret"].as_s if config[profile]["application_secret"]?
      @client_id = config[profile]["client_id"].as_i64 if config[profile]["client_id"]?
      @token = config[profile]["token"].as_s
      if verbose
        STDERR.puts "application_secret: #{@application_secret.inspect}"
        STDERR.puts "client_id: #{@client_id.inspect}"
        STDERR.puts "token: #{@token.inspect}"
      end

      Dir.mkdir_p @dbfile.parent unless Dir.exists? @dbfile.parent
      @putio = PutIO.new(
        client_id: @client_id,
        application_secret: @application_secret,
        token: @token,
        dbfile: @dbfile,
      )
    end

    private def prepare_output
      output_file = @output_file
      @io = output_file ? File.open output_file, mode: "w" : STDOUT
    end

    def run
      case command = @command
      when Commands::Help
        STDERR.puts "No help defined yet"
        exit 99
      when Commands::AccountInfo
        account_info = putio.account_info
        prepare_output
        case @output_format
        when OutputFormat::ANSI
          account_info.to_ansi(@io)
        when OutputFormat::ASCII
          account_info.to_s(@io)
        when OutputFormat::JSON
          account_info.to_json(@io)
        else
          raise "#{@output_format}: output format not implemented"
        end
      when Commands::List
        entries = putio.tree
        prepare_output
        case @output_format
        when OutputFormat::ANSI, OutputFormat::ASCII
          entries.keys.sort.each { |e| @io.puts entries[e].to_json }
        when OutputFormat::JSON
          entries.to_json(@io)
          @io.print "\n"
        end
      when Commands::Get
        prepare_output
        get_ids.each do |id|
          entry = putio.by_id id: id
          if entry
            entry.to_json(@io)
            @io.print "\n"
          else
            STDERR.puts "Failed to fetch info for #{id}"
          end
        end
      when Commands::Path
        entries = [] of PutIO::Entry
        paths.each do |path|
          entry = putio.by_path path: path
          STDERR.puts "#{path}: found" if verbose
          entries << entry
        end
        if entries.size > 0
          STDERR.puts "#{entries.size} entries found"
          prepare_output
          entries.each { |e| e.to_json(@io); @io << "\n" }
        else
          STDERR.puts "No entries found"
        end
      else
        raise "#{command}: unknown command"
      end
    end
  end
end

putio_cli = PutIO::CLI.new(ARGV)
putio_cli.run
