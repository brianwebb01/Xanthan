module Xanthan

  # Base class for every Xen Object
  class XObject

    DEBUG = true

    def initialize(link, ref)
      @ref = ref
      @link = link
      @proxy_name = nil
      @proxy = nil
      @log = Logger.new(STDOUT)
      @log.level = Logger::DEBUG
    end
  
  
    def get_ref
      @ref
    end
  
  
    def get_link
      @link
    end
    
    
    def process_async_result(result)
      if result["Status"].downcase =~ /success/
        task = Task.find(get_link, result["Value"])
        response = {:success => true, :message => "", :task => task}
      else
        case result["ErrorDescription"].class
          when Array
            err_msg = result["ErrorDescription"].join(" => ")
          when String
            err_msg = result["ErrorDescription"]
        end
        response = {:success => false, :message => err_msg, :task => nil}
      end
    end #end method process_async_result(result)
    

  
    def method_missing(method_sym, *arguments, &block)
      begin
        call_api_method(method_sym.to_s, arguments)
      rescue XenApiError => e
        raise StandardError.new(e.message)
      rescue => e
        super(method_sym, arguments)
      end
    end #end method_missing
  
  
  
  
    def create_method_signature(method, args=[])

      vars = []
      args.each do |a|
        case a.class.to_s.downcase
          when "string":
            vars << "\"#{a.to_s}\""
          else
            vars << a.to_s
        end
      end
    
      arg_string = vars.join(", ")
    
      if arg_string != "" && arg_string != "\"\""
        sig = %[@proxy.send("#{method}", "#{@link.sid}", "#{@ref}", #{arg_string})]
      else
        sig = %[@proxy.send("#{method}", "#{@link.sid}", "#{@ref}")]
      end
      sig
    end #end method self.test(*args)
  
  
  
  
    def call_api_method(method, args)
    
      #if this is the first call we need to set the @proxy
      if @proxy.nil?
        @proxy = @link.client.proxy(@proxy_name)
      end
  
      begin

        sig = create_method_signature(method, args)
        @log.debug("Calling XenAPI with: #{sig}") if DEBUG
        result = eval(sig)
    
        if result["Status"].downcase =~ /success/
          return result["Value"]
        end
    
      rescue Exception => e
          raise ProxyCallError.new("Error sending request to proxy #{@proxy_name}. Link might be dead (#{e.message})")
      end
    
      if result["Status"].downcase =~ /failure/
        raise XenApiError.new(result["ErrorDescription"])
      end
    
    end #end method call_api_method(method, *args)
  
  end #end class XObject

end #end module