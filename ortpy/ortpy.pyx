# -*- coding: utf-8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

cdef extern from *:
    ctypedef char* const_char_ptr 'const char*'


cdef extern from 'ortp/port.h':
    ctypedef unsigned char bool_t
    ctypedef unsigned int  uint32_t
    ctypedef unsigned char uint8_t
    void ortp_free(void * ptr)
    void ortp_malloc(size_t sz)
    char * ortp_strdup(const_char_ptr tmp)
    void * ortp_realloc(void * ptr, size_t sz)
    void * ortp_malloc0(size_t sz)


cdef extern from 'ortp/payloadtype.h':
    ctypedef struct c_PayloadType 'PayloadType':
        pass
    c_PayloadType *payload_type_new()


cdef class PayloadType(object):
    cdef c_PayloadType * _payload_type
    
    def __init__(self):
        self._payload_type = NULL


cdef extern from 'ortp/payloadtype.h':
    ctypedef struct c_RtpProfile 'RtpProfile':
        char * name
    c_RtpProfile * rtp_profile_new(const_char_ptr name)
    void rtp_profile_destroy(c_RtpProfile * prof)
    c_RtpProfile * rtp_profile_clone(c_RtpProfile * prof)
    c_RtpProfile * rtp_profile_clone_full(c_RtpProfile * prof)
    void rtp_profile_set_name(c_RtpProfile * prof, const_char_ptr name)


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


cdef extern from 'ortp/ortp.h':
    void ortp_init()
    void ortp_scheduler_init()
    void ortp_exit()
    void ortp_set_log_level_mask(int levelmask)


ORTP_DEBUG = 1
ORTP_MESSAGE = 1 << 1
ORTP_WARNING = 1 << 2
ORTP_ERROR = 1 << 3
ORTP_FATAL = 1 << 4
ORTP_LOGLEV_END = 1 << 5

ORTP_LOG_DEFAULT = ORTP_DEBUG | ORTP_MESSAGE | ORTP_WARNING | ORTP_ERROR


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

def set_log_level_mask(mask) :
    """
    Sets log level mask.
    """
    ortp_set_log_level_mask(mask)


cdef extern from 'ortp/rtpsession.h':
    cdef enum RtpSessionMode :
        RTP_SESSION_RECVONLY,
        RTP_SESSION_SENDONLY,
        RTP_SESSION_SENDRECV
    
    cdef struct _RtpSession:
        pass
    
    ctypedef struct c_RtpSession 'RtpSession':
        pass
    
    c_RtpSession *rtp_session_new(int mode)
    void rtp_session_destroy(c_RtpSession * ptr)
    void rtp_session_set_scheduling_mode(c_RtpSession *session, int yesno)
    void rtp_session_set_blocking_mode(c_RtpSession *session, int yesno)
    void rtp_session_set_connected_mode(c_RtpSession *session, bool_t yesno)
    void rtp_session_set_symmetric_rtp (c_RtpSession *session, bool_t yesno)
    int rtp_session_set_payload_type(c_RtpSession *session, int pt)
    int rtp_session_set_local_addr(c_RtpSession *session, const_char_ptr addr, int port)
    void rtp_session_enable_adaptive_jitter_compensation(c_RtpSession *session, bool_t val)
    void rtp_session_set_jitter_compensation(c_RtpSession *session, int milisec)
    int rtp_session_recv_with_ts(c_RtpSession *session, uint8_t *buffer, int len, uint32_t ts, int *have_more)


cdef extern from 'ortp/rtpsignaltable.h':
    ctypedef void (*RtpCallback)(c_RtpSession *, ...)


cdef extern from 'ortp/rtpsession.h':
    int rtp_session_signal_connect(c_RtpSession *session, const_char_ptr signal_name, RtpCallback cb, unsigned long user_data)


SESSION_MODE_RECVONLY = 0
SESSION_MODE_SENDONLY = 1
SESSION_MODE_SENDRECV = 2


