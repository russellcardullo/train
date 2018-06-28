# encoding: utf-8
require 'train/plugins'
require 'open3'
require 'ostruct'

module Train::Transports
  class VMware < Train.plugin(1)
    name 'vmware'
    option :viserver, default: ENV['VISERVER']
    option :username, default: ENV['VISERVER_USERNAME']
    option :password, default: ENV['VISERVER_PASSWORD']

    def connection(_ = nil)
      @connection ||= Connection.new(@options)
    end

    class Connection < BaseConnection
      def initialize(options)
        super(options)
        @viserver = @options.delete(:viserver)
        @username = @options.delete(:username)
        @password = @options.delete(:password)
      end

      def platform
        # direct_platform('vmware', @platform_details)
      end

      def connect

      end

      def uri
        "vmware://#{@viserver}"
      end

      def unique_identifier
        # TODO
      end

      def run_command_via_connection(cmd)
        session.stdin.puts(cmd)

        stdout = read_stdout(session.stdout)
        #stdout.gsub!(/.*#{cmd}\n(.*)/, '\1')
        #stdout.gsub!(/(.*)PS.*>.*/, '\1')

        CommandResult.new(
          stdout,
          '',
          0  # TODO: Figure out exit code
        )
      end

      private

      def session
        return @session if defined?(@session) && !@session.nil?
        stdin, stdout, stderr, wait_thread = Open3.popen3('pwsh')

        sleep 1
        @session = OpenStruct.new
        @session.stdin = stdin
        @session.stdout = stdout
        @session.stderr = stderr

        @session
      end

      def read_stdout(pipe)
        buffer = ''
        buffer += pipe.read_nonblock(1) while buffer !~ /PS.*>/
        buffer
      rescue IO::EAGAINWaitReadable
        raise 'Tried to read empty pipe'
      end

#      def read_stderr(pipe)
#        buffer = ''
#        buffer += pipe.read_nonblock(1) while session.stdout !~ /PS.*>/
#        buffer
#      end
    end
  end
end
