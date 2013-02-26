#/usr/bin/env python -t

import gobject
gobject.threads_init()
import os
# import fcntl
import threading
import Queue
import time

COUNTER = 0


class MyThreadClass(threading.Thread):
    def __init__(self, pipe_r, pipe_w, q):
        self.pipe_read = pipe_r
        self.pipe_write = pipe_w
        self.queue = q
        threading.Thread.__init__(self)
        self._stop = threading.Event()
    
    def run(self):
        self.item = self.queue.get()
        
        watch = gobject.io_add_watch(self.pipe_read,
                        gobject.IO_IN, self.callback,
                        priority=gobject.PRIORITY_DEFAULT)
        
        counter = 0
        while not self.stopped():
            time.sleep(1)
            counter += 1
            print counter
            if counter > 2:
                os.write(self.pipe_write, "thread out of control!n")
                self.queue.task_done()
    
    def callback(self, fd, condition):
        msg = os.read(fd, 4096)
        print "msg recevied from main: %s" % msg
        os.write(self.pipe_write, 'hiya!')
        return True
    
    def stop(self):
        self._stop.set()
    
    def stopped(self):
        return self._stop.isSet()


if __name__ == "__main__":
    def receiver(fd, condition, loop):
        msg = os.read(fd, 4096)
        print "msg received from thread: %s" % msg
        loop.quit()
        return False
    
    # two communication channels
    pipe1_read, pipe1_write = os.pipe()
    pipe2_read, pipe2_write = os.pipe()
    
    # enable non-blocking reads if you need to
    # this example doesn't need it
    # fcntl.fcntl(pipe1_read, fcntl.F_SETFL, os.O_NONBLOCK)
    # fcntl.fcntl(pipe2_read, fcntl.F_SETFL, os.O_NONBLOCK)
    
    loop = gobject.MainLoop()
    
    # watch for someone writing to pipe2
    gobject.io_add_watch(pipe2_read, gobject.IO_IN, receiver, loop)
    
    queue = Queue.Queue()
    item = 'thingy'
    # start a thread, pass in pipe1_read so he can listen
    # and pass in pipe2_write so it can talk back
    thread = MyThreadClass(pipe1_read, pipe2_write, queue)
    thread.setDaemon(True)
    thread.start()
    queue.put(item)
    
    time.sleep(.5)
    os.write(pipe1_write, 'hello thread!')
    
    loop.run()