cdef class __Callback(object):
    def __init__(self, callback, usr_data = None) :
        if not callable(callback) :
            raise ValueError('A callable object expected.')
        self._callback = callback
        self._usr_data = usr_data
    
    def __call__(self):
        if self._usr_data is None :
            self._callback()
        else :
            self._callback(self._usr_data)


cdef class __SignalTable(object):
    
    _signals = []
    
    cdef append_signal(self, c_RtpSession * session, const_char_ptr signal, __Callback callback):
        self._signals.append(callback)
        index = len(self._signals) - 1
        rtp_session_signal_connect(session, signal, <RtpCallback>rtp_session_signal_callback, <unsigned long> index)
    
    def callback(self, index, params) :
        if index >= 0 and index < len(self._signals) :
            self._signals[index]()
        else :
            raise IndexError('callback index {0} is out of range.'.format(index))


cdef __SignalTable signal_table
signal_table = __SignalTable()


cdef class RtpSession(object):
    """
    Incapsulates RTP/RTCP session
    """
    
    cdef c_RtpSession * _session
    
    def __init__(self, mode):
        mode = RTP_SESSION_RECVONLY
        if mode == SESSION_MODE_SENDONLY :
            mode = RTP_SESSION_SENDONLY
        elif mode == SESSION_MODE_SENDRECV :
            mode = RTP_SESSION_SENDRECV
        self._session = rtp_session_new(mode)
    
    def set_scheduling_mode(self, yesno):
        rtp_session_set_scheduling_mode(self._session, yesno)
    
    def set_blocking_mode(self, yesno):
        rtp_session_set_blocking_mode(self._session, yesno)
    
    def set_connected_mode(self, yesno):
        rtp_session_set_connected_mode(self._session, yesno)
    
    def set_symmetric_rtp(self, yesno):
        rtp_session_set_symmetric_rtp(self._session, yesno)
    
    def set_payload_type(self, pt):
        rtp_session_set_payload_type(self._session, pt)
    
    def set_local_addr(self, addr, port):
        if not isinstance(addr, unicode) :
            raise TypeError('addr parameter should be of unicode type.')
        if not isinstance(port, int):
            raise TypeError('port parameter should be of int type.')
        str_addr = addr.encode('utf-8')
        rtp_session_set_local_addr(self._session, str_addr, port)
    
    def enable_adaptive_jitter_compensation(self, yesno):
        rtp_session_enable_adaptive_jitter_compensation(self._session, yesno)
    
    def set_jitter_compensation(self, milisec):
        rtp_session_set_jitter_compensation(self._session, milisec)
    
    def signal_connect(self, signal, callback, user_data):
        if not isinstance(signal, unicode) :
            raise TypeError('signal parameter should be of unicode type.')
        if u'ssrc_changed' == signal :
            global signal_table
            str_signal = signal.encode('utf-8')
            signal_table.append_signal(self._session, str_signal, __Callback(callback, user_data))
        else :
            raise ValueError('signal is not supported.')
    
    def __dealloc__(self):
        if self._session != NULL :
            rtp_session_destroy(self._session)
            self._session = NULL


cdef extern from 'stdarg.h':
    ctypedef struct va_list:
        pass
    ctypedef struct fake_type:
        pass
    void  va_start(va_list, void* arg)
    void* va_arg(va_list, fake_type)
    void  va_end(va_list)
    fake_type ul_type 'unsigned long'


cdef rtp_session_signal_callback(c_RtpSession * session, ...) :
    cdef va_list args
    va_start(args, <void*>session)
    params = []
    cdef unsigned long val = 1
    while val != 0 :
        val = <unsigned long>va_arg(args, ul_type)
        params.append(val)
    va_end(args)
    index = params[-1:]
    if len(index) == 1 :
        global signal_table
        signal_table.callback(index[0], params[:-1])

