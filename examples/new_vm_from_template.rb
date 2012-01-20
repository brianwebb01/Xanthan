require 'rubygems'
require '../lib/xanthan'
include Xanthan


host = Host.connect("https://10.0.0.20", "root", "somepasswordhere")
link = host.get_link

#use "Demo Linux VM" template uuid
template_uuid = "e8978dc4-8b4c-c00c-c921-0084b6260f72"
VM.create_new_from_template(link, template_uuid, "myVMFromTemplate")