class PutIO
  module Util
    def time_ago(at : Time::Span, short : Bool = false)
      negative = at == at.abs ? false : true
      at = at.abs
      result = if at.days > 30
                 "%.1f months" % [(at.days / 30.0).round]
               elsif at.days > 0
                 "#{at.days} days"
               elsif at.hours > 0
                 "#{at.hours} hours"
               elsif at.minutes > 0
                 "#{at.minutes} minutes"
               elsif at.seconds > 30
                 # "almost a minute"
                 "#{at.seconds} seconds"
               else
                 "#{at.seconds} seconds"
               end
      if negative
        if short
          return "-#{result}"
        else
          return "#{result} from now"
        end
      else
        if short
          return result
        else
          return "#{result} ago"
        end
      end
    end

    def time_ago(at : Time, short : Bool = false)
      time_ago(Time.utc - at, short)
    end

    def time_ago(seconds : Int32, short : Bool = false)
      time_ago at: Time::Span.new(seconds: seconds), short: short
    end
  end
end
