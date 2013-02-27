# -*- encoding: utf8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

import sys
import os
import socket
import errno
import logging as log

from tornado.ioloop import IOLoop
from tornado.iostream import IOStream
from tornado.platform.auto import set_close_exec


__all__ = ['UDPServer']


class UDPServer(object):
    """
    Non-blocking UDP server. Repeats tornado.TCPServer code.
    """
    def __init__(self, io_loop = None):
        self.io_loop = io_loop
        self._sockets = {}
    
    def listen(self, port, address=''):
        sockets = bind_sockets(port, address=address)
        self.add_sockets(sockets)
    
    def add_sockets(self, sockets):
        if self.io_loop is None:
            self.io_loop = IOLoop.instance()
        for sock in sockets:
            self._sockets[sock.fileno()] = sock
            add_data_handler(sock, self.handle_data, io_loop=self.io_loop)
    
    def stop(self):
        for fd, sock in self._sockets.iteritems():
            self.io_loop.remove_handler(fd)
            sock.close()
    
    def handle_data(self, data, address):
        raise NotImplementedError()


def add_data_handler(sock, callback, io_loop=None):
    if io_loop is None:
        io_loop = IOLoop.instance()
    def data_handler(fd, events):
        while True :
            try :
                data, address = sock.recvfrom(1024)
            except socket.error, e :
                if e.args[0] in (errno.EWOULDBLOCK, errno.EAGAIN) :
                    return
                raise
            callback(data, address)
    io_loop.add_handler(sock.fileno(), data_handler, IOLoop.READ)


def bind_sockets(port, address=None, family=socket.AF_INET, backlog=128):
    sockets = []
    if address == '':
        address = None
    flags = socket.AI_PASSIVE
    if hasattr(socket, 'AI_ADDRCONFIG'):
        flags |= socket.AI_ADDRCONFIG
    for res in set(socket.getaddrinfo(address, port, family, socket.SOCK_DGRAM, 0, flags)):
        af, socktype, proto, canonname, sockaddr = res
        sock = socket.socket(af, socktype, proto)
        set_close_exec(sock.fileno())
        if os.name != 'nt':
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        if af == socket.AF_INET6:
            if hasattr(socket, 'IPPROTO_IPV6'):
                sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        sock.setblocking(0)
        sock.bind(sockaddr)
        # sock.listen(backlog)
        sockets.append(sock)
    return sockets

