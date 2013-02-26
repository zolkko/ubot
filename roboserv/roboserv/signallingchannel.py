# -*- coding: utf-8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

import logging as log
import json
from tornado.websocket import WebSocketHandler


__all__ = ['SignallingChannelHandler']


STATE_UNKNOWN = 0x00
STATE_START = 0x01
STATE_SDP_DESCR = 0x02
STATE_SDP_CANDIDATE = 0x03
STATE_DONE = 0x04
STATE_ERROR  = 0xfe
STATE_CLOSED = 0xff


class Candidate(object):
    sdp_mline = 0
    sdp_mid = u''
    candidate = None


class SignallingChannelHandler(WebSocketHandler):
    state = STATE_START
    
    def open(self):
        self.state = STATE_SDP_DESCR
        log.info('Signalling channle was opened.')
    
    def on_message(self, message):
        log.info('Message has been received on signalling channel:\r\n{0}.'.format(message))
        if self.state == STATE_SDP_DESCR :
            self.on_session_description(message)
        elif self.state == STATE_SDP_CANDIDATE :
            self.on_candidate(message)
        else :
            log.warn('Unsupported state {0}. Signalling message will be ignored.'.format(self.state))
    
    def on_session_description(self, msg):
        """
        Method determines which media streams are available and
        sends session description back to web-application.

        @type msg: C{str}
        @param msg: Session description
        """
        self.state = STATE_SDP_CANDIDATE
        self.write_message(msg)
    
    def on_candidate(self, msg) :
        """
        This method selects most approprivate candidate.

        @type msg: C{str}
        @param msg: SDP candidate
        """
        self.state = STATE_SDP_CANDIDATE
        self.write_message(msg)
    
    def on_close(self):
        log.info('Signalling channel has been closed.')

