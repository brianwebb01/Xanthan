module Xanthan
  class ProvisionSpec
  
    attr_reader :disks
  
    def initialize
      @disks = []
    end #end method initialize
  
    def disks=(d)
      @disks = d
    end #end method disks=(d)
  
    def to_element
      get_builder.provision do |p|
        @disks.each do |disk|
          p << disk.to_element
        end
      end
    end #end method to_element(builder)
  
    def set_sr(sr)
      @disks.each do |disk|
        disk.sr = sr
      end
    end #end method set_sr(sr)
  
  
    private
  
    def get_builder
      Builder::XmlMarkup.new(:target => "", :indent => 1)
    end #end method get_builder
  
  end #end class ProvisionSpec
end #end module