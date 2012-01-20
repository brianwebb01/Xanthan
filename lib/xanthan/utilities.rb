module Xanthan
  class Utilities
  
    def self.humanize_bytes(bytes)
      m = bytes.to_i
      units = %w[Bits Bytes MB GB TB PB]
      while (m/1024.0) >= 1 
        m = m/1024.0
        units.shift
      end
      return m.round.to_s + " #{units[0]}"
    end
  
  
    def self.GB(gb)
      gb*1073741824
    end
  
    def self.MB(mb)
      mb*1048576
    end
  
  
    def self.KB(kb)
      kb*1024
    end
  
  
    def self.make_time(t)
      return "" if t == nil
    
      #20090728T20:33:32Z
      date = t.split("T").first
      time = t.split("T").last.gsub("Z", "").split(":")
      y  = date[0,4]
      m  = date[4,2]
      d  = date[6,2]
      h  = time[0]
      mi = time[1]
      s  = time[2]
      Time.utc(y,m,d,h,mi,s)
    end
  
  end #end class util
end #end module