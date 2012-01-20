module Xanthan
  class VM < XObject
  
=begin
    ~~ instance methods directly linked to xenapi ~~
    + pause
    + unpause
    + suspend (requires PV Drivers)
    + resume (requires PV Drivers)
    + resume_on (requires PV Drivers)
    + snapshot_with_quiesce (must be supported)
=end
  

    def initialize(link, ref) #:nodoc:
      super(link, ref)
      @proxy_name = 'VM'
      update_record_data
      @provision_task_id = nil
    end
  
  
    def self.all(link)
      vm_collection = []
      result = link.client.call("VM.get_all", link.sid)
      
      if result["Status"].downcase =~ /success/
        result["Value"].each do |_vm_ref|
          vm_collection << VM.new(link, _vm_ref)
        end #end .each
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
      
      return vm_collection
      
    end #end method self.all(link)
  

    def self.find_by_uuid(link, uuid)
      begin
        result = link.client.call("VM.get_by_uuid", link.sid, uuid)
      
        if result["Status"].downcase =~ /success/
          return VM.new(link, result["Value"])
        end
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    
    end #end method self.find_by_uuid(link, uuid)
  
  
  
  
    def self.print_templates(link, filter_str=nil)
      begin
        result = link.client.call("VM.get_all_records", link.sid)
      
        if result["Status"].downcase =~ /success/
          vms = result["Value"]
          vms.each do |k,v|
          
          
            print_info = Proc.new do 
              puts v["name_label"]
              puts k
              puts v["uuid"]
              puts "Template" if v["is_a_snapshot"] == false
              puts "Snapshot" if v["is_a_snapshot"] == true
              puts "\n\n"
            end #end proc
          
          
            if v["is_a_template"] == true && v["is_control_domain"] == false
          
              if filter_str.nil?
                print_info.call
              else
                regex = Regexp.new(filter_str, Regexp::IGNORECASE)
                if regex.match(v["name_label"])
                  print_info.call
                end
              end
            
            end #end if
          
          
          end #end each
        end #end if result
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    
    end #end print_templates
  
  
  
    def self.create_new_from_snapshot(link, snapshot_uuid, new_vm_name)
      
      snapshot = VM.find_by_uuid(link, snapshot_uuid)
      new_vm_ref = snapshot.do_clone(new_vm_name)
      new_vm = VM.new(link, new_vm_ref)
      new_vm.set_PV_args("noninteractive")
      new_vm.provision
      #new_vm.startup
      new_vm.startup_async
      
      return new_vm
  
    end #end method self.create_new_from_snapshot(link, snapshot_uuid)
  
  
  
    def self.create_new_from_template(link, template_uuid, new_name)
    
      begin
      
        # first we want to choose the primary interface this VM will use
        # (we assume that plugging the new VM's VIF into the same network will
        # allow it to get an IP with DHCP)
        result = link.client.call("PIF.get_all_records", link.sid)
      
        if result["Status"].downcase =~ /success/
        
          pifs = result["Value"]
          valid_pif_hash = pifs.reject {|k1,v1| v1["IP"] == "" } #valid == having an IP
        
          #get refs to the pif & pif's network
          pif_ref = pifs.reject {|k1,v1| v1["IP"] == "" }.keys.first
          pif_network_ref = valid_pif_hash.values.first["network"]
        
          #Create the new VM from the template with the given UUID
          vm_template = VM.find_by_uuid(link, template_uuid)
          new_vm_ref = vm_template.do_clone(new_name)
          new_vm = VM.new(link, new_vm_ref)
        
          #create the VIF
          vif = { 
            'device' => '0',
            'network' => pif_network_ref,
            'VM' => new_vm_ref,
            'MAC' => "",
            'MTU' => "1500",
            "qos_algorithm_type" => "",
            "qos_algorithm_params" => {},
            "other_config" => {} 
          }
          link.client.call("VIF.create", link.sid, vif)
        
          #add noninteractive to the kernel commandline
          link.client.call("VM.set_PV_args", link.sid, new_vm_ref, "noninteractive")
        
          #choose a SR to instantiate the VM's disks
          pool_ref = link.client.call("pool.get_all", link.sid)["Value"].first
          default_sr_ref = link.client.call("pool.get_default_SR", link.sid, pool_ref)["Value"]
          default_sr = link.client.call("SR.get_record", link.sid, default_sr_ref)["Value"]
          default_sr_uuid = default_sr["uuid"]
        
          #rewriting the disk provisioning xml
          spec = new_vm.get_provision_spec
          spec.set_sr(default_sr_uuid)
          new_vm.set_provision_spec(spec)
        
          #asking the server to provision storage from the template specification
          #doing so with an async task
          task_result = link.client.call("Async.VM.provision", link.sid, new_vm_ref)
          if task_result["Status"].downcase =~ /success/
            new_vm.provision_id = task_result["Value"]
          else
            raise XenApiError.new(task_result["ErrorDescription"])
          end
        
        
          new_vm.provision_then_startup
        
          return new_vm
        
        end #end if success
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    
    end #end create_new_from_template
  
  
  
    def provision_id=(id)
      @provision_task_id = id
    end #end method provision_id=(id)
  
  
  
    def provision_then_startup
      t1 = Thread.new("#{get_record_data["uuid"]}-provision_then_startup") do 
      
        while provision_status == "pending" do 
          clear = "\e[K"
          print "\rProvisioning: #{provision_progress}% completed#{clear}"
          sleep 2
        end
      
        startup if provision_status == "success"
      
      end #end thread
      t1.join
    end #end method provision_then_startup
  
  
  
  
    def get_record_data
      @vm_record
    end #end method get_record_data
  
  
  
  
    def update_record_data
      @vm_record = get_record
    end #end method update_record_data




    def uuid
      @vm_record["uuid"]
    end #end method uuid



    def label
      @vm_record["name_label"]
    end
  
  
  
    def description
      @vm_record["name_description"]
    end #end method description
  
  
  
    def allowed_operations
      @vm_record["allowed_operations"]
    end #end method allowed_operations
  
  
  
  
    def current_operations
      @vm_record["current_operations"]
    end #end method current_operations
  
  
  
  
    def is_regular?
      !is_control? && !is_template? && !is_snapshot?
    end #end method is_regular?
  
  
  
  
    def is_control?
      @vm_record["is_control_domain"]
    end #end method is_control?
  
  
  
  
    def is_template?
      @vm_record["is_a_template"]
    end #end method is_template?
  
  
  
  
    def is_snapshot?
      @vm_record["is_a_snapshot"]
    end #end method is_snapshot?
  
  
  
  
    def snapshots
      snaps = []
      @vm_record["snapshots"].each do |snap_ref|
        snaps << VM.new(@link, snap_ref)
      end
      snaps
    end #end method snapshots
  
  
  
  
    def snapshot_of
      vm_ref = @vm_record["snapshot_of"]
      if vm_ref =~ /null/
        return nil
      else
        VM.new(@link, vm_ref)
      end
    end #end method snapshot_of
  
  
  
  
    def snapshot_time
      if is_snapshot?
        #Utilities.make_time(@vm_record["snapshot_time"])
        @vm_record["snapshot_time"].to_time
      else
        nil
      end
    end #end method snapshot_time
  
  
  
  
    def power_state
      @vm_record["power_state"]
    end #end method power_state
  
  
  
  
    def cpus
      @vm_record["VCPUs_max"]
    end #end method cpus
  
  
  
  
    def last_shutdown_time
      Utilities.make_time(@vm_record["other_config"]["last_shutdown_time"])
    end #end method last_shutdown_time
  



    def last_shutdown_reason
      @vm_record["other_config"]["last_shutdown_reason"]
    end #end method last_shutdown_reason
  
  
  
  
    def max_memory
      Utilities.humanize_bytes(@vm_record["memory_static_max"])
    end #end method max_mem
  
  
  
    def min_memory
      Utilities.humanize_bytes(@vm_record["memory_satic_min"])
    end #end method min_mem
  
  
  
    def max_dyn_memory
      Utilities.humanize_bytes(@vm_record["memory_dynamic_max"])
    end #end method max_dyn_mem
  
  
  
    def min_dyn_memory
      Utilities.humanize_bytes(@vm_record["memory_dynamic_min"])
    end #end method min_dyn_mem
  
  
    def tags
      @vm_record["tags"]
    end #end method tags
  
  
  
    def shutdown
      clean_shutdown
      update_record_data
    end #end method shutdown
    
    
    def shutdown_async
      link = get_link
      result = link.client.call("Async.VM.clean_shutdown", link.sid, get_ref)
      process_async_result(result)
    end #end method shutdown_async
  
  
  
    def reboot
      clean_reboot
      update_record_data
    end #end method reboot
    
    
    def reboot_async
      link = get_link
      result = link.client.call("Async.VM.clean_reboot", link.sid, get_ref)
      process_async_result(result)
    end #end method reboot_async
  
  
  
    def force_shutdown
      hard_shutdown
      update_record_data
    end #end method force_shutdown
    
    
    def force_shutdown_async
      link = get_link
      result = link.client.call("Async.VM.hard_shutdown", link.sid, get_ref)
      process_async_result(result)
    end #end method force_shutdown_async
  
  
  
    def force_reboot
      hard_reboot
      update_record_data
    end #end method force_reboot
    
    
    def forece_reboot_async
      link = get_link
      result = link.client.call("Async.VM.hard_reboot", link.sid, get_ref)
      process_async_result(result)
    end #end method forece_reboot_async
  
  
  
    def startup
      start(false, false)
    end #end method startup
    
    
    def startup_async
      link = get_link
      result = link.client.call("Async.VM.start", link.sid, get_ref, false, false)
      process_async_result(result)
    end #end method startup_async
  
  
  
    def startup_on(host_ref)
      start_on(host_ref, false, false)
    end #end method startup_on(host_ref)
    
    
    def startup_on_async(host_ref)
      link = get_link
      result = link.client.call("Async.VM.start_on", link.sid, get_ref, host_ref, false, false)
      process_async_result(result)
    end #end method startup_on_async(host_ref)
  
  
  
    def possible_hosts
      hosts = []
      get_possible_hosts.each do |host_ref|
        hosts << Host.new(@link, host_ref)
      end
      hosts
    end #end method possible_hosts
  
  
  
    def resident_on
      host_ref = get_resident_on
      Host.new(@link, host_ref)
    end #end method resident_on
  
  
    def get_disks
      other_config = get_other_config
      disks_xml = other_config['disks']
      doc = REXML::Document.new(disks_xml)
      disks = []
      doc.elements.each("provision/disk") {|e| disks << Disk.disk_from_xml(e) }
      disks
    end #end method get_disks
  
  
    def get_provision_spec
      ps = ProvisionSpec.new
      ps.disks = get_disks
      ps
    end #end method get_provision_spec
  
  
    def set_provision_spec(ps)
      remove_from_other_config("disks")
      txt = REXML::Document.new(ps.to_element)
      add_to_other_config("disks", txt.to_s)
    end #end method set_provision_spec(ps)
    
    
    def get_console_locations
      link = get_link
    
      begin
        result = link.client.call("VM.get_consoles", link.sid, get_ref)
      
        if result["Status"].downcase =~ /success/
          console_refs = result["Value"]
          locations = []
          console_refs.each do |c_ref|
            loc_result = link.client.call("console.get_location", link.sid, c_ref)
            locations << "#{loc_result["Value"]}&session_id=#{link.sid}"
          end
          return locations
        end
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method get_console_locations
    
    
    
    
    def do_suspend
      link = get_link
    
      begin
        result = link.client.call("VM.suspend", link.sid, get_ref)
      
        if result["Status"].downcase =~ /success/
          return result["Value"]
        end
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method do_suspend
    
    
    def do_suspend_async
      link = get_link
      result = link.client.call("Async.VM.suspend", link.sid, get_ref)
      process_async_result(result)
    end #end method do_suspend_async
    
    
    def do_resume
      link = get_link
    
      begin
        result = link.client.call("VM.resume", link.sid, get_ref, false, false)
      
        if result["Status"].downcase =~ /success/
          return result["Value"]
        end
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method do_resume
    
    
    def do_resume_async
      link = get_link
      result = link.client.call("Async.VM.resume", link.sid, get_ref, false, false)
      process_async_result(result)
    end #end method do_resume_async
    
    

    def do_destroy
    
      link = get_link
      
      disks_to_del = get_disk_VDIs
    
      begin
        result = link.client.call("VM.destroy", link.sid, get_ref)
      
        if result["Status"].downcase =~ /success/
          #return result["Value"]
          
          #delete the VM's disks
          for vdi in disks_to_del
            vdi.do_destroy
          end
          
          return true
          
        end #end if successful VM.destroy
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method do_clone(new_name)
    
    
    
    def do_destroy_async
      
      result_set = []
      
      link = get_link
      disks_to_del = get_disk_VDIs
      result = link.client.call("Async.VM.destroy", link.sid, get_ref)
      vm_destroy_result = process_async_result(result)
      
      if vm_destroy_result[:success] == true
        result_set << vm_destroy_result
        for vdi in disks_to_del
          vdi_destroy_result = vdi.do_destroy_async
          result_set << vdi_destroy_result
        end
      end
      
      return result_set
    end #end method do_destroy_async
    
    
    
    
    
    def do_snapshot(new_name="")
    
      link = get_link
    
      new_name = Time.now.strftime("%Y%m%d_%H%M%S") if new_name == ""
    
      begin
        result = link.client.call("VM.snapshot", link.sid, get_ref, new_name)
      
        if result["Status"].downcase =~ /success/
          ref = result["Value"]
          update_record_data
          new_snap_uuid = nil
          snapshots.each do |s|
            if s.get_ref == ref
              new_snap_uuid = s.uuid
            end
          end
          return new_snap_uuid
        end
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method do_clone(new_name)
    
    
    def do_snapshot_async(new_name="")      
      
      new_name = Time.now.strftime("%Y%m%d_%H%M%S") if new_name == ""
      
      link = get_link
      result = link.client.call("Async.VM.snapshot", link.sid, get_ref, new_name)
      process_async_result(result)
      
    end #end method do_snapshot_async(new_name="")
    
    
    
    def do_revert_to_snapshot(snap_uuid)
      link = get_link
      snap = VM.find_by_uuid(link, snap_uuid)
      begin
        result = link.client.call("VM.revert", link.sid, snap.get_ref)
      
        if result["Status"].downcase =~ /success/
          return result["Value"]
        end
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method do_revert_to_snapshot(snap_uuid)
    
    
    
    def do_revert_to_snapshot_async(snap_uuid)
      link = get_link
      snap = VM.find_by_uuid(link, snap_uuid)
      result = link.client.call("Async.VM.revert", link.sid, snap.get_ref)
      process_async_result(result)
    end #end method do_revert_to_snapshot_async(snap_uuid)
  
  
  
    def do_clone(new_name)
    
      link = get_link
    
      begin
        result = link.client.call("VM.clone", link.sid, get_ref, new_name)
      
        if result["Status"].downcase =~ /success/
          return result["Value"]
        end
    
      rescue Exception => e
        raise ProxyCallError.new("Error sending request to proxy VM. Link might be dead (#{e.message})")
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method do_clone(new_name)
    
    
    
    def do_clone_async(new_name)
      link = get_link
      result = link.client.call("Async.VM.clone", link.sid, get_ref, new_name)
      process_async_result(result)
    end #end method do_clone_async(new_name)
  
  
  
    def os_name
      gm_ref = @vm_record["guest_metrics"]
      link = get_link
    
      begin
        result = link.client.call("VM_guest_metrics.get_os_version", link.sid, gm_ref)
      
        if result["Status"].downcase =~ /success/
          os = result["Value"]
          if os.keys.include? "name"
            return os["name"]
          else
            return nil
          end
        end
    
      rescue Exception => e
        return nil
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    
    end #end method os_name
  
  
  
    def ip_address
      gm_ref = @vm_record["guest_metrics"]
      link = get_link
    
      begin
        result = link.client.call("VM_guest_metrics.get_networks", link.sid, gm_ref)
      
        if result["Status"].downcase =~ /success/
          os = result["Value"]
          if os.keys.include? "0/ip"
            return os["0/ip"]
          else
            return nil
          end
        end
    
      rescue Exception => e
        return nil
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method ip_address
  
  
  
  
  
    def provision_status
      return "none" if @provision_task_id.nil? #never started a provision
    
      begin
        link = get_link
        result = link.client.call("task.get_status", link.sid, @provision_task_id)
      
        if result["Status"].downcase =~ /success/
          return result["Value"]  #pending, #success, #failure
        end
    
      rescue Exception => e
        return nil
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method provision_status
  
  
  
    def provision_progress
      return 0 if @provision_task_id.nil? #never started a provision
    
      begin
        link = get_link
        result = link.client.call("task.get_progress", link.sid, @provision_task_id)
      
        if result["Status"].downcase =~ /success/
          return (result["Value"].to_f * 100).to_i
        end
    
      rescue Exception => e
        return nil
      end
    
      raise XenApiError.new(result["ErrorDescription"]) if result["Status"].downcase =~ /failure/
    end #end method provision_progress
  
  
  
    def state_description
      return "provisioning" unless @provision_task_id.nil?
      return power_state
    end #end method state_description
  
  
  
  #need implementation
    def crash_dumps
      @vm_record["crash_dumps"]
    end #end method crash_dumps
  
    def consoles
      @vm_record["consoles"]
    end #end method consoles
  
    def VIFs
      @vm_record["VIFs"]
    end #end method VIFs
  
    def VBDs
      link = get_link
      
      vbd_refs = @vm_record["VBDs"]
      vbd_objects = []
      
      vbd_refs.each do |_ref|
        
        if _ref != "OpaqueRef:NULL"
          vbd_objects << VBD.find(link, _ref)
        end

      end #end .each
      
      return vbd_objects
      
    end #end method VBDs
    
    
    def VDIs
      link = get_link
      vdi_objects = []
      
      vbd_objects = self.VBDs
      vbd_objects.collect(&:VDI).each do |_vdi_ref|
        
        if _vdi_ref != "OpaqueRef:NULL"
        
          vdi_objects << VDI.find(link, _vdi_ref)
        
        end #end if ref is null
        
      end #end .each
      
      return vdi_objects
      
    end #end method VDIs
    
    
    def get_disk_VDIs
      link = get_link
      vdi_objects = []
      
      vbd_objects = self.VBDs
      vbd_objects.reject {|vbd| vbd unless vbd.type == "Disk" }.collect(&:VDI).each do |_vdi_ref|
        
        if _vdi_ref != "OpaqueRef:NULL"
        
          vdi_objects << VDI.find(link, _vdi_ref)
        
        end #end if ref is null
        
      end #end .each
      
      return vdi_objects
    end #end method get_disk_VDIs
    
  
    def metrics
      @vm_record["metrics"]
    end #end method metrics
  
    def guest_metrics
      @vm_record["guest_metrics"]
    end #end method guest_metrics
  
  
  end #end VM Class
end #end module