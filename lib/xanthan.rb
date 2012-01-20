# Xanthan
require 'xmlrpc/client'
require 'rexml/document'
require 'builder'
require 'logger'
require "xanthan/net.rb"
require "xanthan/errors.rb"
require "xanthan/utilities.rb"
require "xanthan/link.rb"
require "xanthan/xobject.rb"
require "xanthan/host.rb"
require "xanthan/vm.rb"
require "xanthan/disk.rb"
require "xanthan/provision_spec.rb"

module Xanthan
  VERSION = "0.1.20100907162200"
end # module Xanthan