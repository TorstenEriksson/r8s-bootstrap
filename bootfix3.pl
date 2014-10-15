#!/usr/bin/perl -w
# *******************************************
#  bootfix step 3
#
#  A utility to merge PL smoothing values into a r8s command file
#  Note: This may or may not work...
#
#  Input parameters:
#        1. The name of r8s boot command file. 
#        2. The name of a file containing smoothing values from the cv-extract.pl
#           script.
#
#   Note that the boot r8s command should be fixed in all ways before this is
#        attempted. The script will look for a line containing the following
#        and try to insert a smoothing value into it:
#
#        "set smoothing=###.#"
#
#   Note that if you edit the file contaning the smoothing values in any way
#        manually, all will probably fail. This script is not error tolerant
#        (but fast).
#
#  It writes to standard output, so you might want to redirect output to a file
#
# Copyright (C) 2002 Torsten Eriksson
# Torsten@Bergianska.se
# This program is free software; 
# you can redistribute it and/or modify it under the terms of the 
# GNU General Public License as published by the Free Software Foundation; 
# either version 2 of the License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# http://www.gnu.org/copyleft/gpl.html
# *******************************************
use strict;
my($version) = "0.1";
my($usage) = "Error: Missing parameter\nUsage: bootfix3.pl input_r8s_cmdfile_name smoothing_values_file_name\n";
my($rfile); # input r8s file name
my($sfile); # name of file for smoothing values
my($cntr) = 1;
my($tmp);
my(@values);
my($smo);

if (not defined ($ARGV[0])) {die "$usage"}
if (not defined ($ARGV[1])) {die "$usage"}
$rfile = $ARGV[0];
$sfile = $ARGV[1];
open (RF,$rfile) || die "Error: Unable to open r8s command file\n";
open (SF,$sfile) || die "Error: Unable to open file with smoothing values\n";
while (<RF>) {
	if (/set smoothing=\#\#\#.\#/) {
		$tmp = $_;
		while (<SF>) {
			if (/^[\d]+: /) {last}
			}
		@values = split(/[ \t]+/); # value 1 is log smoothing; 2 is smoothing value
		# Don't use value output by r8s because it is truncated
		# Compute a new one from log smoothing
		$smo = 10 ** $values[1];
		print "\tset smoothing=";
		printf "%10.5f", $smo;
		print "; \[log smoothing $values[1]\]\n";
		}
	else {
		print "$_";
		}
	}
close (RF) || warn "Warning: Could not close input file\n";
close (SF) || warn "Warning: Could not close input file\n";
exit(0);
