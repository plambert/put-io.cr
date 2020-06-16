require "json"

class PutIO
  class Entry
    alias ChildrenMap = Hash(Int64, Array(Int64))
    class_property columns : Array(String) = %w{
      id child_ids content_type crc32 created_at extension file_type first_accessed_at folder_type icon
      indexed_at is_hidden is_mp4_available is_shared name opensubtitles_hash parent_id
      screenshot size start_from updated_at
    }
    class_property entries : Hash(Int64, self) = {} of Int64 => self
    include JSON::Serializable
    property id : Int64
    property child_ids : Array(Int64)? = nil
    property content_type : String
    property crc32 : String?
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property created_at : Time
    property extension : String?
    property file_type : String?
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property first_accessed_at : Time?
    property folder_type : String
    property icon : String
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property indexed_at : Time
    property is_hidden : Bool
    property is_mp4_available : Bool
    property is_shared : Bool
    setter name : String
    property opensubtitles_hash : String?
    property parent_id : Int64
    @[JSON::Field(key: "path")]
    property _path : String? = nil
    property screenshot : String?
    property size : Int64
    property start_from : Int64
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property updated_at : Time

    def name
      @name = "/" if @parent_id == -1_i64
      @name
    end

    def set_path?(putio : PutIO)
      if !@_path
        if !@parent_id || @parent_id == -1_i64
          new_path = ""
        elsif @@entries[@parent_id]?
          new_path = @@entries[@parent_id].set_path(putio) + @name
        else
          parent = putio.by_id(@parent_id)
          new_path = parent.set_path(putio) + @name
        end
        file_type = @file_type
        if file_type && file_type == "FOLDER"
          @_path = new_path + "/"
        else
          @_path = new_path
        end
      end
      @_path
    end

    def set_path(putio)
      set_path?(putio) || raise "failed to set path"
    end

    def path
      @_path || raise "path not calculated"
    end

    def path?
      @_path
    end

    def initialize(@id, @child_ids, @content_type, @crc32, @created_at, @extension, @file_type,
                   @first_accessed_at, @folder_type, @icon, @indexed_at, @is_hidden,
                   @is_mp4_available, @is_shared, @name, @opensubtitles_hash,
                   @parent_id, @screenshot, @size, @start_from, @updated_at)
      self.class.register self
    end

    def self.new(obj : Hash(String, JSON::Any))
      if obj["id"]? && obj["id"].as_i64?
        cached = PutIO::Entry[obj["id"].as_i64]?
        return cached if cached
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

    def folder?
      ft = @file_type
      if ft
        ft == "FOLDER"
      else
        false
      end
    end

    def file?
      !folder?
    end

    def register_children(ids : Array(Int64))
      @child_ids ||= [] of Int64
      @child_ids << ids
      @child_ids.sort!.uniq!
      STDERR.puts "#{@id}: children = #{@child_ids}" if PutIO.verbose
    end

    def each_child_id
      if ids = @child_ids
        ids.each do |id|
          yield id
        end
      end
    end

    def self.known_ids
      @@entries.keys.sort
    end

    def self.[]?(id : Int64)
      @@entries[id]?
    end

    def self.[](id : Int64)
      @@entries[id]? || raise "no entry with id=#{id}"
    end

    def self.register(entry : self)
      @@entries[entry.id] = entry
      entry.name = "/" if entry.parent_id == -1_i64
      entry
    end

    def self.[]=(id : Int64, entry : self)
      raise "ids do not match" unless id == entry.id
      @@entries[entry.id] = entry
    end
  end
end
