# -*- encoding: utf8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

import re
import StringIO


__all__ = ['SDP_CANDIDATE_PROTO_RTP',
           'SDP_CANDIDATE_PROTO_RTCP',
           'SDP_CANDIDATE_PROTO_SRTP',
           'SDP_CANDIDATE_PROTO_SRTCP',
           'Candidate']


SDP_CANDIDATE_COMPONENT_RTP   = 1
SDP_CANDIDATE_COMPONENT_RTCP  = 2
SDP_CANDIDATE_COMPONENT_SRTP  = 3
SDP_CANDIDATE_COMPONENT_SRTCP = 4


class Candidate(object):
    """
    Represents SDP candidate string
    """
    
    foundation = None
    component = -1
    protocol = None
    weight = 0
    addr = None
    port = 0
    typ = None
    raddr = None
    rport = None
    generation = None
    
    def __init__(self, sdp = None) :
        """
        @type sdp: C{unicode}
        @param sdp: valid python string
        """
        if sdp is not None :
            r = re.split(u'\\s+', sdp)
            self.foundation = r[0][12:]
            self.component = int(r[1], 10)
            self.protocol = r[2]
            self.weight = int(r[3], 10)
            self.addr = r[4]
            self.port = r[5]
            for i in range(6, len(r), 2) :
                attr = r[i]
                if (i + 1) >= len(r) :
                    break
                if attr == u'typ' :
                    self.typ = r[i + 1]
                elif attr == u'raddr' :
                    self.raddr = r[i + 1]
                elif attr == u'rport' :
                    self.rport = r[i + 1]
                elif attr == 'generation' :
                    self.generation = int(r[i + 1], 10)
                # ignore unknown attributes
    
    def to_sdp(self):
        """
        Generates string SDP candidate representation.
        """
        res = u'a=candidate:{0} {1} {2} {3} {4} {5}'.format(self.foundation, self.component, self.protocol, self.weight, self.addr, self.port)
        if self.typ is not None :
            res += u' typ {0}'.format(self.typ)
        if self.raddr is not None :
            res += u' raddr {0}'.format(self.raddr)
        if self.rport is not None :
            res += u' rport {0}'.format(self.rport)
        if self.generation is not None :
            res += u' generation {0}'.format(self.generation)
        return res
 

class SdpPrefix(object):
    __slots__ = ["version", "origin", "session_name", "session_info",
    "session_email", "session_phone", "session_connection",
    "session_bandwidth", "timing", "repeat_times", "time_zone",
    "encoding_key", "media", "attribute"]
    #
    version = "v="
    origin = "o="
    session_name = "s="
    session_info = "i="
    session_uri = "u="
    session_email = "e="
    session_phone = "p="
    session_connection = "c="
    session_bandwidth = "b="
    timing = "t="
    repeat_times = "r="
    time_zone = "z="
    encription_key = "k="
    media = "m="
    attribute = "a="


class SdpAttributes(object):
    __slots__ = ["group", "mid", "rtcp_mux", "ssrc", "cname", "mslabel",
    "label", "crypto", "candidate", "candidate_typ", "candidate_name",
    "candidate_network_name", "candidate_username", "candidate_password",
    "candidate_generation", "rtpmap"]
    #
    group = "group:"
    mid = "mid:"
    rtcp_mux = "rtcp-mux"
    # sync source
    ssrc = "ssrc:"
    # canonical name
    cname = "cname:"
    mslabel = "mslabel:"
    label = "label:"
    crypto = "crypto:"
    candidate = "candidate:"
    candidate_typ = "typ"
    candidate_name = "name"
    candidate_network_name = "network_name"
    candidate_username = "username"
    candidate_password = "password"
    candidate_generation = "generation"
    rtpmap = "rtpmap:"

