#!/usr/bin/env ruby
#
# Copyright (c) 2009 Carson McDonald
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 2
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

require 'hs_transfer'
require 'hs_config'
require 'hs_encoder'
require 'fileutils'

# **************************************************************
#
# Main
#
# **************************************************************

hsencoder = nil

trap('INT') { hsencoder.stop_encoding if !hsencoder.nil?  }

if ARGV.length != 1
  puts "Usage: http_streamer.rb <config file>"
  exit 1
end

begin
  config = HSConfig::load( ARGV[0] )
rescue
  exit 1
end

log = HSConfig::log_setup( config )

log.info('HTTP Streamer started')

#Look for a new file name
pipe = File.open("/home/xbmc/streamPipe", "r+")

while true 

	log.info("WAITING ON PIPE")
	line = pipe.gets.chop
	log.info("LINE READ: #{line}")

	# Delete all old files 
	dir = config['copy_dev']['directory']
	Dir.foreach(dir) do |f|
		if f == '.' or f == '..' then next
		elsif File.directory?(f) then FileUtils.rm_rf(f)
		else FileUtils.rm(f)
		end
	end

	hsencoder.stop_encoding if !hsencoder.nil?
	
	break if line == "QUIT"

	#if !File.exists?(line)
	#	log.info("FILE DOES NOT EXIST: \"#{line}\"")
	#	next
	#end

	hstransfer = HSTransfer::init_and_start_transfer_thread( log, config )

	hsencoder = HSEncoder.new(log, config, hstransfer, line)

	# Keep reference to the ecoding threads so we can join
	# and possible kill if necessary
	encoding_threads = []
	hsencoder.start_encoding (encoding_threads)

	# Now wait for the fd to not be blocking	
	#pipeWatcher = Thread.new {
	#        log.info("STARTING WATCHER")	
	#	rb_io_wait_readable(pipe)
	#	log.info("WATCHING WOKEUP")
	#	hsencoder.stop_encoding
	#}

	# Joined here in case all threads exit
	#encoding_threads.each do |encoding_thread|
	#	encoding_thread.join
	#end

	hstransfer.stop_transfer_thread

	log.info('HTTP Streamer terminated')

end

hsencoder.stop_encoding if !hsencoder.nil?
hstransfer.stop_transfer_thread if !hstransfer.nil?

