module Xanthan
  class Disk
  
    attr_reader :device, :size, :type, :sr, :bootable
  
    def initialize(device, size, type, sr, bootable)
      @device = device
      @size = size
      @type = type
      @sr = sr
      @bootable = bootable
    end #end method initialize(device, size, sr, bootable)
  
  
    def sr=(val)
      @sr = val
    end #end method sr=(val)
  
  
    def to_element
      get_builder.disk(:device => @device, :size => @size, :type => @type, :sr => @sr, :bootable => @bootable)
    end #end method to_element(builder)
  
  
    def self.disk_from_xml(element)
      d = element.attributes["device"]
      s = element.attributes["size"]
      t = element.attributes["type"]
      sr = element.attributes["sr"]
      b = element.attributes["bootable"]
      return Disk.new(d,s,t,sr,b)
    end #end method self.disk_from_xml(element)
  
    private
  
    def get_builder
      Builder::XmlMarkup.new(:target => "", :indent => 1)
    end #end method get_builder
  
  end #end class Disk
end #end module