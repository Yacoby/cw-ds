require 'thread'
require 'ostruct'

class DsProcess
  @@msg = Hash.new { |h,k| h[k] = {} }
  @@mutex = Mutex.new

  def initialize(pid)
    @mutex_owned = false

    @pid = pid
    @clock = 0

    @cmd_queue = Queue.new

    @t = Thread.new do
      while work = @cmd_queue.pop
        @clock += 1
        work.call
      end
    end
  end

  def msg_key(from_pid, to_pid)
    OpenStruct.new(:frm => from_pid, :to => to_pid)
  end

  def call_msg_recv(pid, msg)
    send_rec_key = msg_key(pid, @pid)
    while @@msg[send_rec_key][msg] == nil
    end
    other_time = @@msg[send_rec_key][msg]
    @clock = [@clock, other_time].max

    puts "received #{@pid} #{msg} #{pid} #{@clock}"
  end

  def call_msg_send(pid, msg)
    send_rec_key = msg_key(@pid, pid)
    @@msg[send_rec_key][msg] = @clock

    puts "sent #{@pid} #{msg} #{pid} #{@clock}"
  end

  def call_msg_enter_mutex
    @@mutex.lock
    @mutex_owned = true
  end

  def call_msg_exit_mutex
    @mutex_owned = false
    @@mutex.unlock
  end

  def call_msg_print(msg)
    if @mutex_owned
      puts "printed #{@pid} #{msg} #{@clock}"
    else
      @@mutex.synchronize {
        puts "printed #{@pid} #{msg} #{@clock}"
      }
    end
  end

  def call_msg_exit
    @t.kill
  end

  def join
    @t.join
  end

  def method_missing(m, *args, &block)
    if m.to_s.start_with? 'msg_'
      @cmd_queue << lambda { self.send("call_#{m}", *args) }
    else
      super(m, *args, &block)
    end
  end

end


File.open("input") do |file|
  current_processes = []
  current_process = nil

  file.each do |line|
    line = line.strip
    if line != ''
      if proc_id = /begin process (.*)/.match(line)
        current_process = DsProcess.new(proc_id[1])
        current_processes << current_process
      elsif /begin mutex/.match(line)
        current_process.msg_enter_mutex
      elsif /end mutex/.match(line)
        current_process.msg_exit_mutex
      elsif /end process/.match(line)
        current_process.msg_exit
      else
        proc_name, *args = line.split(' ')
        current_process.send("msg_#{proc_name}", *args)
      end
    end
  end

  current_processes.map { |p| p.join }
end

