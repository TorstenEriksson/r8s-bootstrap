#!/usr/bin/perl -w
# *******************************************
#  bootfix step 2
#
#  A utility to fix a treefile from a bootstrap run by adding r8s
#  commands to it
#
#
#  Input parameters:
#        1. The name of the bootstrap treefile. Should have all treeblocks appended
#           one after the other
#        2. The name of a file containing r8s commands which should be run after 
#           each tree
#
#  It writes to standard output, so you would want to redirect output to a file
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
my($version) = "0.2";
my($usage) = "Error: Missing parameter\nUsage: bootfix2.pl input_bootstrap_treefile_name r8s_cmds_file_name\n";
my($tfile); # input bootstrap tree file name
my($pfile); # name of file for r8s commands
my(@r8scmds); # list of r8s commands for each replicate
my($i);
my($cntr) = 1;

if ($ARGV[0]) {
	#
	# Open input file
	#
	$tfile = $ARGV[0]; # name of input file
	if ($ARGV[1]) { $pfile = $ARGV[1] ;
		# Read r8s commands from file
		open (PF,$pfile) || die "Error: Unable to open file with r8s commands";
		$i=0;
		while (<PF>) {
			$r8scmds[$i] = $_;
			$i++;
			}
		close (PF) || warn "Warning: Could not close file with r8s commands\n";
		}
	else { $pfile = "[no r8s commands]\n" }
	open (TF,$tfile) || die "Error: Unable to open input file";

	#
	# Copy all trees to standard output
	# along with r8s stuff
	#
	while (<TF>) {
		print "$_" ;
		#
		# First replicate
		#
		if (/#NEXUS/i) {
			print "\n[!---------\>Bootstrap replicate # $cntr ]\n";
			$cntr++;
			}
		if (/End;/) { # fount the end of a tree block
			#
			# insert r8s command block
			#
			print "Begin r8s;\n";
			for ($i=0;$i<@r8scmds;$i++) {
				print "\t$r8scmds[$i]"
				}
			print "\nEnd;\n";
			#
			# Initiate a new bootstrap replicate (there will be one too many of these lines)
			#
			print "\n[!---------\>Bootstrap replicate # $cntr ]\n";
			$cntr++;
			}
		} # end of: while (<TF>)
	} # end of: if $ARGV[0]
else { 
	die "$usage" } 
print "[Please ignore the bogus line above this...]\n";
close (TF) || warn "Warning: Could not close input file\n";
exit(0);
