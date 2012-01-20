module Xanthan
  class SR < XObject
  
    attr_accessor :sm_config, :physical_size, :virtual_allocation, :content_type, :PBDs, :uuid, :blobs, :name_label, :tags, 
      :physical_utilisation, :allowed_operations, :type, :VDIs, :local_cache_enabled, :shared, :name_description, 
      :current_operations, :other_config



    def initialize(link, ref) #:nodoc:
      super(link, ref)
      @proxy_name = 'VDI'
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
      result = link.client.call("SR.get_record", link.sid, ref)
      
      if result["Status"].downcase =~ /success/
        sr = SR.new(link, ref)
        sr.popuplate_from_response(result["Value"])
        return sr
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
    end #end method self.find(link, ref)
    
    
    
    def self.all(link, limit=0)
      result = link.client.call("SR.get_all", link.sid)
      
      if result["Status"].downcase =~ /success/
        srs = []
        
        if limit > 0
          refs = result["Value"][0, limit]
        else
          refs = result["Value"]
        end
        
        refs.each do |ref|
          sr = SR.find(link, ref)
          srs << sr
        end
        return srs
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
      
    end #end method self.all(link)
    
    
    
    def get_vdis
      link = get_link
      vdi_refs = self.VDIs
      result = []
      vdi_refs.each do |_vdi_ref|
        vdi = VDI.find(link, _vdi_ref)
        result << vdi
      end #end .each
      
      result
    end #end method get_vbds
    

  end #end class Task
end #end module