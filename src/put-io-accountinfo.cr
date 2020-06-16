require "json"

class PutIO
  class AccountInfo
    DEFAULT_TERMINAL_WIDTH = 132

    class DiskInfo
      include JSON::Serializable

      property avail : Int64
      property size : Int64
      property used : Int64

      def initialize(obj : JSON::Any)
        @avail = obj["avail"].as_i64
        @size = obj["size"].as_i64
        @used = obj["used"].as_i64
      end
    end

    class Settings
      include JSON::Serializable

      property beta_user : Bool
      property callback_url : String
      property dark_theme : Bool
      property default_download_folder : Int64
      property fluid_layout : Bool
      property hide_subtitles : Bool
      property history_enabled : Bool
      property is_invisible : Bool
      property locale : String?
      property login_mails_enabled : Bool
      property next_episode : Bool
      property pushover_token : String?
      property sort_by : String
      property start_from : Bool | Int32
      property subtitle_languages : Array(String)
      property theater_mode : Bool
      property transfer_sort_by : String
      property trash_enabled : Bool
      property tunnel_route_name : String?
      property use_private_download_ip : Bool
      property video_player : String?

      def initialize(obj : JSON::Any)
        @beta_user = obj["beta_user"].as_bool
        @callback_url = obj["callback_url"].as_s
        @dark_theme = obj["dark_theme"].as_bool
        @default_download_folder = obj["default_download_folder"].as_i64
        @fluid_layout = obj["fluid_layout"].as_bool
        @hide_subtitles = obj["hide_subtitles"].as_bool
        @history_enabled = obj["history_enabled"].as_bool
        @is_invisible = obj["is_invisible"].as_bool
        @locale = !obj["locale"].nil? && obj["locale"].as_s? ? obj["locale"].as_s : nil
        @login_mails_enabled = obj["login_mails_enabled"].as_bool
        @next_episode = obj["next_episode"].as_bool
        @pushover_token = obj["pushover_token"]? ? obj["pushover_token"].as_s : nil
        @sort_by = obj["sort_by"].as_s
        @start_from = obj["start_from"].as_bool
        @subtitle_languages = obj["subtitle_languages"].as_a.map { |e| e.as_s }
        @theater_mode = obj["theater_mode"].as_bool
        @transfer_sort_by = obj["transfer_sort_by"].as_s
        @trash_enabled = obj["trash_enabled"].as_bool
        @tunnel_route_name = obj["tunnel_route_name"]? ? obj["tunnel_route_name"].as_s : nil
        @use_private_download_ip = obj["use_private_download_ip"].as_bool
        @video_player = !obj["video_player"].nil? && obj["video_player"].as_s? ? obj["video_player"].as_s : nil
      end
    end

    include JSON::Serializable

    property account_active : Bool?
    property avatar_url : String
    property can_create_sub_account : Bool
    property is_eligible_for_friend_invitation : Bool
    property days_until_files_deletion : Int32
    property disk : DiskInfo
    property family_owner : String
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property files_will_be_deleted_at : Time?
    property has_voucher : Bool
    property is_invited_friend : Bool
    property is_sub_account : Bool
    property mail : String
    property oauth_token_id : Int32
    @[JSON::Field(converter: Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local))]
    property plan_expiration_date : Time?
    property private_download_host_ip : String?
    property settings : Settings
    property simultaneous_download_limit : Int32
    property subtitle_languages : Array(String)
    property user_id : Int64
    property username : String

    def initialize(obj : JSON::Any)
      @account_active = obj["account_active"]? ? obj["account_active"].as_bool : nil
      @avatar_url = obj["avatar_url"].as_s
      @can_create_sub_account = obj["can_create_sub_account"]? ? obj["can_create_sub_account"].as_bool : false
      @is_eligible_for_friend_invitation = obj["is_eligible_for_friend_invitation"]? ? obj["is_eligible_for_friend_invitation"].as_bool : false
      @days_until_files_deletion = obj["days_until_files_deletion"]? ? obj["days_until_files_deletion"].as_i : -1
      @disk = DiskInfo.new(obj["disk"])
      @family_owner = obj["family_owner"].as_s
      @files_will_be_deleted_at = !obj["files_will_be_deleted_at"].nil? && obj["files_will_be_deleted_at"].as_i? ? Time.unix(obj["files_will_be_deleted_at"].as_i) : nil
      @has_voucher = obj["has_voucher"].as_bool
      @is_invited_friend = obj["is_invited_friend"].as_bool
      @is_sub_account = obj["is_sub_account"].as_bool
      @mail = obj["mail"].as_s
      @oauth_token_id = obj["oauth_token_id"].as_i
      @plan_expiration_date = obj["plan_expiration_date"]? ? Time::Format.new("%Y-%m-%dT%H:%M:%S", Time::Location.local).parse(obj["plan_expiration_date"].as_s) : nil
      @private_download_host_ip = !obj["private_download_host_ip"].nil? && obj["private_download_host_ip"].as_s? ? obj["private_download_host_ip"].as_s : nil
      @settings = Settings.new(obj["settings"])
      @simultaneous_download_limit = obj["simultaneous_download_limit"].as_i
      @subtitle_languages = obj["subtitle_languages"].as_a.map { |e| e.as_s }
      @user_id = obj["user_id"].as_i64
      @username = obj["username"].as_s
    end

    private def utf8bool(io : IO, value : Bool, label : String, truechar : String = "✔", falsechar : String = "✘", truecolor = 32, falsecolor = 31)
      io.printf "[\e[%dm%s\e[0m\e[%dm %s\e[0m]", value ? truecolor : falsecolor, value ? truechar : falsechar, value ? 1 : 0, label
    end

    private def utf8bool(value : Bool, label : String, truechar : String = "✔", falsechar : String = "✘", truecolor = 32, falsecolor = 31)
      String.build do |str|
        utf8bool io: str, value: value, label: label, truechar: truechar, falsechar: falsechar, truecolor: truecolor, falsecolor: falsecolor
      end
    end

    private def reltime(when : Time?)
      if !when
        "———"
      else
        span = (when - Time.utc).abs
        future = when > Time.utc
        if span.zero?
          text = "now:"
        elsif 0 == span.days + span.hours + span.minutes
          text = "%d seconds" % span.seconds
        elsif 0 == span.days + span.hours
          if span.minutes < 3
            text = "%.1f minutes" % (span.minutes + span.seconds / 60)
          else
            text = "%d minutes" % span.minutes
          end
        elsif 0 == span.days
          if span.hours < 3
            text = "%.1f hours" % (span.hours + span.minutes / 60)
          else
            text = "%d hours" % span.hours
          end
        elsif span.days < 3
          text = "%.1f days" % (span.days + span.hours / 24)
        elsif span.days < 75
          text = "%d days" % span.days
        else
          text = "%d months" % (span.days/30).round
        end
        future ? "in #{text}" : "#{text} ago"
      end
    end

    private def maybe(thing : String?)
      thing || "\e[37m———\e[0m"
    end

    private def human_size(bytes : Int64)
      bytes = bytes.abs
      if bytes < 1024_i64
        "#{bytes}b"
      elsif bytes < 1024_i64**2
        "%.1fK" % (bytes / 1024_i64**1)
      elsif bytes < 1024_i64**3
        "%.1fM" % (bytes / 1024_i64**2)
      elsif bytes < 1024_i64**4
        "%.1fG" % (bytes / 1024_i64**3)
      else
        "%.1fT" % (bytes / 1024_i64**4)
      end
    end

    private def percent_bar(pct : Float64, *, width = DEFAULT_TERMINAL_WIDTH, warning = 0.7, critical = 0.9)
      bar_width = width - 10
      len = (bar_width.to_f64 * pct + 0.5_f64).round.to_i
      if pct >= critical
        color = 31
      elsif pct >= warning
        color = 33
      else
        color = 32
      end
      "%6.2f%% [\e[%d;1m%s\e[0m\e[1m%s\e[0m]" % [
        100.0_f64 * pct,
        color,
        "=" * len,
        "-" * (bar_width - len),
      ]
    end

    private def percent_bar(amount, total, *, width = DEFAULT_TERMINAL_WIDTH, warning = 0.7, critical = 0.9)
      percent_bar(amount.to_f64 / total.to_f64, width: width, warning: warning, critical: critical)
    end

    def to_ansi(io : IO, *, indent : Int32 = 0)
      now = Time.utc
      plan_expiration_date = @plan_expiration_date
      expiration_color = if !plan_expiration_date
                           31
                         elsif plan_expiration_date > now + 90.days
                           0
                         elsif plan_expiration_date > now + 7.days
                           33
                         else
                           31
                         end
      i = "  " * indent
      io.printf "#{i}\e[34;1mPutIO:\e[0m \e[1m%s\e[0m - %s - %d [%s]", @username, @mail, @user_id, utf8bool(@account_active || false, "Active")
      io.printf " \e[%dm%s %s\e[0m", expiration_color, plan_expiration_date > now ? "Expires" : "Expired", reltime(plan_expiration_date) if plan_expiration_date
      io.print "\n"
      io.printf "#{i}%s\n", percent_bar(disk.used, disk.size)
      io.printf "#{i}%s/%s (%6.2f%%) used, %s (%6.2f%%) avail\n",
        human_size(disk.used), human_size(disk.size), 100_f32 * disk.used / disk.size,
        human_size(disk.avail), 100_f32 * disk.avail / disk.size
      io.printf "%s  %s  %s  %s\n",
        utf8bool(@is_eligible_for_friend_invitation || false, "CanBeInvited"),
        utf8bool(@is_invited_friend || false, "IsInvited"),
        utf8bool(@is_sub_account || false, "SubAccount"),
        utf8bool(@has_voucher || false, "HasVoucher")
      io.printf "#{i}Private Download IP: %s\n", private_download_host_ip if private_download_host_ip = @private_download_host_ip
    end

    def to_ansi(*, indent : Int32 = 0)
      String.build do |str|
        to_utf8 io: str, indent: indent
      end
    end

    def to_s(io : IO = STDOUT, *, indent : String | Int32 = 0)
      i : String
      i = case indent
          when String
            indent
          else
            "  " * indent
          end
      io.printf "#{i}account_active = %s\n", @account_active.inspect if @account_active
      io.printf "#{i}avatar_url = %s\n", @avatar_url
      io.printf "#{i}can_create_sub_account = %s\n", @can_create_sub_account
      io.printf "#{i}is_eligible_for_friend_invitation = %s\n", @is_eligible_for_friend_invitation
      io.printf "#{i}days_until_files_deletion = %s\n", @days_until_files_deletion if @days_until_files_deletion >= 0
      io.printf "#{i}disk = {\n#{i}  avail: %d\n#{i}   size: %d\n#{i}   used: %d\n#{i}}\n", @disk.avail, @disk.size, @disk.used
      io.printf "#{i}family_owner = %s\n", @family_owner
      io.printf "#{i}files_will_be_deleted_at = %s\n", @files_will_be_deleted_at if @files_will_be_deleted_at
      io.printf "#{i}has_voucher = %s\n", @has_voucher
      io.printf "#{i}is_invited_friend = %s\n", @is_invited_friend
      io.printf "#{i}is_sub_account = %s\n", @is_sub_account
      io.printf "#{i}mail = %s\n", @mail
      io.printf "#{i}oauth_token_id = %d\n", @oauth_token_id
      io.printf "#{i}plan_expiration_date = %s\n", @plan_expiration_date if @plan_expiration_date
      io.printf "#{i}private_download_host_ip = %s\n", @private_download_host_ip if @private_download_host_ip
      io.printf "#{i}settings = {\n"
      io.printf "#{i}  beta_user = %s\n", @settings.beta_user
      io.printf "#{i}  callback_url = %s\n", @settings.callback_url
      io.printf "#{i}  dark_theme = %s\n", @settings.dark_theme
      io.printf "#{i}  default_download_folder = %d\n", @settings.default_download_folder
      io.printf "#{i}  fluid_layout = %s\n", @settings.fluid_layout
      io.printf "#{i}  hide_subtitles = %s\n", @settings.hide_subtitles
      io.printf "#{i}  history_enabled = %s\n", @settings.history_enabled
      io.printf "#{i}  is_invisible = %s\n", @settings.is_invisible
      io.printf "#{i}  locale = %s\n", @settings.locale if @settings.locale
      io.printf "#{i}  login_mails_enabled = %s\n", @settings.login_mails_enabled
      io.printf "#{i}  next_episode = %s\n", @settings.next_episode
      io.printf "#{i}  pushover_token = %s\n", @settings.pushover_token if @settings.pushover_token
      io.printf "#{i}  sort_by = %s\n", @settings.sort_by
      io.printf "#{i}  start_from = %d\n", @settings.start_from if @settings.start_from.is_a?(Int32)
      io.printf "#{i}  start_from = %s\n", @settings.start_from if @settings.start_from.is_a?(Bool)
      io.printf "#{i}  subtitle_languages = %s\n", @settings.subtitle_languages.join(", ") if @settings.subtitle_languages.size > 0
      io.printf "#{i}  subtitle_languages = []\n" if @settings.subtitle_languages.size == 0
      io.printf "#{i}  theater_mode = %s\n", @settings.theater_mode
      io.printf "#{i}  transfer_sort_by = %s\n", @settings.transfer_sort_by
      io.printf "#{i}  trash_enabled = %s\n", @settings.trash_enabled
      io.printf "#{i}  tunnel_route_name = %s\n", @settings.tunnel_route_name if @settings.tunnel_route_name
      io.printf "#{i}  use_private_download_ip = %s\n", @settings.use_private_download_ip
      io.printf "#{i}  video_player = %s\n", @settings.video_player if @settings.video_player
      io.printf "#{i}}\n"
      io.printf "#{i}simultaneous_download_limit = %d\n", simultaneous_download_limit
      io.printf "#{i}subtitle_languages = %s\n", @subtitle_languages.join(", ") if @subtitle_languages.size > 0
      io.printf "#{i}subtitle_languages = []\n" if @subtitle_languages.size == 0
      io.printf "#{i}user_id = %d\n", @user_id
      io.printf "#{i}username = %s\n", @username
    end
  end
end
