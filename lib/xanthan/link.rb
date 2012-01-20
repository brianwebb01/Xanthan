module Xanthan
  class Link

    attr_reader :client, :sid, :url, :connected


    def initialize(url, username='foo', password='bar')
      @xmlrpc_url = url
      @username = username
      @password = password
    end


    def connect
      $stdout.flush
      begin
        @client = XMLRPC::Client.new2(@xmlrpc_url)
        @session = @client.proxy('session')
        @sid = @session.login_with_password(@username, @password)['Value']
        @connected = true
      rescue Exception => e
        raise LinkConnectError.new("Error connecting to the hypervisor #{@xmlrpc_url} (#{e.message})")
      end
    end
  
    def disconnect
      $stdout.flush
      begin
        @session.logout(@sid)
      rescue Exception => e
        raise LinkConnectError.new("Error connecting to the hypervisor #{@xmlrpc_url} (#{e.message})")
      end
    end #end method disconnect
    
    
    def self.new_link
      @_host = Xanthan::Host.connect("https://#{XEN_SERVER_MASTER}", XEN_SERVER_USERNAME, XEN_SERVER_PASSWORD)
      @_link = @_host.get_link
    end #end method self.new_link
    

  end #end Link
end #end module