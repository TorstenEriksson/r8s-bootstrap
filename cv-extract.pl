#!/usr/bin/perl -w
# *******************************************
#  cv-extract
#
#  A utility to read a cross-validation log file from r8s
#  and attempt to extract the optimal smoothing, as evidenced by the
#  lowest Chi square value found. It is useful
#  when cross-validation is performed on bootstrap replicates.
#  Rows which have the "(Failed)" note are skipped.
#
#  A word of warning: It's not necessarily a good idea in all cases
#  to strictly pick the smoothing value with the lowest Chi square
#  value. I closer inspection is often needed.
#
#  Usage:
#
#  cv-extract.pl input_file_name [replicate_number_start]
#
#  The optional starting replicate number may be useful if cross-validation
#  for bootstrap replicates were performed separately, and there are separate
#  log files.
#
# Copyright (C) 2004 Torsten Eriksson
# Torsten.Eriksson@Bergianska.se
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
my ($tfile);
my($cnt) = 0;
my ($reading) = 0;
my ($really) = 0;
my ($first) = 1;
my (@values);
my ($best) = 0;
my ($bestline);
if ($ARGV[0]) {
	$tfile = $ARGV[0] # name of input file
	}
else {
	die "Parameter error\nUsage: cv-extract.pl input_file_name [starting_replicate_number]\n"
	}
if ($ARGV[1]) {$cnt = $ARGV[1] - 1}
open (TF,$tfile) || die "Error: Unable to open input file.";
while (<TF>) {
	if ($reading) {
		if (/[\*]+/) {
			$reading = 0;
			$really = 0;
			print "$cnt\: $bestline";
			$best = 0;
			}
		if ($really) {
			@values = split(/[ \t]+/); # value 4 is chi square value
			chomp ($values[5]);
			if ($best) {
				if ($best > $values[4]) {
					if ($values[5] ne "(Failed)"){
						$best = $values[4];
						$bestline = $_;
						}
					}
				}
			else {
				if ($values[5] ne "(Failed)") {
					$best = $values[4];
					$bestline = $_;
					}
				}
			}
		else {
			if ($first) {print "     $_"}
			if (/\-\-\-\-/) {
				$really = 1;
				$first = 0;
				}
			}
	}
	else {
		if (/Results of cross validation/) {
			if ($first) {print "$_"}
			$reading = 1;
			$cnt++;
		}
	}
}
close (TF) || warn "Warning: Could not close input file\n";
exit(0);
