# -*- encoding: utf8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

import json
import sdp


__all__ = ['IceCandidate', 'SdpType', 'SessionDescription']


class IceCandidate(object):
    sdp_mline_index = 0
    sdp_mid = u''
    candidate = None
    
    @staticmethod
    def create_from_string(string):
        d = json.loads(string)
        res = IceCandidate()
        if 'sdpMLine' in d :
            res.sdp_mline_index = int(d['sdpMLineIndex'], 10)
        if 'sdpMid' in d :
            res.sdp_mid = d['sdpMid']
        if 'candidate' in d :
            res.candidate = sdp.Candidate(d['candidate'])
        return res
    
    def __str__(self):
        return '<sdpMLineIndex:{0}; sdpMid:{1}; candidate:{2}>'.format(self.sdp_mline_index, self.sdp_mid, self.candidate)


class SdpType(object):
    __slots__ = ['offer', 'answer', 'pranswer']
    offer = u'offer'
    answer = u'answer'
    pranswer = u'pranswer'


class SessionDescription(object):
    type = SdpType.offer
    sdp = u''
    
    def __init__(self, typ, sdp) :
        self.type = typ
        self.sdp = sdp
    
    def to_json(self):
        return json.dumps({u'type': self.type, u'sdp': self.sdp})

