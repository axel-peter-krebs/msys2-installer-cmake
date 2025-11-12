#!/usr/bin/perl
use strict;
use warnings;
use YAML::XS 'LoadFile';
use Data::Dumper;

my $ins = LoadFile('config.yaml');

print "OK"

print Dumper($ins);
