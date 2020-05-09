#!/usr/bin/env python

"""
setup.py file for SWIG example
"""

from distutils.core import setup, Extension


althashlib_module = Extension(
    '_gcrypt_hash_wrapper',
    sources=['gcrypt_hash_wrapper.i', 'gcrypt_hash_wrapper.cpp'],
    swig_opts=['-c++'],
    language='c++',
    extra_compile_args=['--std=c++11', '-Os'],
    extra_link_args=['-lgcrypt'],
)

setup(
    name='althashlib',
    version='0.1',
    author="Jesper Lloyd",
    description="Small slot-in replacement for hashlib, using libgcrypt",
    ext_modules=[althashlib_module],
    py_modules=["althashlib"],
)
