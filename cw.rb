require 'thread'
require 'ostruct'

$puts_mutex = Mutex.new

def puts(o)
  $puts_mutex.synchronize { super(o) }
end

class DsProcess
  @@msg = Hash.new { |h,k| h[k] = {} }
  @@procs = {}

  def initialize(pid)
    @mutex_owned = false
    @mutex_wanted = false
    @mutex_accepts = []
    @mutex_deffer = []

    @@procs[pid] = self
    @pid = pid
    @time = 0

    @cmd_queue = []
    @msg_queue = []

    @t = Thread.new do
      while true
        if work = @msg_queue.shift || work = @cmd_queue.shift
          work.call
        else
          sleep(0.01)
        end
      end
    end
  end

  def call_recv(pid, msg)
    send_rec_key = msg_key(pid, @pid)
    if @@msg[send_rec_key][msg] == nil
      msg_recv(pid, msg)
    else
      other_time = @@msg[send_rec_key].delete(msg)
      @time = [@time, other_time].max

      puts "received #{@pid} #{msg} #{pid} #{@time}"
    end
  end

  def call_send(pid, msg)
    @time += 1

    send_rec_key = msg_key(@pid, pid)
    @@msg[send_rec_key][msg] = @time

    puts "sent #{@pid} #{msg} #{pid} #{@time}"
  end


  def call_req_mutex(req_pid, req_time)
    if !@mutex_owned && (!@mutex_wanted || @time > req_time)
      @@procs[req_pid].msg_req_mutex_response(@pid)
    else
      @mutex_deffer << req_pid
    end
  end

  def call_req_mutex_response(respone_pid)
    @mutex_accepts << respone_pid
  end

  def call_mutex_wait
    if (@@procs.keys - @mutex_accepts).length == 1
      @mutex_owned = true
      @mutex_accepts = []
    else
      msg_mutex_wait
    end
  end

  def call_enter_mutex
    raise "Attemtped to enter a mutex when already in a mutex" unless !@mutex_owned
    @mutex_wanted = true
    @@procs.each do |k,v|
      v.msg_req_mutex(@pid, @time) unless v == self
    end
    msg_mutex_wait
  end

  def call_exit_mutex
    raise "Called exit mutex without having a mutex" unless @mutex_owned

    @mutex_owned = false
    @mutex_wanted = false

    @mutex_deffer.each { |pid| @@procs[pid].msg_req_mutex_response(@pid) }
    @mutex_deffer = []
  end

  def call_print(msg)
    raise "Called print without having mutex" unless @mutex_owned

    @time += 1
    puts "printed #{@pid} #{msg} #{@time}"
  end

  def await_done
    if @msg_queue.empty? && @cmd_queue.empty?
      true
    else
      while !@msg_queue.empty? || !@cmd_queue.empty?
        sleep(0.1)
      end
      false
    end
  end

  def method_missing(m, *args, &block)
    if m.to_s.start_with? 'msg_'
      m_suffix = m[/msg_(.*)/, 1]
      @msg_queue << lambda { self.send("call_#{m_suffix}", *args) }
    elsif m.to_s.start_with? 'cmd'
      m_suffix = m[/cmd_(.*)/, 1]
      @cmd_queue << lambda { self.send("call_#{m_suffix}", *args) }
    else
      super(m, *args, &block)
    end
  end

  private

  def msg_key(from_pid, to_pid)
    OpenStruct.new(:frm => from_pid, :to => to_pid)
  end

end

File.open("input") do |file|
  current_processes = []
  current_process = nil
  in_mutex = false

  file.each do |line|
    line = line.strip
    if line != ''
      if proc_id = /begin process (.*)/.match(line)
        current_process = DsProcess.new(proc_id[1])
        current_processes << current_process
      elsif /begin mutex/.match(line)
        in_mutex = true
        current_process.cmd_enter_mutex
      elsif /end mutex/.match(line)
        in_mutex = false
        current_process.cmd_exit_mutex
      elsif /end process/.match(line)
      else
        proc_name, *args = line.split(' ')
        if proc_name == 'print' && !in_mutex
          current_process.cmd_enter_mutex
          current_process.send("cmd_#{proc_name}", *args)
          current_process.cmd_exit_mutex
        else
          current_process.send("cmd_#{proc_name}", *args)
        end
      end
    end
  end

  while !current_processes.all? { |p| p.await_done }
  end
end
