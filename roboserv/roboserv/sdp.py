# -*- encoding: utf8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

"""
As described in http://www.ietf.org/rfc/rfc2327.txt"
"""

import StringIO


__all__ = ['Candidate']


class CandidateComponent(object):
    __slots__ = ['rtp', 'rtcp', 'srtp', 'srtcp']
    rtp = 1
    rtcp = 2
    srtp = 3
    srtcp = 4


class MediaType(object):
    __slots__ = ['audio', 'video', 'application', 'data', 'control']
    
    audio = u'audio'
    video = u'video'
    application = u'application'
    data = u'data'
    control = u'control'


class SdpLineType(object):
    __stols__ = ['origin', 'bandwidth', 'connection', 'encryption_key', 'attribute']
    
    origin = u'o='
    bandwidth = u'b='
    connection = u'c='
    encryption_key = u'k='
    attribute = u'a'


class SdpLine(object):
    def __init__(self, sdp=None):
        if sdp is not None :
            self.parse_sdp(sdp.lstrip())
    
    def parse_sdp(self, sdp):
        """
        Parses and initializes class from SDP string.
        @type sdp: C{str}
        @param sdp: sdp bandwidth unicode string.
        """
        raise NotImplementedError()
    
    def to_sdp(self):
        """
        Converts object into SDP unicode representation.
        Method returns unicode string.
        """
        raise NotImplementedError()
    
    def __str__(self):
        return self.to_sdp()


class SdpOrigin(SdpLine):
    """
    The "o=" field gives the originator of the session
    """
    
    username = None
    session_id = None
    version = None
    network_type = None
    address_type = None
    address = None
    
    def parse_sdp(self, sdp):
        if not sdp.startswith(SdpLineType.origin) :
            raise ValueType('Origin SDP line expected.')
        self.username, self.session_id, self.version, self.network_type, self.address_type, self.address = sdp[2:].split(' ')
    
    def to_sdp(self):
        return u'o={0} {1} {2} {3} {4} {5}'.format(self.username, self.session_id, self.version, self.network_type, self.address_type, self.address)


class SdpBandwidth(SdpLine):
    """
    This specifies the proposed bandwidth to be used by the
    session or media, and is optional.
    """
    
    modifier = None
    value = None
    
    def parse_sdp(self, sdp):
        if not sdp.startswith(SdpLineType.bandwidth) :
            raise ValueType('Bandwidth SDP line expected.')
        self.modifier, self.value = sdp[2:].split(':')
    
    def to_sdp(self):
        return u'b={0}:{1}'.format(self.modifier, self.value)


class SdpConnection(SdpLine):
    """
    Connection Data
    """
    
    network_type = None
    address_type = None
    connection_address = None
    
    def parse_sdp(self, sdp):
        if not sdp.startswith(SdpLineType.connection) :
            raise ValueType('Connection data SDP line expected.')
        self.network_type, self.address_type, self.connection_address = sdp[2:].split(' ')
    
    def to_sdp(self):
        return u'c={0} {1} {2}'.format(self.network_type, self.address_type, self.connection_address)


class SdpEncryptionKey(SdpLine):
    """
    Represents k= line.
    """
    
    method = None
    encyption_key = None
    
    def parse_sdp(self, sdp):
        if not self.startswith(SdpLineType.encryption_key) :
            raise ValueError('Encryption key SDP line expected.')
        tmp = sdp[2:].split(' ')
        if len(tmp) == 2 :
            self.method, self.encryption_key = tmp
        else :
            self.method = tmp[0]
            self.encryption_key = None
    
    def to_sdp(self):
        if self.encryption_key is not None :
            return u'k={0}:{1}'.format(self.method, self.encryption_key)
        else :
            return u'k={0}'.format(self.method)


class SdpAttribute(SdpLine):
    name = None
    value = None
    
    def parse_sdp(self, sdp):
        if not sdp.startswith(SdpLineType.attribute) :
            raise ValueError('SDP attribute line expected.')
        tmp = sdp[2:].split(':')
        self.name = tmp[0]
        if len(tmp) == 2:
            self.value = tmp[1]
        elif len(tmp) > 2 :
            self.value = u':'.join(tmp[1:])
    
    def to_sdp(self):
        if self.value is not None :
            return u'a={0}:{1}'.format(self.name, self.value)
        else :
            return u'a={0}'.format(self.name)


class SdpGlobalDescription(object):
    attributes = []
    bandwidth = None
    connection = None
    encryption_key = None
    origin = None


class SdpMediaDescription(object):
    attributes = []   # Gets the list of "a" lines from the SDP.
    bandwidth  = None # Gets the details of the "b" line from the SDP.
    connection = None # Gets the details of the "c" line from the SDP.
    encryption_key = None # Gets the details of the "k" line from the SDP.
    formats = None    # Gets or sets tokens found at the end of the "m" line.
    media_name = None # Gets or sets the type of media represented by the "m" line. Typical values include "audio" and "video".
    port = 0          # Gets or sets the port where the media should be directed.
    port_count = -1   # Gets the number of sequential ports starting with the value of the Port property.
    transport_protocol = None # Gets or sets the transport protocol specified in the "m" line. For example, "RTP/AVP". The default value "RTP/AVP" is used when serializing if nothing else is specified.



SDP_LINE_MAP = {SdpLineType.origin: SdpOrigin,
                SdpLineType.bandwidth: SdpBandwidth,
                SdpLineType.connection: SdpConnection,
                SdpLineType.encryption_key: SdpEncryptionKey,
                SdpLineType.attribute: SdpAttribute}


class SdpDescription(object):
    global_description = None
    media_description = None
    
    def parse_sdp(self, sdp):
        for line in (StringIO.StringIO(sdp)).readlines() :
            line = line.lstrip()
            if len(line) > 2 :
                prefix = line[:2]
                if prefix in SDP_LINE_MAP :
                    obj = SDP_LINE_MAP[prefix]()
                    obj.parse_sdp(line)
                else :
                    pass # TODO: unknown
            else :
                raise ValueError('Invalid "{0}" line inside SDP stream.'.format(line))
    
    def to_sdp(self):
        raise NotImplementedError()


#
# temporary class which parses candidate line
#
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
    
    def __init__(self, sdp=None) :
        """
        @type sdp: C{unicode}
        @param sdp: valid python string
        """
        if sdp is not None :
            if not sdp.startswith(SDP_ATTRIBUTE + SDP_ATTR_CANDIDATE) :
                raise ValueError('SDP candidate attribute expected.')
            params = sdp.lstrip().split(SDP_ATTR_CANDIDATE)[1].split(' ')
            self.foundation = params[0]
            self.component = int(params[1], 10)
            self.protocol = params[2]
            self.weight = int(params[3], 10)
            self.addr = params[4]
            self.port = params[5]
            for i in range(6, len(params), 2) :
                attr = params[i]
                if (i + 1) >= len(params) :
                    break
                if attr == u'typ' :
                    self.typ = params[i + 1]
                elif attr == u'raddr' :
                    self.raddr = params[i + 1]
                elif attr == u'rport' :
                    self.rport = params[i + 1]
                elif attr == 'generation' :
                    self.generation = int(params[i + 1], 10)
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
    
    def __str__(self):
        return self.to_sdp()

