module Xanthan
  class LinkConnectError < StandardError
  end


  class ProxyCallError < StandardError
  end


  class XenApiError < StandardError
  
    CODES = {
      "AUTH_ALREADY_ENABLED" => "External authentication for this host is already enabled.",
      "AUTH_ENABLE_FAILED" => "The host failed to enable external authentication.",
      "AUTH_IS_DISABLED" => "External authentication is disabled, unable to resolve subject name.",
      "AUTH_SERVICE_ERROR" => "Error querying the external directory service.",
      "AUTH_UNKNOWN_TYPE" => "Unknown type of external authentication.",
      "BACKUP_SCRIPT_FAILED" => "The backup could not be performed because the backup script failed.",
    }
  
    def initialize(params)
      @error_code = params[0]
      @params = params
    end #end method initialize()
  
  
    def message
      if CODES[@error_code]
        CODES[@error_code]
      else
        @error_code
      end
    end #end method message
  
  end #end XenApiError
end #end module