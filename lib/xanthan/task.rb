module Xanthan
  class Task< XObject
  
    attr_reader :result, :resident_on, :uuid, :progress, :name_label, :subtasks, :allowed_operations,
      :subtask_of, :type, :name_description, :error_info, :status, :finished, :current_operations,
      :other_config, :created
  
    def initialize(link, ref) #:nodoc:
      super(link, ref)
      @proxy_name = 'task'
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
    
    
    def fetch_status
      link = get_link
      ref = get_ref
      
      result = link.client.call("task.get_status", link.sid, ref)

      if result["Status"].downcase =~ /success/
        return result["Value"]  #pending, #success, #failure
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
      
    end #end method fetch_status
    
    
    
    def fetch_progress
      link = get_link
      ref = get_ref
      
      result = link.client.call("task.get_progress", link.sid, ref)

      if result["Status"].downcase =~ /success/
        return result["Value"]  #float
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
      
    end #end method fetch_status
    
    
    def self.find_by_uuid(link, uuid)
      result = link.client.call("task.get_by_uuid", link.sid, uuid)
      
      if result["Status"].downcase =~ /success/
        task_ref = result["Value"]
        task = Task.find(link, task_ref)
        return task
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
      
    end #end method self.find_by_uuid(link, uuid)
    
    
    def self.find(link, ref)
      result = link.client.call("task.get_record", link.sid, ref)
      
      if result["Status"].downcase =~ /success/
        task = Task.new(link, ref)
        task.popuplate_from_response(result["Value"])
        return task
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
    end #end method self.find(link, ref)
    
    
    def self.all(link)
      result = link.client.call("task.get_all", link.sid)
      
      if result["Status"].downcase =~ /success/
        tasks = []
        result["Value"].each do |ref|
          t = Task.find(link, ref)
          tasks << t
        end
        return tasks
      else
        raise XenApiError.new(result["ErrorDescription"])
      end
      
    end #end method self.all(link)
    
    
    def self.print_tasks(link)
      tasks = Task.all(link)
      tasks.each do |t|
        output = <<-EOOUT
        
Task: #{t.uuid}
  Name: #{t.name_label}
  Ref: #{t.get_ref}
  Subtasks: #{t.subtasks.join(', ')}
  Status: #{t.status =~ /failure/ ? 'failed - ' + t.error_info.join(' - ') : t.status}
  Progress: #{t.progress}
  
        EOOUT
        puts output
      end
      
      return nil
    end #end method self.print_tasks(link)
    
  
  end #end class Task
end #end module