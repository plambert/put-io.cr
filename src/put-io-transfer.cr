require "json"

class PutIO
  class Transfer
    enum Status
      IN_QUEUE
      WAITING
      DOWNLOADING
      COMPLETING
      SEEDING
      COMPLETED
      ERROR
    end

    enum TransferType
      TORRENT
      URL
      PLAYLIST
    end

    class EnumConverter(T)
      def self.from_json(json : JSON::PullParser)
        T.parse(json.read_string)
      end

      def self.to_json(value : T, builder : JSON::Builder)
        json.string(value.to_s)
      end
    end

    include JSON::Serializable
    property availability : Int32
    property callback_url : String?
    property client_ip : String
    property completion_percent : Int32
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property created_at : Time
    property created_torrent : Bool
    property current_ratio : Float32
    property downloaded : Int32
    property download_id : Int32
    property down_speed : Int32
    property error_message : String?
    property estimated_time : Int32?
    property file_id : Int32?
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property finished_at : Time?
    property hash : String
    property id : Int32
    property is_private : Bool
    property name : String
    property peers : Int32
    property peers_connected : Int32
    property peers_getting_from_us : Int32
    property peers_sending_to_us : Int32
    property percent_done : Int32
    property save_parent_id : Int32
    property seconds_seeding : Int32?
    property simulated : Bool?
    property size : Int32
    property source : String
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property started_at : Time?
    @[JSON::Field(converter: EnumConverter(Status))]
    property status : Status
    property status_message : String
    property subscription_id : Int32?
    property torrent_link : String
    property tracker : String
    property tracker_message : String?
    @[JSON::Field(converter: EnumConverter(TransferType))]
    property type : TransferType
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property updated_at : Time?
    property uploaded : Int32
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
        if cached = PutIO::Entry[obj["id"].as_i64]?
          return cached
        end
      end
      obj["name"] = JSON::Any.new "/" if !obj["parent_id"]? || obj["parent_id"].as_i64? == -1_i64
      time_format = Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.load("UTC"))
      register new(
        id: obj["id"].as_i64,
        child_ids: obj["child_ids"]? ? obj["child_ids"].as_a.map { |id| id.as_i64 }.sort!.uniq! : nil,
        content_type: obj["content_type"].as_s,
        crc32: obj["crc32"].as_s?,
        created_at: time_format.parse(obj["created_at"].as_s),
        extension: obj["extension"].as_s?,
        file_type: obj["file_type"].as_s?,
        first_accessed_at: obj["first_accessed_at"]? && obj["first_accessed_at"].as_s? ? time_format.parse(obj["first_accessed_at"].as_s) : nil,
        folder_type: obj["folder_type"].as_s,
        icon: obj["icon"].as_s,
        indexed_at: obj["indexed_at"]? && obj["indexed_at"].as_s? ? time_format.parse(obj["indexed_at"].as_s) : Time.utc,
        is_hidden: obj["is_hidden"].as_bool,
        is_mp4_available: obj["is_mp4_available"].as_bool,
        is_shared: obj["is_shared"].as_bool,
        name: obj["name"].as_s,
        opensubtitles_hash: obj["opensubtitles_hash"].as_s?,
        parent_id: obj["parent_id"]? ? obj["parent_id"].as_i64? || -1_i64 : -1_i64,
        screenshot: obj["screenshot"]? ? obj["screenshot"].as_s? : nil,
        size: obj["size"].as_i64,
        start_from: obj["start_from"]? ? obj["start_from"].as_i64 : 0_i64,
        updated_at: time_format.parse(obj["updated_at"].as_s),
      )
    end

    def list
      page = 1
      count = 0
      response = self.get "transfers/list"
      result = response.parse
      STDERR.puts "transfers(#{page}: #{query.inspect}) = #{result}" if PutIO.verbose
      if result["transfers"]?
        result["transfers"].as_a.each do |f|
          entry = PutIO::Transfer.new(f.as_h)
          if entry
            yield entry
            count += 1
          end
        end
      end
      STDERR.print "list: #{page}: #{count} entries"
      STDERR.print ", continued" if result["cursor"]?
      STDERR.print "\n"
      while result["cursor"]? && result["cursor"].as_s?
        cursor = result["cursor"].as_s
        page += 1
        STDERR.puts "list(#{page}: #{query.inspect}) = #{result}" if PutIO.verbose
        continue_response = self.post "files/list/continue", form: {"cursor" => cursor, "per_page" => per_page.to_s}
        result = continue_response.parse
        if result["files"]?
          result["files"].as_a.each do |f|
            entry = PutIO::Entry.new(f.as_h)
            if entry
              yield entry
              count += 1
            end
          end
        end
        STDERR.print "list: #{page}: #{count} entries"
        STDERR.print ", continued" if result["cursor"]?
        STDERR.print "\n"
      end
      count
    end
  end
end
