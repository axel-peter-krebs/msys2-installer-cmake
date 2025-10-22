#!/bin/env python
import sys
import importlib.util
import codecs

if(sys.maxunicode > 65536):
    print(sys.maxunicode)
    if sys.stdout.encoding != 'cp850':
        sys.stdout = codecs.getwriter('cp850')(sys.stdout.buffer, 'strict')
    if sys.stderr.encoding != 'cp850':
        sys.stderr = codecs.getwriter('cp850')(sys.stderr.buffer, 'strict')
    print(b"Ola".decode('utf-8').encode('cp850','replace').decode('cp850'))

mods = []
# help("modules") > mods
