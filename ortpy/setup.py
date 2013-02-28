# -*- coding: utf-8 -*-
# vim:set et tabstop=4 shiftwidth=4 nu nowrap fileencoding=utf-8:

import sys
from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext


if sys.platform == 'win32' :
    libpath = [r'C:\Program Files\Microsoft SDKs\Windows\v6.0A\Lib',
               r'C:\Program Files (x86)\Microsoft SDKs\Windows\v6.0A\Lib',
               r'third_party']
    libs    = ['ortp', 'WS2_32', 'WSock32', 'WinMM', 'qwave']
    incpath = [r'third_party\ortp-0.20.0\include',
               r'C:\Program Files\Microsoft SDKs\Windows\v6.0A\Include',
               r'C:\Program Files (x86)\Microsoft SDKs\Windows\v6.0A\Include']
    defines = [('WIN32', 1)]
else :
    libpath = []
    libs    = []
    incpath = [r'third_party/ortp-0.20.0/include']
    defines = []


setup(
    cmdclass = {'build_ext': build_ext},
    ext_modules = [Extension('ortpy', ['ortpy.pyx'],
                                      libraries = libs,
                                      define_macros = defines,
                                      library_dirs = libpath,
                                      include_dirs = incpath)])

