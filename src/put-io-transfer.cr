require "json"
require "./put-io-util"

class PutIO
  class Transfer
    include PutIO::Util
    enum Status
      ERROR
      IN_QUEUE
      WAITING
      DOWNLOADING
      COMPLETING
      SEEDING
      COMPLETED

      def self.parse_arg(current : Set(self)?, text : String) : Set(self)
        if !current
          current = Set(self).new
        end
        text.split(%r{[, \|:\n]+}).each do |word|
          if member = self.parse? word
            current.add member
          else
            raise "#{word}: unknown transfer status"
          end
        end
        current
      end
    end

    enum TransferType
      TORRENT
      URL
      PLAYLIST
    end

    class EnumConverter(T)
      def from_json(json : JSON::PullParser)
        T.parse(json.read_string)
      end

      def to_json(value : T, builder : JSON::Builder)
        builder.string(value.to_s)
      end
    end

    class_property entries : Hash(Int64, self) = {} of Int64 => self
    include JSON::Serializable
    property availability : Int32?
    property callback_url : String?
    property client_ip : String
    property completion_percent : Int32
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property created_at : Time
    property created_torrent : Bool
    property current_ratio : Float64
    property downloaded : Int64
    property download_id : Int64
    property down_speed : Int32
    property error_message : String?
    property estimated_time : Int32?
    property file_id : Int64?
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property finished_at : Time?
    property hash : String
    property id : Int64
    property is_private : Bool
    property name : String
    property peers : Int32?
    property peers_connected : Int32
    property peers_getting_from_us : Int32
    property peers_sending_to_us : Int32
    property percent_done : Int32
    property save_parent_id : Int64
    property seconds_seeding : Int32?
    property simulated : Bool?
    property size : Int64
    property source : String
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property started_at : Time?
    @[JSON::Field(converter: PutIO::Transfer::EnumConverter(PutIO::Transfer::Status).new)]
    property status : Status
    property status_message : String
    property subscription_id : Int32?
    property torrent_link : String
    property tracker : String
    property tracker_message : String?
    @[JSON::Field(converter: PutIO::Transfer::EnumConverter(PutIO::Transfer::TransferType).new)]
    property type : TransferType
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property updated_at : Time?
    property uploaded : Int64
    property up_speed : Int32

    def initialize(*,
                   @availability,
                   @callback_url = nil,
                   @client_ip,
                   @completion_percent,
                   @created_at,
                   @created_torrent,
                   @current_ratio,
                   @downloaded,
                   @download_id,
                   @down_speed,
                   @error_message = nil,
                   @estimated_time = nil,
                   @file_id,
                   @finished_at = nil,
                   @hash,
                   @id,
                   @is_private,
                   @name,
                   @peers,
                   @peers_connected,
                   @peers_getting_from_us,
                   @peers_sending_to_us,
                   @percent_done,
                   @save_parent_id,
                   @seconds_seeding = nil,
                   @simulated = nil,
                   @size,
                   @source,
                   @started_at = nil,
                   @status,
                   @status_message,
                   @subscription_id = nil,
                   @torrent_link,
                   @tracker,
                   @tracker_message = nil,
                   @type,
                   @updated_at = nil,
                   @uploaded,
                   @up_speed)
    end

    def self.new(obj : Hash(String, JSON::Any))
      if obj["id"]? && obj["id"].as_i64?
        if cached = PutIO::Transfer[obj["id"].as_i64]?
          return cached
        end
      end
      time_format = Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.load("UTC"))
      # obj["current_ratio"] = JSON::Any.new begin
      #   obj["current_ratio"].as_f32
      # rescue
      #   1.0_f32 * obj["current_ratio"].as_i64
      # end
      register new(
        availability: obj["availability"].as_i,
        callback_url: obj["callback_url"].as_s?,
        client_ip: obj["client_ip"].as_s,
        completion_percent: obj["completion_percent"].as_i,
        created_at: time_format.parse(obj["created_at"].as_s),
        created_torrent: obj["created_torrent"].as_bool,
        current_ratio: obj["current_ratio"].raw.as(Int64 | Float64).to_f,
        downloaded: obj["downloaded"].as_i64,
        download_id: obj["download_id"].as_i64,
        down_speed: obj["down_speed"].as_i,
        error_message: obj["error_message"].as_s?,
        estimated_time: obj["estimated_time"].as_i?,
        file_id: obj["file_id"].as_i64?,
        finished_at: obj["finished_at"]? && obj["finished_at"].as_s? ? time_format.parse(obj["finished_at"].as_s) : nil,
        hash: obj["hash"].as_s,
        id: obj["id"].as_i64,
        is_private: obj["is_private"].as_bool,
        name: obj["name"].as_s,
        peers: obj["peers"]?.try(&.as_i?) || 0_i32,
        peers_connected: obj["peers_connected"].as_i,
        peers_getting_from_us: obj["peers_getting_from_us"].as_i,
        peers_sending_to_us: obj["peers_sending_to_us"].as_i,
        percent_done: obj["percent_done"].as_i,
        save_parent_id: obj["save_parent_id"].as_i64,
        seconds_seeding: obj["seconds_seeding"].as_i?,
        simulated: obj["simulated"].as_bool?,
        size: obj["size"]?.try(&.as_i64) || 0_i64,
        source: obj["source"].as_s,
        started_at: obj["started_at"]? && obj["started_at"].as_s? ? time_format.parse(obj["started_at"].as_s) : nil,
        status: Status.parse(obj["status"].as_s),
        status_message: obj["status_message"].as_s,
        subscription_id: obj["subscription_id"].as_i?,
        torrent_link: obj["torrent_link"].as_s,
        tracker: obj["tracker"].as_s,
        tracker_message: obj["tracker_message"].as_s?,
        type: TransferType.parse(obj["type"].as_s),
        updated_at: obj["updated_at"]? && obj["updated_at"].as_s? ? time_format.parse(obj["updated_at"].as_s) : nil,
        uploaded: obj["uploaded"].as_i64,
        up_speed: obj["up_speed"].as_i,
      )
    rescue e
      STDERR.puts "obj: #{obj.inspect}"
      raise e
    end

    def error?
      return true if @status == Status::ERROR
      if @tracker_message.try &.match(/error/i)
        # STDERR.puts "error: #{@tracker_message}"
        return true
      end
      return false
    end

    def queued?
      !error? && @status == Status::IN_QUEUE
    end

    def waiting?
      !error? && @status == Status::WAITING
    end

    def downloading?
      !error? && @status == Status::DOWNLOADING
    end

    def seeding?
      !error? && @status == Status::SEEDING
    end

    def completed?
      !error? && @status == Status::COMPLETED
    end

    def done?
      seeding? || completed?
    end

    def running?
      downloading? || completing?
    end

    def to_ascii(io : IO)
      tracker_message = @tracker_message
      status_message = @status_message
      finished_at = @finished_at
      seconds_seeding = @seconds_seeding
      estimated_time = @estimated_time
      up_speed = @up_speed
      down_speed = @down_speed
      io.print "\n"
      io.printf "%s%s:\n", @name, error? ? "[ERROR]" : ""
      io.printf "==> %s\n", tracker_message if tracker_message
      io.printf "--> %s\n", status_message if status_message
      io.printf "%-11s %3d%% [%s%s]\n", @status, @completion_percent, "=" * @completion_percent, "-" * (100 - @completion_percent)
      io.printf "created: %s", time_ago(@created_at)
      if seconds_seeding && seconds_seeding > 0
        io.printf "seeding: %d ", seconds_seeding if seconds_seeding
      end
      io.printf "estimated: %s", estimated_time if estimated_time
      if finished_at
        io.printf " finished: %s", time_ago(finished_at)
        io.printf " elapsed: %s", time_ago(finished_at - @created_at, true)
      end
      io.printf "\n"
      if up_speed && down_speed && 0 < up_speed + down_speed
        io.printf "^ %s    v %s  ", up_speed.inspect, down_speed.inspect
      end
      io.printf "size: %s\n", human_size(@size)
    end

    def to_ansi(io : IO)
      tracker_message = @tracker_message
      status_message = @status_message
      finished_at = @finished_at
      seconds_seeding = @seconds_seeding
      estimated_time = @estimated_time
      up_speed = @up_speed
      down_speed = @down_speed
      io.print "\n"
      io.printf "\e[%d;1m%s:\e[0m\n", error? ? 31 : 34, @name
      io.printf "\e[%d;1m==> %s\e[0m\n", tracker_message.match(/error/i) ? 31 : 32, tracker_message if tracker_message
      io.printf "\e[1m--> %s\e[0m\n", status_message if status_message
      io.printf "\e[1m%-11s %3d%% [\e[0m\e[32m%s\e[0m\e[33m%s\e[0m\e[1m]\e[0m\n", status, @completion_percent, "=" * @completion_percent, "-" * (100 - @completion_percent)
      io.printf "created: \e[34m%s\e[0m", time_ago(@created_at)
      if seconds_seeding && seconds_seeding > 0
        io.printf "seeding: \e[34m%d\e[0m ", seconds_seeding if seconds_seeding
      end
      io.printf "estimated: \e[34m%s\e[0m", estimated_time if estimated_time
      if finished_at
        io.printf " finished: \e[34m%s\e[0m", time_ago(finished_at)
        io.printf " elapsed: \e[34m%s\e[0m", time_ago(finished_at - @created_at, true)
      end
      io.printf "\n"
      if up_speed && down_speed && 0 < up_speed + down_speed
        io.printf "^ %s    v %s  ", up_speed.inspect, down_speed.inspect
      end
      io.printf "size: \e[34m%s\e[0m\n", human_size(@size)
    end

    def percent_complete
      @completion_percent
    end

    def self.register(entry : self)
      @@entries[entry.id] = entry
      entry
    end

    def self.[]?(id : Int64)
      @@entries[id]?
    end

    def self.[](id : Int64)
      @@entries[id]? || raise "no entry with id=#{id}"
    end

    def self.[]=(id : Int64, entry : self)
      raise "ids do not match" unless id == entry.id
      @@entries[entry.id] = entry
    end
  end
end
