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
        if self.state == STATE_START :
            self.state = STATE_SDP_HANDSHAKE
            log.info('SDP message has been received. SDP content: {0}.'.format(message))
            self.write_message('accept'.encode('utf-8'))
            self.write_message(message)
        else :
            self.write_message('error'.encode('utf-8'))
            log.warn('Unsupported state {0}. Closing connection.'.format(self.state))
            self.close()
    
    def on_close(self):
        log.info('Signalling channel has been closed.')

