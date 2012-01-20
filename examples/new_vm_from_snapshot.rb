require 'rubygems'
require '../lib/xanthan'
include Xanthan


host = Host.connect("https://10.0.0.20", "root", "somepasswordhere")
link = host.get_link

#needs to be a UUID of a current snapshot
snapshot_uuid = "60bdf52e-119a-3bcb-1d10-69a2cf6d7193"
VM.create_new_from_snapshot(link, snapshot_uuid, "myVMFromSnapshot")