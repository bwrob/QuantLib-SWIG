# -*- coding: iso-8859-1 -*-
"""
 Copyright (C) 2000, 2001, 2002, 2003 RiskMap srl

 This file is part of QuantLib, a free-software/open-source library
 for financial quantitative analysts and developers - http://quantlib.org/

 QuantLib is free software: you can redistribute it and/or modify it
 under the terms of the QuantLib license.  You should have received a
 copy of the license along with this program; if not, please email
 <quantlib-dev@lists.sf.net>. The license is also available online at
 <https://www.quantlib.org/license.shtml>.

 This program is distributed in the hope that it will be useful, but WITHOUT
 ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 FOR A PARTICULAR PURPOSE.  See the license for more details.
"""

import sys
if sys.platform == "emscripten":
    # In Pyodide's WebAssembly dynamic linking runtime, C++ exceptions thrown
    # from dynamically loaded extension modules dispatch __cxa_throw through
    # function table slot 0. Registering ___cxa_throw in wasmTableMirror[0]
    # ensures C++ exceptions properly translate to Python exceptions.
    try:
        import pyodide_js
        _m = getattr(pyodide_js, "_module", None)
        if _m and hasattr(_m, "wasmTableMirror") and hasattr(_m, "___cxa_throw"):
            _m.wasmTableMirror[0] = _m.___cxa_throw
        del _m
    except Exception:
        pass

from .QuantLib import *
from . import _QuantLib

__author__ = 'The QuantLib Group'
__email__ = 'quantlib-users@lists.sourceforge.net'

if hasattr(_QuantLib,'__version__'):
    __version__ = _QuantLib.__version__
elif hasattr(_QuantLib.cvar,'__version__'):
    __version__ = _QuantLib.cvar.__version__
else:
    print('Could not find __version__ attribute')

if hasattr(_QuantLib,'__hexversion__'):
    __hexversion__ = _QuantLib.__hexversion__
elif hasattr(_QuantLib.cvar,'__hexversion__'):
    __hexversion__ = _QuantLib.cvar.__hexversion__
else:
    print('Could not find __hexversion__ attribute')
