require "json"

class PutIO
  class CLI
    class Config
      struct Profile
        app_id : String?
        application_secret : String?
        token : String?
      end

      property configfile : Path
      property profiles : Hash(String, Profile | String) = {} of String => Profile | String
      property aliases : Hash(String, String)
      property profile : String?
      property verbose : Bool = false
      property putio : PutIO? = nil
      property io : IO = STDOUT
      property output_format : PutIO::CLI::OutputFormat = PutIO::CLI::OutputFormat::Auto
      property output_file : Path? = nil

      def initialize(configfile : Path | String | Nil, *, @profile = nil, @verbose, @putio, @io, @output_format, @output_file)
        if configfile
          @configfile = Path[configfile]
          @aliases = {} of String => String
          input = File.read(@configfile)
          config = JSON.parse(input)
          raise "#{@configfile} must contain a valid JSON object, not " + type(config.raw) unless config.as_h?
          config.as_h.each do |k, v|
            if v.as_s?
              @aliases[k] = v
            elsif v.as_h?
              profiles[k] = Profile.new(app_id: v["app_id"]?, application_secret: v["application_secret"]?, token: v["token"]?)
            else
              raise "unexpected #{v.class} for profile #{k.inspect} in config file"
            end
          end
          @aliases.each do |k, v|
            if !profiles[v]?
              raise "alias #{k.inspect} points to non-existent profile #{v.inspect}"
            end
          end
        end
      end

      def []?(profile : String)
        if aliases[profile]?
          profiles[aliases[profile]]?
        else
          profiles[profile]?
        end
      end

      def [](profile : String)
        for?(profile) || raise "invalid profile: #{profile}"
      end

      def token?(profile : String? = @profile)
        raise "no current profile defined, and no profile given" unless profile
        while profile_alias = @aliases[profile]?
          profile = profile_alias
        end
        if @profiles[profile]?
          @profiles[profile].token
        else
          nil
        end
      end

      def token(profile : String? = @profile)
        raise "no current profile defined, and no profile given" unless profile
        self.token?(profile) || raise "no token defined for #{profile.inspect}"
      end

      def application_secret?(profile : String? = @profile)
        raise "no current profile defined, and no profile given" unless profile
        while profile_alias = @aliases[profile]?
          profile = profile_alias
        end
        if @profiles[profile]?
          @profiles[profile].application_secret
        else
          nil
        end
      end

      def application_secret(profile : String? = @profile)
        raise "no current profile defined, and no profile given" unless profile
        self.application_secret?(profile) || raise "no application_secret defined for #{profile.inspect}"
      end

      def app_id?(profile : String? = @profile)
        raise "no current profile defined, and no profile given" unless profile
        while profile_alias = @aliases[profile]?
          profile = profile_alias
        end
        if @profiles[profile]?
          @profiles[profile].app_id
        else
          nil
        end
      end

      def app_id(profile : String? = @profile)
        raise "no current profile defined, and no profile given" unless profile
        self.app_id?(profile) || raise "no app_id defined for #{profile.inspect}"
      end
    end
  end
end
