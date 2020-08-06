require "json"
require "./put-io"
# require "./put-io/cli/config"
require "pretty_print"

class PutIO
  class CLI
    APP_ID = 4722_i64
    enum Commands
      Help
      AccountInfo
      List
      Get
      Path
      Login
      Transfers
      Statuses
      Upload
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
    property config : JSON::Any
    # property dbfile : Path
    property verbose : Bool = false
    property profile : String
    property application_secret : String?
    property app_id : Int64? = APP_ID
    property token : String?
    property command : Commands
    property putio : PutIO
    property output_format : OutputFormat = OutputFormat::Auto
    property io : IO = STDOUT
    property output_file : Path? = nil
    property get_ids : Array(Int64) = [] of Int64
    property paths : Array(String) = [] of String
    property name_match : Regex? = nil
    property error_match : Bool? = nil
    property status_match : Set(PutIO::Transfer::Status)? = nil
    property sortkey : Symbol = :created_at
    property parent : String? = nil

    def initialize(*args : String)
      initialize argv: args
    end

    def initialize(argv : Array(String) = ARGV)
      configfile : Path? = nil
      # dbfile : Path? = nil
      profile : String? = nil
      command : Commands? = nil

      while argv.size > 0
        arg = argv.shift
        case arg
        when "--configfile", "-c"
          configfile = Path[argv.shift]
          # when "--dbfile", "-D"
          # dbfile = Path[argv.shift]
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
        when "--name"
          name_arg = argv.shift || raise "#{arg}: requires an argument"
          if name_arg =~ %r{^/.*/$}
            @name_match = Regex.new name_arg.sub(%r{^/}, "").sub(%r{/$}, "")
          else
            @name_match = Regex.new Regex.escape name_arg
          end
        when "--errored"
          @error_match = true
        when "--folder", "--at"
          @parent = ARGV.shift
        when "--not-errored"
          @error_match = false
        when "--status"
          status_arg = argv.shift || raise "#{arg}: requires an argument"
          @status_match = PutIO::Transfer::Status.parse_arg @status_match, status_arg
        when "--sort"
          sorted_arg = argv.shift || raise "#{arg}: requires an argument"
          @sortkey = case sorted_arg.downcase
                     when "name"
                       :name
                     when "percent", "completion_percent", "completion"
                       :completion_percent
                     when "ratio", "current_ratio"
                       :current_ratio
                     when "created", "created_at", "create"
                       :created_at
                     when "completed", "finished", "finished_at"
                       :finished_at
                     else
                       raise "unknown sort key"
                     end
        when "account_info", "account-info", "info"
          command = Commands::AccountInfo
        when "list"
          command = Commands::List
        when "get"
          command = Commands::Get
        when "path"
          command = Commands::Path
        when "transfer", "transfers"
          command = Commands::Transfers
        when "statuses"
          command = Commands::Statuses
        when "upload", "put"
          command = Commands::Upload
        when /^--/
          raise "#{arg}: unknown option"
        else
          if command == Commands::Get && arg.match(%r{^\d+$})
            @get_ids << arg.to_i64
          elsif command == Commands::Path || command == Commands::Upload
            @paths << arg.to_s
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
      # @dbfile = dbfile = Path[dbfile || ENV["PUTIO_DB"]? || "#{ENV["HOME"]}/Library/Put.IO/putio.sqlite3"]
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
        # STDERR.puts "dbfile: #{@dbfile}"
      end

      # read the config file
      @config = JSON::Any.new({} of String => JSON::Any)
      begin
        File.open(configfile, "r") do |input|
          @config = JSON.parse(input)
        end
      rescue
        File.write(configfile, @config.to_json)
      end
      config = @config
      raise "#{PROGRAM_NAME}: #{configfile}: profile '#{@profile}' not found" unless @config[profile]?
      while @config[profile].as_s?
        new_profile = @config[profile].as_s
        raise "#{PROGRAM_NAME}: #{configfile}: profile '#{new_profile}' not found from 'use' directive in profile '#{profile}'" unless @config[new_profile]?
        STDERR.puts "use profile: #{profile} -> #{new_profile}" if verbose
        @profile = profile = new_profile
      end

      STDERR.puts "profile: #{@profile}" if verbose
      ["token"].each do |required_key|
        raise "#{PROGRAM_NAME}: #{@configfile}: profile '#{@profile}': #{required_key} not defined" unless @config[profile][required_key]?
      end
      @application_secret = @config[profile]["application_secret"].as_s if config[profile]["application_secret"]?
      @app_id = @config[profile]["client_id"].as_i64 if config[profile]["client_id"]?
      @app_id = @config[profile]["app_id"].as_i64 if config[profile]["app_id"]?
      @token = @config[profile]["token"].as_s if config[profile]["token"]?
      if verbose
        STDERR.puts "application_secret: #{@application_secret.inspect}"
        STDERR.puts "client_id: #{@app_id.inspect}"
        STDERR.puts "token: #{@token.inspect}"
      end

      # Dir.mkdir_p @dbfile.parent unless Dir.exists? @dbfile.parent
      token = @token
      if token
        @putio = PutIO.new(
          app_id: @app_id,
          application_secret: @application_secret,
          token: token,
        )
      else
        raise "no token"
      end
      # dbfile: @dbfile,
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
        entries = putio.file_tree
        prepare_output
        case @output_format
        when OutputFormat::ASCII, OutputFormat::ANSI
          entries.keys.sort.each do |path|
            entry = entries[path]
            if entry.file?
              @io.printf "%14d %14d %-23s %s\n", entry.id, entry.size, entry.content_type, path
            else
              @io.printf "%14d %14d %-23s %s\n", entry.id, (entry.child_ids.try &.size) || 0, entry.content_type, path
            end
          end
        when OutputFormat::Unset
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
      when Commands::Login
        raise "cannot login, token already defined" if @token
      when Commands::Transfers
        transfers = putio.transfers_list
        count = transfers.size
        transfers.sort! do |a, b|
          result = a.status <=> b.status
          result = a.completion_percent <=> b.completion_percent if 0 == result
          result = a.name <=> b.name if 0 == result
          result
        end
        if status_match = @status_match
          transfers = transfers.select { |t| status_match.includes? t.status }
          STDERR.puts "#{count} transfers, #{count - transfers.size} removed, #{transfers.size} remaining"
        end
        if name_match = @name_match
          transfers = transfers.select { |t| name_match.match t.name }
          STDERR.puts "#{count} transfers, #{count - transfers.size} removed, #{transfers.size} remaining"
        end
        error_match = @error_match
        if !error_match.nil?
          transfers = transfers.select { |t| @error_match == t.error? }
          STDERR.puts "#{count} transfers, #{count - transfers.size} removed, #{transfers.size} remaining"
        end
        prepare_output
        case @output_format
        when OutputFormat::ASCII
          transfers.each do |transfer|
            transfer.to_ascii(@io)
          end
        when OutputFormat::ANSI
          transfers.each do |transfer|
            transfer.to_ansi(@io)
          end
        when OutputFormat::JSON
          transfers.to_json(@io)
          @io << "\n"
        else
          raise "#{@output_format}: output format not implemented"
        end
      when Commands::Statuses
        statuses = PutIO::Transfer::Status.names
        prepare_output
        case @output_format
        when OutputFormat::ASCII, OutputFormat::ANSI
          statuses.each { |s| @io.puts s }
        when OutputFormat::JSON
          statuses.to_json(@io)
          @io << "\n"
        else
          raise "#{@output_format}: output format not implemented"
        end
      when Commands::Upload
        parent = @parent || "/"
        case parent
        when /^\d+$/
          parent_id = parent.to_i64
        else
          parent_id = putio.by_path(parent).id
        end
        @paths.each do |path|
          puts "Starting upload: #{path}"
          response = @putio.upload file: path, parent: parent_id
          if response.success?
            puts "Upload complete"
            puts response.body
          else
            STDERR.puts "Upload failed: #{response.status_code} #{response.status_message}"
            STDERR.puts response.body
          end
        end
      else
        raise "#{command}: unknown command"
      end
    end
  end
end

def human_size(bytes : Int64)
  negative = bytes < 0 ? "-" : ""
  real_bytes = bytes.abs.to_f
  units = ["", "K", "M", "G", "T"]
  while units.size > 1 && real_bytes > 1024.0_f64
    real_bytes = real_bytes / 1024.0_f64
    units.shift
  end
  "%s%.1f%s" % [negative, real_bytes, units[0]]
end

def human_size(bytes : Int32)
  human_size bytes.to_i64
end

def human_size(bytes : UInt32)
  human_size bytes.to_i64
end

putio_cli = PutIO::CLI.new(ARGV)
putio_cli.run
