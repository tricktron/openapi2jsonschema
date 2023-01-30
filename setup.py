#!/usr/bin/env python

from distutils.core import setup

setup(name='Openapi2jsonschema',
      version='1.0',
      description='OpenAPI to JSON Schemas converter',
      author='Thibault Gagnaux',
      author_email='tgagnaux@gmail.com',
      url='http://github.com/yannh/openapi2jsonschema',
      packages=['openapi2jsonschema'],
      scripts=[ 'openapi2jsonschema/command.py' ]
      )