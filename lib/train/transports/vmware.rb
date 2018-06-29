# encoding: utf-8
require 'train/plugins'
require 'open3'
require 'ostruct'
require 'json'

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
      POWERSHELL_PROMPT_REGEX = /PS\s.*> $/

      def initialize(options)
        super(options)
        options[:viserver] = options[:viserver] || options[:host]
        options[:username] = options[:username] || options[:user]

        @session = nil
        @stdout_buffer = ''
        @stderr_buffer = ''

        @platform_details = { release: "vmware-powercli-#{powercli_version}" }

        connect
      end

      def platform
        direct_platform('vmware', @platform_details)
      end

      def connect
        login_command = "Connect-VIserver #{options[:viserver]} -User #{options[:username]} -Password #{options[:password]} | Out-Null"
        result = run_command_via_connection(login_command)

        if result.exit_status != 0
          message = "Unable to connect to VIServer at #{options[:viserver]}. "
          case result.stderr
          when /Invalid server certificate/
            message += 'Certification verification failed. Please use `--insecure` or set `Set-PowerCLIConfiguration -InvalidCertificateAction Ignore` in PowerShell'
          when /incorrect user name or password/
            message += 'Incorrect username or password'
          else
            message += result.stderr.gsub(/-Password .*\s/, '-Password REDACTED')
          end

          raise message
        end
      end

      def uri
        "vmware://#{@username}@#{@viserver}"
      end

      def unique_identifier
        # TODO
      end

      def run_command_via_connection(cmd)
        result = parse_powershell_output(cmd)

        # Attach exit status to result
        exit_status = parse_powershell_output('echo $?').stdout.chomp
        result.exit_status = exit_status == 'True' ? 0 : 1

        result
      end

      private

      def powercli_version
        version_command = '[string](Get-Module -Name VMware.PowerCLI -ListAvailable | Select -ExpandProperty Version)'
        result = run_command_via_connection(version_command)
        if result.stdout.empty? || result.exit_status != 0
          raise 'Unable to determine PowerCLI Module version, is it installed?'
        end

        result.stdout.chomp
      end

      def parse_powershell_output(cmd)
        session.stdin.puts(cmd)

        stdout = flush_stdout(session.stdout)

        # Remove stdin from stdout (including trailing newline)
        stdout.slice!(0, cmd.length+1)

        # Remove prompt from stdout
        stdout.gsub!(POWERSHELL_PROMPT_REGEX, '')

        # Grab stderr
        stderr = flush_stderr(session.stderr)

        CommandResult.new(
          stdout,
          stderr,
          nil # exit_status is attached in `run_command_via_connection`
        )
      end

      def session
        return @session unless @session.nil?
        stdin, stdout, stderr = Open3.popen3('pwsh')

        # Remove leading prompt and intro text
        flush_stdout(stdout)

        @session = OpenStruct.new
        @session.stdin = stdin
        @session.stdout = stdout
        @session.stderr = stderr

        @session
      end

      # Read from stdout pipe until prompt is received
      def flush_stdout(pipe)
        while @stdout_buffer !~ POWERSHELL_PROMPT_REGEX
          @stdout_buffer += pipe.read_nonblock(1)
        end
        @stdout_buffer
      rescue IO::EAGAINWaitReadable
        retry
      ensure
        @stdout_buffer = ''
      end

      # Read from stderr until IO::EAGAINWaitReadable "error"
      # This must be called after `flush_stdout` to ensure buffer is full
      def flush_stderr(pipe)
        loop do
          @stderr_buffer += pipe.read_nonblock(1)
        end
      rescue IO::EAGAINWaitReadable
        @stderr_buffer
      ensure
        @stderr_buffer = ''
      end
    end
  end
end
