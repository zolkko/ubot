import sys
import os
import unittest

sys.path.insert(1, os.path.abspath(os.path.curdir + os.sep + ".."))
import roboserv
from roboserv import sdp


SDP_MSG = ("v=0\r\n"
    "o=- 0 0 IN IP4 127.0.0.1\r\n"
    "s=\r\n"
    "c=IN IP4 0.0.0.0\r\n"
    "t=0 0\r\n"
    "m=audio 1 RTP/AVPF 103 104\r\n"
    "a=candidate:1 1 udp 1 127.0.0.1 1234 typ host name rtp network_name eth0 username user_rtp password password_rtp generation 0\r\n"
    "a=candidate:1 2 udp 1 127.0.0.1 1235 typ host name rtcp network_name eth0 username user_rtcp password password_rtcp generation 0\r\n"
    "a=mid:audio\r\n"
    "a=rtcp-mux\r\n"
    "a=crypto:1 AES_CM_128_HMAC_SHA1_32 inline:NzB4d1BINUAvLEw6UzF3WSJ+PSdFcGdUJShpX1Zj|2^20|1:32 \r\n"
    "a=rtpmap:103 ISAC/16000\r\n"
    "a=rtpmap:104 ISAC/32000\r\n"
    "a=ssrc:1 cname:stream_1_cname mslabel:local_stream_1 label:local_audio_1\r\n"
    "a=ssrc:4 cname:stream_2_cname mslabel:local_stream_2 label:local_audio_2\r\n"
    "m=video 1 RTP/AVPF 120\r\n"
    "a=candidate:1 2 udp 1 127.0.0.1 1236 typ host name video_rtcp network_name eth0 username user_video_rtcp password password_video_rtcp generation 0\r\n"
    "a=candidate:1 1 udp 1 127.0.0.1 1237 typ host name video_rtp network_name eth0 username user_video_rtp password password_video_rtp generation 0\r\n"
    "a=mid:video\r\n"
    "a=crypto:1 AES_CM_128_HMAC_SHA1_80 inline:d0RmdmcmVCspeEc3QGZiNWpVLFJhQX1cfHAwJSoj|2^20|1:32 \r\n"
    "a=rtpmap:120 VP8/90000\r\n"
    "a=ssrc:2 cname:stream_1_cname mslabel:local_stream_1 label:local_video_1\r\n"
    "a=ssrc:3 cname:stream_1_cname mslabel:local_stream_1 label:local_video_2\r\n"
    "a=ssrc:5 cname:stream_2_cname mslabel:local_stream_2 label:local_video_3\r\n")

SDP_CANDIDATE_ONE = "a=candidate:1 1 udp 1 127.0.0.1 1234 typ host name rtp network_name eth0 username user_rtp password password_rtp generation 0"
SDP_CANDIDATE_TWO = "a=candidate:1 2 TCP 1 127.0.0.1 1235 typ RELAY generation 0"
SDP_CANDIDATE_REST = (
    "a=candidate:1 2 udp 1 127.0.0.1 1236 typ host name video_rtcp network_name eth0 username user_video_rtcp password password_video_rtcp generation 0\r\n"
    "a=candidate:1 1 udp 1 127.0.0.1 1237 typ host name video_rtp network_name eth0 username user_video_rtp password password_video_rtp generation 0\r\n")

SDP_CANDIDATE = SDP_CANDIDATE_ONE + "\r\n" + SDP_CANDIDATE_TWO + "\r\n" + SDP_CANDIDATE_REST


class SdpCandidateTest(unittest.TestCase):
    def setUp(self):
        self.candidates = sdp.sdp_deserialize_candidates(SDP_CANDIDATE)
    
    def test_count(self):
        self.assertEqual(len(self.candidates), 4)
    
    def test_candidate_properties(self) :
        c = self.candidates[0]
        self.assertEqual(c.hash, "1")
        self.assertEqual(c.proto, 1)
        self.assertEqual(c.transport, sdp.Candidate.transport_udp)
        self.assertEqual(c.priority, 1.0)
        self.assertEqual(c.address, "127.0.0.1")
        self.assertEqual(c.port, 1234)
        self.assertEqual(c.type, sdp.Candidate.type_host)
        self.assertEqual(c.name, "rtp")
        self.assertEqual(c.network_name, "eth0")
        self.assertEqual(c.username, "user_rtp")
        self.assertEqual(c.password, "password_rtp")
        self.assertEqual(c.generation, 0)
    
    def test_upper_case_values(self) :
        c = self.candidates[1]
        self.assertEqual(c.transport, sdp.Candidate.transport_tcp)
        self.assertEqual(c.type, sdp.Candidate.type_relay)
    
    def test_sdp_serialization(self) :
        c = self.candidates[0]
        line = c.to_sdp()
        self.assertEqual(line, SDP_CANDIDATE_ONE)
    
    def test_sdp_serialize_short(self) :
        c = self.candidates[1]
        line = str(c)
        self.assertEqual(line, SDP_CANDIDATE_TWO.lower())


if __name__ == "__main__":
    unittest.main()
