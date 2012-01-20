module Xanthan
  class VDI < XObject
  
    attr_accessor :managed, :sm_config, :allow_caching, :read_only, :location, :parent, :sharable, 
      :xenstore_data, :uuid, :name_label, :storage_lock, :allowed_operations, :physical_utilisation, 
      :is_a_snapshot, :tags, :type, :snapshots, :crash_dumps, :name_description, :current_operations, 
      :SR, :VBDs, :snapshot_of, :on_boot, :virtual_size, :other_config, :missing, :snapshot_time


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
    
    
    
    def get_vbds
      link = get_link
      vbd_refs = self.VBDs
      result = []
      vbd_refs.each do |_vbd_ref|
        vbd = VBD.find(link, _vbd_ref)
        result << vbd
      end #end .each
      
      result
    end #end method get_vbds


    def get_vm
      vm_refs = []
      _vbds = get_vbds
      _vbds.each do |_vbd|
        vm_refs << _vbd.VM
      end
      vm_refs.uniq!
      
      _vms = []
      vm_refs.each do |_vm_ref|
        _vms << VM.new(get_link, _vm_ref)
      end
      
      if _vms.size == 1
        return _vms.first
      else
        return _vms
      end
      
    end #end method get_vm
    
    
    
    def self.find(link, ref)
      result = link.client.call("VDI.get_record", link.sid, ref)
      
      if result["Status"].downcase =~ /success/
        vdi = VDI.new(link, ref)
        vdi.popuplate_from_response(result["Value"])
        return vdi
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
    end #end method self.find(link, ref)
    
    
    
    def self.all(link, limit=0)
      result = link.client.call("VDI.get_all", link.sid)
      
      if result["Status"].downcase =~ /success/
        vdis = []
        
        if limit > 0
          refs = result["Value"][0, limit]
        else
          refs = result["Value"]
        end
        
        refs.each do |ref|
          v = VDI.find(link, ref)
          vdis << v
        end
        return vdis
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
      
    end #end method self.all(link)
    
    
    
    def do_destroy
    
      link = get_link
    
      begin
        result = link.client.call("VDI.destroy", link.sid, get_ref)
      
        if result["Status"].downcase =~ /success/
          return result["Value"]
        end
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VDI. (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method do_clone(new_name)
    
    
    def do_destroy_async
      link = get_link
      result = link.client.call("Async.VDI.destroy", link.sid, get_ref)
      process_async_result(result)
    end #end method do_destroy_async

    
  
  end #end class Task
end #end module