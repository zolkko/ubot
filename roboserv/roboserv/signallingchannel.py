# -*- coding: utf-8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

import rtc
import sdp
import logging as log

from tornado.websocket import WebSocketHandler


__all__ = ['SignallingChannelHandler']


STATE_UNKNOWN = 0x00
STATE_START = 0x01
STATE_SDP_DESCR = 0x02
STATE_SDP_CANDIDATE = 0x03
STATE_DONE = 0x04
STATE_ERROR  = 0xfe
STATE_CLOSED = 0xff


class SignallingChannelHandler(WebSocketHandler):
    """
    UDP dynamic port range: 49152-65535
    """
    
    state = STATE_START
    
    remote_sdescr = None
    
    local_sdescr = None
    
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
        Method determines which media available streams and
        sends session description back to web-application.
        
        @type msg: C{str}
        @param msg: Session description. it should be utf-8 encoded string
        """
        self.state = STATE_SDP_CANDIDATE
        self.remote_sdescr = rtc.SessionDescription(rtc.SdpType.offer, unicode(msg))
        self.local_sdescr = rtc.SessionDescription(rtc.SdpType.answer, self.remote_sdescr.sdp)
        self.write_message(self.local_sdescr.to_json().encode('utf-8'))
    
    def on_candidate(self, msg) :
        """
        This method selects most approprivate candidate.

        @type msg: C{str}
        @param msg: SDP candidate, utf-8 encoded string
        """
        self.state = STATE_SDP_CANDIDATE
        ice_candidate = rtc.IceCandidate.create_from_string(unicode(msg))
        log.info('ice_candidate: {0}'.format(ice_candidate))
        self.write_message(msg)
    
    def on_close(self):
        log.info('Signalling channel has been closed.')

