# -*- coding: utf-8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

import logging as log
from tornado.websocket import WebSocketHandler


__all__ = ['SignallingChannelHandler']


STATE_UNKNOWN = 0x00
STATE_START = 0x01
STATE_SDP_HANDSHAKE = 0x02
STATE_CLOSED = 0xff


class SignallingChannelHandler(WebSocketHandler):
    state = STATE_UNKNOWN
    
    def open(self):
        self.state = STATE_START
        log.info('Signalling channle was opened.')
    
    def on_message(self, message):
        log.info('message: {0}.'.format(message))
        self.write_message(message)
    
    def on_close(self):
        log.info('Signalling channel has been closed.')

