require "halite"
require "./put-io-entry"
require "./put-io-accountinfo"

class PutIO
  VERSION  = "0.1.0"
  PER_PAGE = 1000
  alias QueryParamsType = Hash(String, String | Int32 | Bool | Array(String | Int32 | Bool))
  class_property verbose : Bool = false
  class_property sort_keys : Array(String) = %w{NAME_ASC NAME_DESC SIZE_ASC SIZE_DESC DATE_ASC DATE_DESC MODIFIED_ASC MODIFIED_DESC}
  class_property file_types : Array(String) = %w{FOLDER FILE AUDIO VIDEO IMAGE ARCHIVE PDF TEXT SWF}

  property client_id : Int64?
  property application_secret : String?
  property token : String
  property dbfile : Path
  property client : Halite::Client

  def self.verbose
    @@verbose
  end

  def self.verbose(value : Bool)
    @@verbose = value
    value
  end

  def initialize(@token, @dbfile, @client_id = nil, @application_secret = nil, client : Halite::Client? = nil)
    if client
      @client = client
    else
      @client = Halite::Client.new do
        # timeout 60.seconds
        user_agent "crystal/put.io/#{VERSION}"
        headers authorization: "Bearer #{@token}"
        endpoint "https://api.put.io/v2"
      end
      # @client.timeout(10)
    end
  end

  def by_id?(id : Int64)
    cached = PutIO::Entry[id]?
    return cached if cached
    page = 1
    STDERR.puts "+++ GET /files/list?per_page=#{PutIO::PER_PAGE}&parent_id=#{id}" if PutIO.verbose
    result = self.get("files/list", params: {"parent_id" => id.to_s, "per_page" => PutIO::PER_PAGE}).parse
    if result && result["parent"]?
      attributes = result["parent"].as_h
      if result["files"]? && result["files"].as_a?
        child_ids = result["files"].as_a.compact_map { |c| c["id"].as_i64? }
        while result["cursor"]? && result["cursor"].as_s?
          cursor = result["cursor"].as_s
          page += 1
          result = self.post("files/list/continue", form: {"cursor" => cursor, "per_page" => "#{PutIO::PER_PAGE}"}).parse
          STDERR.puts "list(#{page}: id=#{id}) = #{result}" if PutIO.verbose
          child_ids += result["files"].as_a.compact_map { |c| c["id"].as_i64? } if result["files"]? && result["files"].as_a?
        end
        attributes["child_ids"] = JSON::Any.new child_ids.sort!.uniq!.map { |id| JSON::Any.new id }
      else
        attributes["child_ids"] = JSON::Any.new [] of JSON::Any
      end
      entry = PutIO::Entry.new(attributes)
      entry.set_path?(self)
      return entry
    end
    return nil
  end

  def by_id(id : Int64)
    by_id?(id) || raise "#{id}: entry not found"
  end

  def root
    by_id?(0)
  end

  def find_child_by_name?(parent_id : Int64, name : String)
    parent = by_id(parent_id)
    child_ids = parent.child_ids
    return nil unless child_ids
    child_ids.each do |child_id|
      child = by_id(child_id)
      if child.name == name
        STDERR.puts "--- matched '#{child.name}' against '#{name}'" if PutIO.verbose
        return child_id
      else
        STDERR.puts "--- failed match: '#{child.name}' against '#{name}" if PutIO.verbose
      end
    end
    return nil
  end

  def find_child_by_name(parent_id : Int64, name : String)
    find_child_by_name?(parent_id: parent_id, name: name) || raise "#{parent_id}: no child with name #{name.inspect}"
  end

  private def by_path_real(path : String)
    raise "empty path is invalid" unless path.size > 0
    found_segments = [] of String
    segments = path.sub(%r{^/+}, "").gsub(%r{//+}, "/").split("/")
    STDERR.puts "path: fetch root (0)" if PutIO.verbose
    parent_id = 0_i64
    segments.each do |segment|
      if child_id = find_child_by_name? parent_id, segment
        found_segments << segment
        parent_id = child_id
      else
        return found_segments
      end
    end
    return parent_id
  end

  def by_path?(path : String)
    result = by_path_real(path)
    case result
    when Int64
      return by_id(result)
    else
      return nil
    end
  end

  def by_path(path : String)
    result = by_path_real(path)
    case result
    when Int64
      return by_id(result)
    else
      raise "#{path}: path not found, failed after: #{("/" + result.join("/")).inspect}"
    end
  end

  def children(id : Int64)
    by_id(id).child_ids.map { |id| by_id(id) }
  end

  def account_info
    info = self.get("account/info").body
    STDERR.puts "AccountInfo = #{info}" if PutIO.verbose
    PutIO::AccountInfo.from_json info, root: "info"
  end

  def account_settings
    info = self.get("account/settings").parse["info"]
    STDERR.puts "AccountSettings = #{info}" if PutIO.verbose
    PutIO::AccountInfo::Settings.new info
  end

  def tree(
    parent_id : Int32 = -1,
    *,
    per_page : Int32 = PutIO::PER_PAGE,
    sort_by : String? = nil,
    file_types : Array(String)? = nil,
    stream_url : Bool = false,
    stream_url_parent : Bool = false,
    mp4_stream_url : Bool = false,
    mp4_stream_url_parent : Bool = false,
    hidden : Bool = false,
    mp4_status : Bool = false
  )
    tree = {} of String => PutIO::Entry
    list = self.list(
      parent_id: parent_id,
      per_page: per_page,
      sort_by: sort_by,
      file_types: file_types,
      stream_url: stream_url,
      stream_url_parent: stream_url_parent,
      mp4_stream_url: mp4_stream_url,
      mp4_stream_url_parent: mp4_stream_url_parent,
      hidden: hidden,
      mp4_status: mp4_status
    )
    list.each do |entry|
      cids = entry.child_ids
      entry.set_path(self) if entry.file? || !cids || (cids && cids.size == 0)
      tree[entry.path] = entry
    end
    tree
  end

  def list(
    parent_id : Int32 = -1,
    *,
    per_page : Int32 = PutIO::PER_PAGE,
    sort_by : String? = nil,
    file_types : Array(String)? = nil,
    stream_url : Bool = false,
    stream_url_parent : Bool = false,
    mp4_stream_url : Bool = false,
    mp4_stream_url_parent : Bool = false,
    hidden : Bool = false,
    mp4_status : Bool = false
  )
    entries = [] of PutIO::Entry
    self.list(
      parent_id: parent_id,
      per_page: per_page,
      sort_by: sort_by,
      file_types: file_types,
      stream_url: stream_url,
      stream_url_parent: stream_url_parent,
      mp4_stream_url: mp4_stream_url,
      mp4_stream_url_parent: mp4_stream_url_parent,
      hidden: hidden,
      mp4_status: mp4_status
    ) do |entry|
      entries << entry
    end
    entries.each { |e| cids = e.child_ids; e.set_path(self) if e.file? || !cids || (cids && cids.size == 0) }
    entries
  end

  def list(
    parent_id : Int32 = -1,
    *,
    per_page : Int32 = PutIO::PER_PAGE,
    sort_by : String? = nil,
    file_types : Array(String)? = nil,
    stream_url : Bool = false,
    stream_url_parent : Bool = false,
    mp4_stream_url : Bool = false,
    mp4_stream_url_parent : Bool = false,
    hidden : Bool = false,
    mp4_status : Bool = false
  )
    page = 1
    count = 0
    query = QueryParamsType.new
    query["per_page"] = per_page
    query["parent_id"] = parent_id
    query["sort_by"] = sort_by if sort_by
    query["file_types"] = file_types if file_types
    query["stream_url"] = stream_url if stream_url
    query["stream_url_parent"] = stream_url_parent if stream_url_parent
    query["mp4_stream_url"] = mp4_stream_url if mp4_stream_url
    query["mp4_stream_url_parent"] = mp4_stream_url_parent if mp4_stream_url_parent
    query["hidden"] = hidden if hidden
    query["mp4_status"] = mp4_status if mp4_status
    root = self.root
    yield root if root
    response = self.get "files/list", params: query
    result = response.parse
    STDERR.puts "list(#{page}: #{query.inspect}) = #{result}" if PutIO.verbose
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

  private def get(path : String, *, params : QueryParamsType = QueryParamsType.new)
    response = @client.get path, params: params
    if response.status_code != 200
      raise "#{path}: #{response.status_code}: request failed:\n#{response.inspect}\n#{response.body.inspect}"
    end
    response
  end

  private def post(path : String, *, form : Hash(String, String))
    response = @client.post path, form: form
    if response.status_code != 200
      raise "#{path}: #{response.status_code}: request_failed\nsent: #{form}\n#{response.inspect}\n#{response.body.inspect}"
    end
    response
  end
end
