class DsProcess
  @@msg = Hash.new { |h,k| h[k] = {} }
  @@procs = {}

  def initialize(pid)
    @mutex_owned = false
    @mutex_wanted = false
    @mutex_req_time = 0
    @mutex_accepts = []
    @mutex_deffer = []

    @@procs[pid] = self
    @pid = pid
    @time = 0

    @cmd_queue = []
    @msg_queue = []
  end

  def self.processes
    @@procs.values
  end

  def exc_next_command
    if work = @msg_queue.shift || work = @cmd_queue.shift
      work.call
    else
      false
    end
  end

  def has_tasks?
    ![@msg_queue, @cmd_queue].all?(&:empty?)
  end

  def mutex_owned?
    @mutex_owned
  end

  def method_missing(method, *args, &block)
    case method
    when /msg_(?<method_suffix>.*)/
      @msg_queue << lambda { send("call_#{$~[:method_suffix]}", *args) }
      false
    when /cmd_(?<method_suffix>.*)/
      @cmd_queue << lambda { send("call_#{$~[:method_suffix]}", *args) }
      false
    else
      super(method, *args, &block)
    end
  end

  def call_recv(from_pid, msg_id)
    send_rec_key = msg_key(from_pid, @pid)
    if @@msg[send_rec_key][msg_id] == nil
      msg_recv(from_pid, msg_id)
    else
      other_time = @@msg[send_rec_key].delete(msg_id)
      @time = [@time, other_time].max + 1

      puts "received #{@pid} #{msg_id} #{from_pid} #{@time}"
    end
  end

  def call_send(to_pid, msg)
    @time += 1

    send_rec_key = msg_key(@pid, to_pid)
    @@msg[send_rec_key][msg] = @time

    puts "sent #{@pid} #{msg} #{to_pid} #{@time}"
  end

  def call_req_mutex(req_pid, req_time)
    @time = [req_time, @time].max + 1
    if !@mutex_owned && (!@mutex_wanted || @mutex_req_time > req_time)
      @@procs[req_pid].msg_req_mutex_response(@pid, @time)
    else
      @mutex_deffer << req_pid
    end
  end

  def call_req_mutex_response(respone_pid, response_time)
    raise 'Accepting our request' if respone_pid == @pid
    @time = [response_time, @time].max + 1
    @mutex_accepts << respone_pid
  end

  def call_mutex_wait
    raise 'Waiting when in an owned mutex' unless !@mutex_owned
    if (@@procs.keys - @mutex_accepts).length == 1
      raise 'Attemtped to enter a mutex when another process is in a mutex' unless @@procs.values.none?(&:mutex_owned?)
      @mutex_owned = true
      @mutex_accepts = []
    else
      msg_mutex_wait
    end
  end

  def call_enter_mutex
    raise 'Attemtped to enter a mutex when already in a mutex' unless !@mutex_owned
    @mutex_wanted = true
    @mutex_req_time = @time
    @@procs.each do |k,v|
      v.msg_req_mutex(@pid, @time) unless v == self
    end
    msg_mutex_wait
  end

  def call_exit_mutex
    raise 'Called exit mutex without having a mutex' unless @mutex_owned

    @mutex_owned = false
    @mutex_wanted = false

    @mutex_deffer.each do
      |def_pid| @@procs[def_pid].msg_req_mutex_response(@pid, @time)
    end
    @mutex_deffer = []
  end

  def call_print(msg)
    raise 'Called print without having mutex' unless @mutex_owned

    @time += 1
    puts "printed #{@pid} #{msg} #{@time}"
  end

  private

  def msg_key(from_pid, to_pid)
    [from_pid, to_pid]
  end

end

if ARGV.length
  input_file = ARGV[0]
else
  input_file = "input"
end

File.open(input_file) do |file|
  current_process = nil
  in_mutex = false

  file.each do |line|
    case line.strip
    when ''
    when /begin process (?<pid>.*)/
      current_process = DsProcess.new($~[:pid])
    when /^end process/
    when /^begin mutex/
      current_process.cmd_enter_mutex
      in_mutex = true
    when /^end mutex/
      in_mutex = false
      current_process.cmd_exit_mutex
    else
      proc_name, *args = line.split
      if proc_name == 'print' && !in_mutex
        current_process.cmd_enter_mutex
        current_process.send("cmd_#{proc_name}", *args)
        current_process.cmd_exit_mutex
      else
        current_process.send("cmd_#{proc_name}", *args)
      end
    end
  end

  while DsProcess.processes.any?(&:has_tasks?)
    DsProcess.processes.each do |p|
      loop { break unless p.exc_next_command }
    end
  end

end
