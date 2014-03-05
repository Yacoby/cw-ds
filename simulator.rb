#!/usr/bin/env ruby
# Run by passing the input file you want to run as the first argument when running
# this program. e.g.
# ./script_runner.rb script_name

# This class uses two queues of work that should be done. One for 
# external commands such as "send pid msg". The other is for high priority
# internal communication such as sending mutex requests or implementing wait loops
#
# The commands that the scrip uses are implemented in this class by method names
# prefixed with "call_".
#
# Debug checks have been left in to ensure the correct running of the program
class DsProcess
  @@msg = Hash.new { |h,k| h[k] = {} }
  @@procs = {}

  def initialize(pid)
    @mutex_owned = @mutex_wanted = false
    @mutex_req_time = 0
    @mutex_accepts = []
    @mutex_deffer = []

    @uid = @@procs.length
    @@procs[pid] = self
    @pid = pid
    @time = 0

    @cmd_queue = []
    @msg_queue = []
  end

  def puts(text)
    codes = ['1;34', '1;32', '1;36', '1;31', '0;33', '1;33', '1;30;47', '1;35', '37;40']
    super "\e[#{codes[@uid % codes.length]}m#{text}\e[0m"
  end

  def self.processes
    @@procs.values
  end

  def exc_next_command
    work = (@msg_queue.shift || @cmd_queue.shift)
    work ? work.call : false
  end

  def has_tasks?
    ![@msg_queue, @cmd_queue].all?(&:empty?)
  end

  def mutex_owned?
    @mutex_owned
  end

  def method_missing(method, *args, &block)
    case method.to_s
    when /^queue_msg_(.*)/
      @msg_queue << lambda { send("call_#{$1}", *args) } && false
    when /^queue_cmd_(.*)/
      @cmd_queue << lambda { send("call_#{$1}", *args) } && false
    else
      super(method, *args, &block)
    end
  end

  private

  def call_recv(from_pid, msg_id)
    if @@msg[msg_send_rec_key(from_pid, @pid)][msg_id]
      other_time = @@msg[msg_send_rec_key(from_pid, @pid)].delete(msg_id)
      @time = [@time, other_time].max + 1

      puts "received #{@pid} #{msg_id} #{from_pid} #{@time}"
    else
      queue_msg_recv(from_pid, msg_id)
    end
  end

  def call_send(to_pid, msg)
    @time += 1

    @@msg[msg_send_rec_key(@pid, to_pid)][msg] = @time

    puts "sent #{@pid} #{msg} #{to_pid} #{@time}"
  end

  # This isn't part of the script language but is used internally when
  # needing to enter a mutex. This is called from the process requesting access
  # to a mutex
  def call_req_mutex(req_pid, req_time)
    @time = [req_time, @time].max + 1
    if !@mutex_owned && (!@mutex_wanted || @mutex_req_time > req_time)
      @@procs[req_pid].queue_msg_req_mutex_response(@pid, @time)
    else
      @mutex_deffer << req_pid
    end
  end

  # This also isn't part of the script language but represents a response from another
  # process indicating the acceptance of a mutex request
  def call_req_mutex_response(respone_pid, response_time)
    raise 'Accepting our own request. No need to do this' if respone_pid == @pid
    @time = [response_time, @time].max + 1
    @mutex_accepts << respone_pid
  end

  # Used when waiting for a mutex, this either waits adds itself to the message queue
  # which has a benefit over a while loop in that it allows responding to mutex requests
  # while waiting
  def call_mutex_wait
    raise 'Waiting when in an owned mutex' unless !@mutex_owned
    if (@@procs.keys - @mutex_accepts).length == 1
      raise 'Attempted to enter a mutex when another process is in a mutex' unless @@procs.values.none?(&:mutex_owned?)
      @mutex_owned = true
      @mutex_accepts = []
    else
      queue_msg_mutex_wait
    end
  end

  def call_enter_mutex
    raise 'Attempted to enter a mutex when already in a mutex' unless !@mutex_owned
    @mutex_wanted = true
    @mutex_req_time = @time
    @@procs.each_value { |p| p.queue_msg_req_mutex(@pid, @time) unless p == self }
    queue_msg_mutex_wait
  end

  def call_exit_mutex
    raise 'Called exit mutex without having a mutex' unless @mutex_owned

    @mutex_owned = @mutex_wanted = false

    @mutex_deffer.map { |pid| @@procs[pid] }.each { |p| p.queue_msg_req_mutex_response(@pid, @time) }
    @mutex_deffer = []
  end

  def call_print(msg)
    raise 'Called print without having mutex' unless @mutex_owned

    @time += 1
    puts "printed #{@pid} #{msg} #{@time}"
  end

  def msg_send_rec_key(from_pid, to_pid)
    [from_pid, to_pid]
  end

end

raise "Need to specify a file to process" unless (filename = ARGV.pop)

File.open(filename) do |file|
  current_process = nil
  in_mutex = false

  file.each do |line|
    case line.strip
    when ''
    when /begin process (.*)/
      current_process = DsProcess.new($1)
    when /end process/
    when /begin mutex/
      current_process.queue_cmd_enter_mutex
      in_mutex = true
    when /end mutex/
      in_mutex = false
      current_process.queue_cmd_exit_mutex
    else
      proc_name, *args = line.split
      should_add_mutex = proc_name == 'print' && !in_mutex
      current_process.queue_cmd_enter_mutex if should_add_mutex
      current_process.send("queue_cmd_#{proc_name}", *args)
      current_process.queue_cmd_exit_mutex if should_add_mutex
    end
  end

  #While at one point this was evaluated using threads this turned out to be quite
  #slow due to the GIL. This is faster as its scheduling is relatively good
  while DsProcess.processes.any?(&:has_tasks?)
    DsProcess.processes.each { |p| loop { break unless p.exc_next_command } }
  end

end
