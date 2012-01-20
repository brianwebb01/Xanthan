module Xanthan
  class VBD < XObject
  

    attr_accessor :device, :qos_algorithm_type, :qos_supported_algorithms, :VM, :status_detail, 
      :uuid, :userdevice, :mode, :unpluggable, :storage_lock, :qos_algorithm_params, :allowed_operations, 
      :VDI, :metrics, :type, :empty, :status_code, :runtime_properties, :current_operations, 
      :currently_attached, :bootable, :other_config


    def initialize(link, ref) #:nodoc:
      super(link, ref)
      @proxy_name = 'VBD'
    end
  
  
  
    def popuplate_from_response(values={})
      values.each do |k,v|
        if v.class == XMLRPC::DateTime
          instance_variable_set "@#{k}", v.to_time
        else
          instance_variable_set "@#{k}", v
        end
      end #end each
      
    end #end method initialize
   
    
    
    def self.find(link, ref)
      result = link.client.call("VBD.get_record", link.sid, ref)
      
      if result["Status"].downcase =~ /success/
        vbd = VBD.new(link, ref)
        vbd.popuplate_from_response(result["Value"])
        return vbd
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
    end #end method self.find(link, ref)
    
    
    
    def self.all(link)
      result = link.client.call("VBD.get_all", link.sid)
      
      if result["Status"].downcase =~ /success/
        vbds = []
        result["Value"].each do |ref|
          v = VBD.find(link, ref)
          vbds << v
        end
        return vbds
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
      
    end #end method self.all(link)
    
    
  
  end #end class Task
end #end module