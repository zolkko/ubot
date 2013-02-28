# -*- coding: utf-8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

cdef extern from *:
    ctypedef char* const_char_ptr 'const char*'


cdef extern from 'ortp/port.h':
    void ortp_free(void * ptr)
    void ortp_malloc(size_t sz)
    char * ortp_strdup(const_char_ptr tmp)
    void * ortp_realloc(void * ptr, size_t sz)
    void * ortp_malloc0(size_t sz)


cdef extern from 'ortp/ortp.h':
    void ortp_init()
    void ortp_scheduler_init()
    void ortp_exit()


cdef extern from 'ortp/payloadtype.h':
    ctypedef struct c_PayloadType 'PayloadType':
        pass
    c_PayloadType *payload_type_new()
    c_PayloadType *payload_type_clone(c_PayloadType *payload)
    char *payload_type_get_rtpmap(c_PayloadType *pt)
    void payload_type_destroy(c_PayloadType *pt)
    void payload_type_set_recv_fmtp(c_PayloadType *pt, const_char_ptr fmtp)
    void payload_type_set_send_fmtp(c_PayloadType *pt, const_char_ptr fmtp)
    void payload_type_append_recv_fmtp(c_PayloadType *pt, const_char_ptr fmtp)
    void payload_type_append_send_fmtp(c_PayloadType *pt, const_char_ptr fmtp)


cdef extern from 'ortp/payloadtype.h':
    ctypedef struct c_RtpProfile 'RtpProfile':
        char * name
    c_RtpProfile * rtp_profile_new(const_char_ptr name)
    void rtp_profile_destroy(c_RtpProfile * prof)
    c_RtpProfile * rtp_profile_clone(c_RtpProfile * prof)
    c_RtpProfile * rtp_profile_clone_full(c_RtpProfile * prof)
    void rtp_profile_set_name(c_RtpProfile * prof, const_char_ptr name)
    # rtp_profile_clear_all(c_RtpProfile *prof)
    # PayloadType * rtp_profile_get_payload_from_mime(RtpProfile *profile, const_char_ptr mime)
    # PayloadType * rtp_profile_get_payload_from_rtpmap(RtpProfile *profile, const_char_ptr rtpmap)
    # int rtp_profile_get_payload_number_from_mime(RtpProfile *profile, const_char_ptr mime)
    # int rtp_profile_get_payload_number_from_rtpmap(RtpProfile *profile, const_char_ptr rtpmap)
    # int rtp_profile_find_payload_number(RtpProfile *prof, const_char_ptr mime, int rate, int channels)
    # PayloadType * rtp_profile_find_payload(RtpProfile *prof, const_char_ptr mime, int rate, int channels)
    # int rtp_profile_move_payload(RtpProfile *prof, int oldpos, int newpos)


cdef class PayloadType(object):
    cdef c_PayloadType * _payload_type
    
    def __init__(self):
        self._payload_type = NULL


cdef class RtpProfile(object):
    cdef c_RtpProfile * _profile
    
    def __init__(self, name = None):
        if name is None :
            self._profile = NULL
        else :
            if not isinstance(name, unicode) :
                raise ValueError('Unicode name expected.')
            str_name = name.encode('utf-8')
            self._profile = rtp_profile_new(str_name)
    
    def get_name(self):
        """
        Return profile's name or None if profile is not set.
        """
        if self._profile == NULL:
            return None
        else :
            return unicode(self._profile.name)
    
    def set_name(self, name):
        """
        Sets profile name. name parameter should be of unicode type.
        """
        if not isinstance(name, unicode) :
            raise ValueError('Unicode name expected.')
        
        if self._profile == NULL :
            str_name = name.encode('utf-8')
            self._profile = rtp_profile_new(str_name)
        else :
            str_name = name.encode('utf-8')
            rtp_profile_set_name(self._profile, str_name)
    
    def clone(self):
        """
        Creates profile clone.
        """
        if self._profile == NULL :
            return None
        else :
            oclone = RtpProfile()
            oclone._profile = rtp_profile_clone(self._profile)
            return oclone
    
    def clone_full(self):
        """
        Creates full profile clone.
        """
        if self._profile == NULL :
            return None
        else :
            oclone = RtpProfile()
            oclone._profile = rtp_profile_clone_full(self._profile)
            return oclone
    
    def __dealloc__(self):
        if self._profile != NULL:
            rtp_profile_destroy(self._profile)
            self._profile = NULL


def init():
    """
    Initializes oRTP library internals
    """
    ortp_init()

def scheduler_init():
    """
    Initializes scheduler
    """
    ortp_scheduler_init()

def exit():
    """
    Initializes exit method
    """
    ortp_exit()




