#!/usr/bin/perl -w
# *******************************************
#  bootfix step 1
#
#  A utility to fix a bootstrap file from the Phylip seqboot program
#  into a nexus file
#
#  Assumptions: datatype=DNA missing=? gap=-
#
#  Input parameters:
#        1. The name of the phylip seqboot file
#        2. The name of a file containing paup commands which should be run after 
#           each replicate
#        3. Optional: Indication if the seqboot file is not interleaved. Interleaved is
#           the default. Using "no" as the third parameter indicates that data is 
#           not interleaved
#
#  It writes to standard output, so you would want to redirect output to a file
#
# Copyright (C) 2002-2007 Torsten Eriksson
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
my($version) = "0.4";
my($usage) = "Error: Missing parameter\nUsage: bootfix1.pl input_bootstrap_file_name paup_cmds_file_name [no (if not interleaved)]\n";
my($tfile); # input seqboot bootstrap file name
my($pfile); # name of file for paup commands
my($ntax); # number of taxa
my($nchar); # number of characters
my($savedline); # saved first line of each replicate
my($first) = 1; # indication of first replicate
my($interleaved); # indication of if bootstrap data are interleaved
my(@paupcmds); # list of paup commands for each replicate
my($i);
my($cntr) = 1;

if ($ARGV[0]) {
	#
	# Open input file
	#
	$tfile = $ARGV[0]; # name of input file
	if ($ARGV[1]) { $pfile = $ARGV[1] ;
		# Read paup commands from file
		open (PF,$pfile) || die "Error: Unable to open file with paup commands";
		$i=0;
		while (<PF>) {
			$paupcmds[$i] = $_;
			$i++;
			}
		close (PF) || warn "Warning: Could not close file with paup commands\n";
		}
	else { $pfile = "[no paup commands]\n" }
	if ($ARGV[2]) { $interleaved = lc($ARGV[2]) } else { $interleaved = "yes" } ;
	open (TF,$tfile) || die "Error: Unable to open input file";

	#
	# Copy all bootstrap replicates to standard output
	# along with nexus stuff
	#
	while (<TF>) {
		if ($first) {
			#
			#  Pick up dimensions from first line
			#
			$savedline = $_;
			($ntax,$nchar) = /[ \t]+(\d+)[ \t]+(\d+)/;
			#
			# Write nexus intro 
			#
			print "#NEXUS\n";
			print "[! Output from bootfix1.pl version $version ]\n";
			print "[! while reading files \"$tfile\" and \"$pfile\" ]\n";
			print "Begin PAUP;\n";
			print "\tset warnreset=no outroot=monophyl;\n";
			print "End;\n"; 
			$first = 0; # set not first 
			$_ = ""; # empty first line
				} # end of: if ($first)
		#
		# start a nexus bootstrap replicate
		#
		print "\n[!---------\>Bootstrap replicate # $cntr ]\n";
		print "Begin Data;\n";
		print "Dimensions ntax=$ntax nchar=$nchar;\n";
		print "Format datatype=DNA interleave=$interleaved missing=\? gap=-;\n";
		print "matrix\n";
		
		print "$_" ; # got to print the first line
		while (<TF>) {
			if ($_  eq $savedline) { # marks the start of next replicate
				$cntr++;
				print ";\n";
				print "End;\n";
				#
				# Write a paup block with commands supplied by user
				#
				print "Begin PAUP;\n";
				for ($i=0;$i<@paupcmds;$i++) {
					print "\t$paupcmds[$i]"
					}
				print "\nEnd;\n";
				last;
				}
			if ($interleaved eq "yes" && (/^             / || /^           /)) {print "x$_"}
			else {print "$_"}
			} # end of second while
			
		} # end of: while (<TF>)
	} # end of: if $ARGV[0]
else { 
	die "$usage" } 

# End of last replicate reached
print ";\n";
print "End;\n";
#
# Write a last paup block with commands supplied by user
#
print "Begin PAUP;\n";
for ($i=0;$i<@paupcmds;$i++) {
	print "\t$paupcmds[$i]"
	}
print "\nEnd;\n";

close (TF) || warn "Warning: Could not close input file\n";
exit(0);
