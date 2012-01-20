module Xanthan
  # Host machine
  # host = Host.connect('http://xen.example.net', 'username', 'password')
  class Host < XObject
  
  
    def initialize(link, ref) #:nodoc:
      super(link, ref)
      @proxy_name = 'host'
    end
  

    def self.connect(url, username, password)
      @link = Link.new(url, username, password)
      @link.connect
      #@ref = @link.client.call('host.get_all', @link.sid)['Value'][0]
      
      result = @link.client.call('host.get_all', @link.sid)
      
      #handle calls that need to go to the master server here.
      if result['Status'] =~ /Failure/i
        if result['ErrorDescription'].class == Array && result['ErrorDescription'].first == 'HOST_IS_SLAVE'
          @link.disconnect
          return Host.connect("https://#{result['ErrorDescription'].last}", username, password)
        else
          raise "Host Connect Err: #{result.to_a.flatten.join("; ")}"
        end
      else
        @ref = @link.client.call('host.get_all', @link.sid)['Value'][0]
      end
      
      return Host.new(@link, @ref)
    end
  
  
    def get_all_hosts
      _hosts = []
      result = @link.client.call('host.get_all', @link.sid)
      result['Value'].each do |ref|
        _hosts << Host.new(@link, ref)
      end
      return _hosts
    end #end method get_all_hosts
  
  
    def disconnect
      @link.disconnect
    end #end method disconnect
  
  
    def reconnect
      raise LinkConnectError.new("You need to connect at least once before reconnecting") if @link.nil?
      @link.connect
      @ref = @link.client.call('host.get_all', @link.sid)['Value'][0]
    end
  
  

    def alive?
      begin
        get_uuid
      rescue Exception => e
        #puts e.message
        return false
      end
      true
    end
  
  
  
    def resident_vms
      vms = []
      get_resident_VMs.each do |vm_ref|
        temp_vm = VM.new(@link, vm_ref)
        if temp_vm.is_regular?
          vms << temp_vm
        else
          temp_vm = nil
        end
      end
      vms
    end


    def free_memory
      compute_free_memory
    end #end method free_memory
  
  
    def free_memory_humanized
      Utilities.humanize_bytes(free_memory)
    end #end method free_memory_humanized
  
  
  end #end host class
end #end module