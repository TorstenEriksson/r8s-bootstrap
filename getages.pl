#!/usr/bin/perl -w
# *******************************************
#  getages
#
#  A utility to read a bootstrap log file output from r8s. 
#  It is assumed that all bootstrap replicates are strung one after the other
#  in one log file, and that the analyses of each replicate did output age
#  estimates with the 'showage' command.
#  Only named nodes (mrca command) are considered.
#
#  There are two forms of usage:
#
#  1. When age estimates are already calibrated:
#  getages.pl r8s_logfile_name
#
#  2. When age estimates are relative 
#  (by using the r8s command 'fixage taxon=root age=1')
#  getages.pl -c r8s_logfile_name calibration_node_name calibration_age
#
# Copyright (C) 2002--2006 Torsten Eriksson
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
my($version) = "1.4";
my($usage) = "Error: Missing parameter\nUsage: getages.pl [-c] r8s_logfile_name [calibration_node_name calibration_age]\n";
my($tfile); # input r8s log file name
my($cntr) = 0;
my(@values);
my(%current,%high,%low,%sum,%sqsum);
my($tmpage);
my($mean);
my($SD);
my($i);
my($calibrate) = 1;
my($taxon); # name of calibration taxon
my($age); # calibration age
my($node_name_position) = 2;
my($age_position) = 6;
if ($ARGV[0]) { 
	if ($ARGV[0] eq "-c") {
		
		#
		#   Calibration has been requested through the -c switch
		#
		if ($ARGV[1]) { $tfile = $ARGV[1] } else { die "$usage" } # name of input file
		if ($ARGV[2]) { $taxon = $ARGV[2] } else { die "$usage" } # name of calibration taxon
		if ($ARGV[3]) { $age   = $ARGV[3] } else { die "$usage" } # calibration age
		open (TF,$tfile) || die "Error: Unable to open input file.";
		while (<TF>) {
			if (/^ \[\*\]/) { #  found a named node
				@values = split(/[ \t]+/); # value $node_name_position is name, value $age_position is relative age estimate
				$current{$values[$node_name_position]} = $values[$age_position];
				}
			else {
				if (/Summary of/) { # check if end of a separate analysis
					# Check that supplied node is one found
					if (! %low) {
						if (! $current{$taxon}) {
							close (TF) || warn "Warning: Could not close input file\n";
							die "Error: That taxon is not among those found in the file. Check spelling\n";
							}
						}
					# calibrate
					$cntr++;
					foreach $i (keys(%current)) {
						$tmpage = $age * $current{$i} / $current{$taxon};
						if ($low{$i}) {
							if ($low{$i} > $tmpage) {$low{$i} = $tmpage}
							}
						else { $low{$i} = $tmpage } # if undefined
						if ($high{$i}) {
							if ($high{$i} < $tmpage) {$high{$i} = $tmpage}
							}
						else { $high{$i} = $tmpage } # if undefined
						if ($sum{$i}) { $sum{$i} += $tmpage }
						else { $sum{$i} = $tmpage } # if undefined
						if ($sqsum{$i}) { $sqsum{$i} += ($tmpage ** 2) }
						else { $sqsum{$i} = $tmpage ** 2 } # if undefined
						}
					}
				}
			}
		}
	else { 
		
		#
		#   No calibration needed
		#
		$tfile = $ARGV[0]; # name of input file
		$calibrate = 0;
		open (TF,$tfile) || die "Error: Unable to open input file.";
		while (<TF>) {
			if (/^ \[\*\]/) { #  found a named node
				@values = split(/[ \t]+/); # value 2 is name, value 7 is relative age estimate
				$current{$values[$node_name_position]} = $values[$age_position];
				}
			else {
				if (/Summary of/) { # check if end of a separate analysis
					$cntr++;
					foreach $i (keys(%current)) {
						if ($low{$i}) {
							if ($low{$i} > $current{$i}) {$low{$i} = $current{$i}}
							}
						else { $low{$i} = $current{$i} } # if undefined
						if ($high{$i}) {
							if ($high{$i} < $current{$i}) {$high{$i} = $current{$i}}
							}
						else { $high{$i} = $current{$i} } # if undefined
						if ($sum{$i}) { $sum{$i} += $current{$i} }
						else { $sum{$i} = $current{$i} } # if undefined
						if ($sqsum{$i}) { $sqsum{$i} += ($current{$i} ** 2)}
						else { $sqsum{$i} = $current{$i} ** 2 } # if undefined
						}
					}
				}
			}
		}
	} 
else { 
	die "$usage" } 

close (TF) || warn "Warning: Could not close input file\n";

# print results
print "Output from \'getages\' version $version\n";
print "----------------------------------\n";
foreach $i (keys(%low)) {
	if ($calibrate) {
		if ($i eq $taxon) {print "* "} else {print "  "}
		}
	else {print "  "}
	$mean = $sum{$i} / $cntr;
	$SD = sqrt ( ( $sqsum{$i} - ( ( $sum{$i} ** 2 ) / $cntr ) ) / ($cntr-1) ); # Standard deviation (for sample)
	if ($cntr > 1) {
		if ($SD == 0) {
			printf "%-15s  Range: %10.3f-%4.3f  Mean: %10.3f  SD: %10.3f\n", $i, $low{$i}, $high{$i}, $mean, $SD;
			}
		else {
			printf "%-15s  Range: %10.3f-%4.3f  Mean: %10.3f  SD: %10.3f (%4.3f - %4.3f)\n", $i, $low{$i}, $high{$i}, $mean, $SD, $mean-$SD, $mean+$SD;
			}
		}
	else {
		printf "%-15s  Age: %10.3f\n", $i, $low{$i};
		}
	}
if ($calibrate) {print "\n* = calibration taxon, at age $age\n";}
if ($cntr > 1) {print "$cntr replicates found\n"}
exit(0);
