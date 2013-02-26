#!/usr/bin/env python -t
# -*- coding: utf-8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

import os, sys
import logging as log
from roboserv import Application


BASE_DIR  = os.path.dirname(__file__)
PID_FILE  = os.path.join(BASE_DIR, 'roboserv.pid')
LOGS_FILE = os.path.join(BASE_DIR, 'logs', 'roboserv.log')
SERV_PORT = 3919


def init_logger() :
    logger = log.getLogger()
    logger.setLevel(log.NOTSET)
    logger.addHandler(log.StreamHandler(stream=sys.stderr))
    logger.addHandler(log.FileHandler(LOGS_FILE, mode='a'))


def main() :
    log.info('Starting roboserv.')
    application = Application(BASE_DIR, PID_FILE)
    application.listen(SERV_PORT)
    application.run()


def dmain():
    """ On UNIX system, and perhups on Cygwin this function will create a deamon. """
    pid = 0
    try :
        pid = os.fork()
    except OSError, e :
        raise Exception, '%s [%d]' % (e.strerror, e.errno)
    
    if pid == 0 :
        os.setsid()
        main()
    else :
        os._exit(0)


if __name__ == '__main__' :
    init_logger()
    if sys.platform.startswith('win32'):
        main()
    else:
        main()

