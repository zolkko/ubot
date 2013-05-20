# -*- coding: utf-8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:
#
# roboserv Application module
#

import logging as log
import functools
import signal
import os
from sys import platform
import tornado
from tornado import web
from signallingchannel import SignallingChannelHandler


__all__ = ['Application', 'signallingchannel']


class Application(web.Application):
    """ Roboserv application class. """
    
    pidfile = ''
    
    def __init__(self, basedir, pidfile, **settings):
        log.info('Starting roboserv in "{0}" directory.'.format(basedir))
        self.pidfile = pidfile
        handlers = [
            (r'/', web.RedirectHandler, {'url': '/index.html', 'permanent': True}),
            (r'/sc', SignallingChannelHandler),
            (r'/client', SignallingChannelHandler),
            (r'/(.+)', web.StaticFileHandler, {'path': os.path.join(basedir, 'htdocs')})
        ]
        super(Application, self).__init__(handlers, **settings)
    
    def create_pid(self):
        if os.path.exists(self.pidfile):
            return False
        else:
            with open(self.pidfile, mode='w') as f:
                f.write(unicode(os.getpid()))
            return True
    
    def signal_handler(self, signum, e, ioloop=None):
        log.info('{0} signal has been recevied.'.format(signum))
        if os.path.exists(self.pidfile) :
            os.remove(self.pidfile)
        # Quit ioloop and then join it's thread
        log.info('Stopping roboserv application server.')
        ioloop.stop()
    
    def install_signal_handlers(self, ioloop):
        """ The typical way to terminate an application - is send a POSIX signal. """
        sig_func = functools.partial(self.signal_handler, ioloop=ioloop)
        if hasattr(signal, 'SIGTERM'):
            signal.signal(signal.SIGTERM, sig_func)
        if hasattr(signal, 'SIGINT'):
            signal.signal(signal.SIGINT, sig_func)
        if hasattr(signal, 'SIGHUP'):
            signal.signal(signal.SIGHUP, sig_func)
    
    def run(self):
        """ A roboserv main loop. If a PID file exists this means that another instance
        of application is already runned. """
        if not self.create_pid():
            log.warn('roboserv PID file "{0}" already exists.'.format(self.pidfile))
            return
        # A web-service I/O loop will be runned from the second thread.
        ioloop = tornado.ioloop.IOLoop.instance()
        self.install_signal_handlers(ioloop)
        try:
            ioloop.start()
        except KeyboardInterrupt:
            log.warn('An interrupt was received from keyboard. In a normal situation this should not happen.')
        log.info('Roboserv is stopped.')

