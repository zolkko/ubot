import sys
import os
import unittest

sys.path.insert(1, os.path.abspath(os.path.curdir + os.sep + ".."))
import roboserv
from roboserv import sdp



SDP_CANDIDATE_1 = u'a=candidate:331 1 udp 2113937151 169.254.42.204 65108 typ host generation 0'
SDP_CANDIDATE_2 = u'a=candidate:187 1 udp 1845501695 89.22.50.59 65107 typ srflx raddr 192.168.194.114 rport 65107 generation 0'


class CandidateTest(unittest.TestCase):
    def test_parse_1(self):
        c1 = sdp.Candidate(SDP_CANDIDATE_1)
        self.assertEquals(u'331', c1.foundation)
        self.assertEquals(1, c1.component)
        self.assertEquals(u'udp', c1.protocol)
        self.assertEquals(u'169.254.42.204', c1.addr)
        self.assertEquals(u'65108', c1.port)
        self.assertEquals(u'host', c1.typ)
        self.assertIsNone(c1.raddr)
        self.assertIsNone(c1.rport)
        self.assertEquals(0, c1.generation)
        self.assertEquals(SDP_CANDIDATE_1, c1.to_sdp())
    
    def test_parse_2(self):
        c = sdp.Candidate(SDP_CANDIDATE_2)
        self.assertEquals(u'187', c.foundation)
        self.assertEquals(1, c.component)
        self.assertEquals(u'udp', c.protocol)
        self.assertEquals(u'89.22.50.59', c.addr)
        self.assertEquals(u'65107', c.port)
        self.assertEquals(u'srflx', c.typ)
        self.assertEquals(u'192.168.194.114', c.raddr)
        self.assertEquals(u'65107', c.rport)
        self.assertEquals(0, c.generation)
        self.assertEquals(SDP_CANDIDATE_2, c.to_sdp())


if __name__ == "__main__":
    unittest.main()
