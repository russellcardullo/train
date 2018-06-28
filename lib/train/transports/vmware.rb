# encoding: utf-8
require 'train/plugins'
require 'open3'
require 'ostruct'
require 'json'
require 'pry'

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
        options[:viserver] = options[:host] || options[:viserver]
        options[:username] = options[:user] || options[:username]
        @session = nil

        # get vmware cli version
        version_command = 'Get-Module -Name VMware.PowerCLI -ListAvailable | Select-Object -Property Version | ConvertTo-Json -Compress'
        version = run_command_via_connection(version_command)
        if version.stdout.empty? || version.exit_status == 1
          raise "Unable to connect to viserver at #{options[:viserver]}. Please make sure you have `pwsh` installed and the vmware cli extention."
        end
        version = JSON.parse(version.stdout)['Version']
        version = "#{version['Major']}.#{version['Minor']}.#{version['Build']}"
        @platform_details = { release: "vmware-cli-#{version}" }


        # login = connect
        # if login.exit_status != 0
        #   raise "Unable to connect to viserver at #{options[:viserver]}. Please make sure you have `pwsh` installed and the vmware cli extention."
        # end
      end

      def platform
        direct_platform('vmware', @platform_details)
      end

      def connect
        login_cmd = "Connect-VIserver #{options[:viserver]} -User #{options[:username]} -Password #{options[:password]} | Out-Null"
        run_command_via_connection(login_cmd)
      end

      def uri
        "vmware://#{@viserver}"
      end

      def unique_identifier
        # TODO
      end

      def run_command_via_connection(cmd)
        command = parse_powershell_output(cmd)

        # attach exit status
        exit_status = parse_powershell_output('echo $?').stdout.chomp
        case exit_status
        when 'True'
          command.exit_status = 0
        when 'False'
          command.exit_status = 1
        end

        command
      end

      private

      def parse_powershell_output(cmd)
        session.stdin.puts(cmd)

        stdout = read_stdout(session.stdout)

        # remove stdin from stdout
        stdout.slice!(0, cmd.length+1)

        # remove prompt from stdout
        stdout.gsub!(/PS\s.*> $/, '')

        # grab stderr
        stderr = read_stderr(session.stderr)

        CommandResult.new(
          stdout,
          stderr,
          nil
        )
      end

      def session
        return @session unless @session.nil?
        stdin, stdout, stderr, wait_thread = Open3.popen3('pwsh')
        @stdout_buffer = ''
        @stderr_buffer = ''

        # remove leading prompt
        read_stdout(stdout)

        @session = OpenStruct.new
        @session.stdin = stdin
        @session.stdout = stdout
        @session.stderr = stderr

        @session
      end

      def read_stdout(pipe)
        @stdout_buffer += pipe.read_nonblock(1) while @stdout_buffer !~ /PS\s.*> $/
        @stdout_buffer
      rescue IO::EAGAINWaitReadable
        retry
      ensure
        @stdout_buffer = ''
      end

      def read_stderr(pipe)
        @stderr_buffer += pipe.read_nonblock(1) while true
        @stderr_buffer
      rescue IO::EAGAINWaitReadable
        @stderr_buffer
      ensure
        @stderr_buffer = ''
      end
    end
  end
end
