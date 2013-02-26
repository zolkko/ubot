# -*- encoding: utf8 -*-
# sdp.py

import StringIO


__all__ = ['StreamGroup']

class StreamGroup(object):
    streams = list()
    name = u''


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


class SessionDescriptor(object) :
    def __init__(self):
        pass


class Candidate(object) :
    """Represents SDP-candidate"""
    
    __slots__ = ["candidate_prefix", "type_host", "type_srflx", "type_relay",
                 "transport_udp", "transport_tcp", "__hash", "__proto",
                 "__transport",  "__priority", "__address", "__port", "__type",
                 "__generation", "__name", "__network_name", "__username",
                 "__password"]
    
    candidate_prefix = "candidate:"
    
    transport_udp = "udp"
    transport_tcp = "tcp"
    
    type_host  = "host"
    type_srflx = "srflx"
    type_relay = "relay"
    
    def __init__(self) :
        # TODO: Initialize hash with a random genrated value like 3290264084
        self.__hash = None
        self.__proto = 1
        self.__transport = Candidate.transport_udp
        self.__priority = 0.0
        self.__address = "127.0.0.1"
        self.__port = 0
        self.__type = Candidate.type_host
        # optional parameters
        self.__generation = 0
        self.__name = None
        self.__network_name = None
        self.__username = None
        self.__password = None
    
    def _set_hash(self, value) :
        self.__hash = value
    
    def _set_proto(self, value) :
        """Sets protocol. Where 1 stands for RTC and 2 stands for SRTC"""
        if (value != 1) and (value != 2) :
            raise ValueError("Unsupported protocol %s." % value)
        self.__proto = value
    
    def _set_transport(self, value) :
        lvalue = value.lower()
        if (lvalue != Candidate.transport_udp) and (lvalue != Candidate.transport_tcp) :
            raise ValueError("Unsupported transport type %s." % value)
        self.__transport = lvalue
    
    def _set_priority(self, value) :
        if not isinstance(value, float) :
            raise ValueError("Invalid priority value %s." % value)
        self.__priority = value
    
    def _set_address(self, value):
        self.__address = value
    
    def _set_port(self, value):
        if not isinstance(value, int) :
            raise ValueError("Invalid port value %s." % value)
        self.__port = value
    
    def _set_type(self, value):
        lvalue = value.lower()
        if (lvalue != Candidate.type_host) and (lvalue != Candidate.type_srflx) and (lvalue != Candidate.type_relay) :
            raise ValueError("Unsuported candidate type %s." % value)
        self.__type = lvalue
    
    def _set_generation(self, value):
        if (not value is None) and (not isinstance(value, int)) :
            raise ValueError("Invalid generation value %s." % value)
        self.__generation = value
    
    def _set_name(self, value):
        self.__name = value
    
    def _set_network_name(self, value):
        self.__network_name = value
    
    def _set_username(self, value):
        self.__username = value
    
    def _set_password(self, value):
        self.__password = value
    
    hash = property(fget = lambda self : self.__hash, fset = _set_hash)
    
    proto = property(fget = lambda self : self.__proto, fset = _set_proto)
    
    transport = property(fget = lambda self : self.__transport, fset = _set_transport)
    
    priority = property(fget = lambda self : self.__priority, fset = _set_priority)
    
    address = property(fget = lambda self : self.__address, fset = _set_address)
    
    port = property(fget = lambda self : self.__port, fset = _set_port)
    
    type = property(fget = lambda self : self.__type, fset = _set_type)
    
    generation = property(fget = lambda self : self.__generation, fset = _set_generation)
    
    name = property(fget = lambda self : self.__name, fset = _set_name )
    
    network_name = property(fget = lambda self : self.__network_name, fset = _set_network_name)
    
    username = property(fget = lambda self : self.__username, fset = _set_username)
    
    password = property(fget = lambda self : self.__password, fset = _set_password)
    
    def __str__(self):
        res = [str(self.hash), str(self.proto), self.transport, str(self.priority).rstrip("0").rstrip("."), self.address, str(self.port), SdpAttributes.candidate_typ, self.type]
        if not self.name is None :
            res.append(SdpAttributes.candidate_name)
            res.append(self.name)
        if not self.network_name is None :
            res.append(SdpAttributes.candidate_network_name)
            res.append(self.network_name)
        if not self.username is None :
            res.append(SdpAttributes.candidate_username)
            res.append(self.username)
        if not self.password is None :
            res.append(SdpAttributes.candidate_password)
            res.append(self.password)
        if not self.generation is None :
            res.append(SdpAttributes.candidate_generation)
            res.append(str(self.generation))
        return SdpPrefix.attribute + Candidate.candidate_prefix + " ".join(res)
    
    def to_sdp(self) :
        return self.__str__()
    
    @staticmethod
    def create_from_sdp(sdpLine) :
        """Creates Candidate object from sdp-candidate line"""
        cparts = sdpLine[len(SdpPrefix.attribute):].rstrip().split(" ")
        if (len(cparts) < 8) or (not cparts[0].startswith(Candidate.candidate_prefix)) or (cparts[6] != SdpAttributes.candidate_typ) :
            raise ValueError("Malformed candidate string %s" % sdpLine)
        #
        candidate = Candidate()
        candidate.hash = cparts[0].split(":")[1]
        candidate.proto = int(cparts[1], 10)
        candidate.transport = cparts[2]
        candidate.priority = float(cparts[3])
        candidate.address = cparts[4]
        candidate.port = int(cparts[5], 10)
        candidate.type = cparts[7]
        # Optional parameters. Generation is 0 by default.
        candidate.generation = 0
        for i in range(0, len(cparts), 2):
            curpart = cparts[i]
            if curpart == SdpAttributes.candidate_name :
                candidate.name = cparts[i + 1]
            elif curpart == SdpAttributes.candidate_network_name :
                candidate.network_name = cparts[i + 1]
            elif curpart == SdpAttributes.candidate_username :
                candidate.username = cparts[i + 1]
            elif curpart == SdpAttributes.candidate_password :
                candidate.password = cparts[i + 1]
            elif curpart == SdpAttributes.candidate_generation :
                candidate.generation = int(cparts[i + 1], 10)
        return candidate


def sdp_deserialize_candidates(sdpMessage) :
    """Deserialize SDP candidates into list of Candidate objects"""
    candidates = list()
    msg = StringIO.StringIO(sdpMessage)
    try :
        for line in msg:
            line.lstrip(line)
            if line.startswith(SdpPrefix.attribute) :
                candidates.append(Candidate.create_from_sdp(line))
    finally :
        msg.close()
    return candidates

