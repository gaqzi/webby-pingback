#!/usr/bin/env ruby -w
# -*- coding: utf-8 -*-
$KCODE = 'u'

# This is just used to easily load the rakefile through includes instead of copying the file

load File.join(%W[#{File.dirname(File.expand_path(__FILE__))} .. tasks pingback.rake])
