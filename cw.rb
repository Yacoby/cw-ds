require 'thread'
require 'ostruct'

class DsProcess
  @@msg = Hash.new { |h,k| h[k] = {} }
  @@procs = {}
  @@mutex = Mutex.new

  def initialize(pid)
    @mutex_owned = false
    @mutex_wanted = false
    @mutex_accepts = []
    @@procs[pid] = self

    @pid = pid
    @time = 0

    @cmd_queue = []
    @msg_queue = []

    @t = Thread.new do
      while true
        if work = @msg_queue.shift 
          work.call
        elsif work = @cmd_queue.shift
          @time += 1
          work.call
        end
      end
    end
  end

  def msg_key(from_pid, to_pid)
    OpenStruct.new(:frm => from_pid, :to => to_pid)
  end

  def call_recv(pid, msg)
    send_rec_key = msg_key(pid, @pid)
    if @@msg[send_rec_key][msg] == nil
      puts "wait for rec #{@pid} #{msg} #{pid} #{@time}"
      msg_recv(pid, msg)
    else
      other_time = @@msg[send_rec_key][msg]
      @time = [@time, other_time].max

      puts "received #{@pid} #{msg} #{pid} #{@time}"
    end
  end

  def call_send(pid, msg)
    send_rec_key = msg_key(@pid, pid)
    @@msg[send_rec_key][msg] = @time

    puts "sent #{@pid} #{msg} #{pid} #{@time}"
  end


  def call_req_mutex(req_pid, req_time)
    if @mutex_owned
      @mutex_deffer << req_pid
      puts "++#{@pid}++ We have mutex"
    elsif !@mutex_wanted || @time > req_time
      @@procs[req_pid].msg_req_mutex_response(@pid)
      puts "++#{@pid}++ #{@time} > #{req_time}"
    else
      puts "++#{@pid}++ !(#{@time} > #{req_time})"
      @mutex_deffer << req_pid
    end
  end

  def call_req_mutex_response(respone_pid)
    @mutex_accepts << respone_pid
  end

  def call_mutex_wait
    if @@procs.keys - @mutex_accepts == []
      puts "++#{@pid} got mutex"
      @mutex_accepts = []
    else
      msg_mutex_wait
    end
  end

  def call_enter_mutex
    puts "++#{@pid} wants mutex"
    @mutex_wanted = true
    @@procs.each { |k,v| v.msg_req_mutex(@pid, @time) }
    msg_mutex_wait
  end

  def call_exit_mutex
    @mutex_owned = false
    @mutex_wanted = false

    @mutex_deffer.each { |pid| @@procs[pid].msg_req_mutex_response(@pid) }
    @mutex_deffer = []

    puts "++#{@pid} stopped mutex"
  end

  def call_print(msg)
    puts "printed #{@pid} #{msg} #{@time}"
  end

  def stop
    @t.kill
  end

  def await_done
    while !@msg_queue.empty? || !@cmd_queue.empty?
      #Thread.current.pass
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
        if proc_name == 'print'
          current_process.cmd_enter_mutex
          current_process.send("cmd_#{proc_name}", *args)
          current_process.cmd_exit_mutex
        else
          current_process.send("cmd_#{proc_name}", *args)
        end
      end
    end
  end

  puts 'All join'

  current_processes.map { |p| p.await_done }
  current_processes.map { |p| p.stop }
end
