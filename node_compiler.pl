#!/usr/bin/perl -w 
# *******************************************
#  NODE_COMPILER
# *******************************************
#
#  A utility to read a log file output from r8s and compile age info.
# 
#  It is assumed that output from a number of trees are strung one 
#  after the other in one log file, and that the analyses of 
#  each replicate output age estimates with the 'showage' command.
#  Only named nodes (mrca command) are considered.
#
#  Usage:
#  node_compiler.pl [-dp] r8s_logfile_name [calibration_node_name calibration_age]
#
#  The program performs some statistical testing and reports the
#     following statistics:
#     Standard deviation, Standard error, 95% confidence interval 
#        of the mean.
#     Also, the script tests if the age estimates from the bootstrap
#        replicates conform to a Normal distribution. Note that the 
#        result can be affected by the size of the classes in which 
#        the sample is divided. The variables '$class_size_setting' 
#        and '$class_range_setting' can be changed manually in the 
#        script to test different sizes and ranges.
#
#     To do these tests, the script relies on the "Statistics::Distributions"
#        module. it can be downloaded from http://cpan.org
#
#  If analyses were performed with the root set to age=1, the resulting
#     relative age estimates of the nodes can be calibrated by 
#     giving a calibration node (must be one of the named ones) and its
#     absolute age.
#
#  Age estimates found in the bootstrap replicates are output by using 
#     the "-p" option. When calibration has been requested both 
#     uncalibrated and calibrated ages are output.
#
#  Estimated rates can be used instead of estimated ages by specifying the
#     "-r" option. Since rates are low, they are multiplied by a constant 
#     ($rate_multiplier) for ease of printing. When picking up rates, the
#     terminals can be included by using the "-t" option
#
#  Simple histograms of the frequency of age classes used for the 
#     statistical calculations can be output by using the "-d" option. 
#     The lower and upper bounds of the classes are also output. 
#
#  Results are exported in csv-format (for input in spreadsheet program) by
#     specifying the "-c" option.
#
#  Thanks to Frank Rutschmann for help with statistics, testing and spelling!
#
# Copyright (C) 2006 Torsten Eriksson
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
use Statistics::Distributions;
my($this_script) = "node_compiler";
my($version) = "1.5";
my($usage) = "Error: Missing parameter\nUsage: $this_script.pl [-dpcrt] r8s_logfile_name [calibration_node_name calibration_age]\n";
my($i);
my($param) = 0; # parameter counter
my($tfile); # input r8s log file name
my($cntr) = 0;
my(@values);
my(%current,%high,%low,%sum,%sqsum,%cnt);
my($tmpage);
my($calibrate) = 0;
my($taxon); # node name
my($calage); # input calibration age
my($tmpcalage); # temporary calibration age storage
my($userates) = 0; # set 'use rates instead of ages' to no
my($printval) = 0; # set printout of age estimates to no
my($diagram) = 0; # set printout of diagram to no
my($csv) = 0; # set output of additional csv file
my($csvfilename);
my($csvfiletype)="tab"; # tab -> tabulated text, csv -> comma separated text with text delimiter (default)
my($csvstart);
my($csvmid);
my($csvend);
my($search_string) = "Summary of rate variation ";
my($method_string) = "Reconstruction method:";
my(@method);
my(@method_cntr);
my($mi); #counter
my(@mtmp); # temporary storage
my($new_method) = 0; # indicator if new method found
my($node_name_position) = 2;
my($age_position) = 6;
my($age_position_alt) = 7;
my($rate_position) = 7;
my($rate_multiplier) = 1000000; # rates are small
my($useterminals) = 0; # don't include terminals by default

#
# Settings for statistics
#
my($class_size_setting) = 0.3 ; # Initial class size * the standard deviation
my($class_range_setting) = 6 ; # Range of classes (number of standard deviations on either side of mean)
#
# variables for statistics
#
my(%nodes);
my($mean);
my($SD); # Standard Deviation
my($SE); # Standard Error
my($normal);
my($x);
my($tmpclass);
my(@class);
my(@xpclass);
my($classize);
my($nrofclasses);
my($OneClassOnly) = 0; # assume more than one class initially
my(@tmp);
my($start);
my($bottom);
my(@up,@down);
my($lowhalf);
my($inner,$outer);
my($chi);     # chi square value
my($degrees); # degrees of freedom for chi square test
my($tval);    # t distribution value
my($conflow); # confidence interval lower bound
my($confup);  # confidence interval upper bound
my($bigclass); 
my($y);

#
#   Test input parameters
#
$i=0;
while (defined ($ARGV[$i])) {
	$_ = $ARGV[$i];
	if (/-/) { 
		# option(s)
		s/-//;
		while (length($_) > 0) {
			if (/p/) {
				$printval = 1; # option: print all age estimates
				s/p//;
			} elsif (/d/) {
				$diagram = 1; # option: print diagrams
				s/d//;
			} elsif (/c/) {
				$csv = 1; # option: output a csv file
				s/c//;
			} elsif (/r/) {
				$userates = 1; # option: use estimated rates instead of ages
				s/r//;
			} elsif (/t/) {
				$useterminals = 1; # option: pick up info about therminals also
				s/t//;
			} else {
				print "Warning: option \"-$_\" was ignored\n";
				last;
			}
		}
	} else {
		# proper parameters
		if ($param == 2) {
			$calage = $_; # age of calibration node
			$param++;
		}
		if ($param == 1) {
			$taxon = $_; # name of calibration node
			$calibrate = 1;
			$param++;
		}
		if ($param == 0) {
			$tfile = $_; # name of input file
			$param++;
		}
	}
	$i++;
}
if (($param == 0) or ($param == 2)) { 
	die "$usage" 
}

open (TF,$tfile) || die "Error: Unable to open input file.";
if ($csv) {
	$csvfilename = $tfile . ".txt";
	open(OF,">$csvfilename") || die "Error: Could not create csv file\n";
	if ($csvfiletype eq "tab") {
		$csvstart = "";
		$csvmid = "\t";
		$csvend = "\n";
	} else {
		$csvstart = "\"";
		$csvmid = "\",\"";
		$csvend = "\"\n";
	}
	# Print a header line
	print OF $csvstart,"Node",$csvmid,"Min",$csvmid,"Max",$csvmid,"Mean",$csvmid,"SD",$csvmid,"mean-SD",$csvmid,"mean+SD",$csvmid,"SE",$csvmid,"95% conf low",$csvmid,"95% conf high",$csvend;
}
#
#   Read the input file
#
while (<TF>) {
	if ($userates && $useterminals && /^      \w/) { # found a terminal
		@values = split(/[\s]+/);
		$current{$values[1]} = $rate_multiplier * $values[$rate_position];
	} elsif (/^\s*\[\*\]/) { #  found a named node
		@values = split(/[ \t]+/);
		if ($userates) { 
		# ----------------------
		# Use the rate estimates
		# Since rates are small, multiply them with a constant to make them easier to print
			unless ($values[3] eq "*") { # Check if any asterisk indicating fixed age then there is no estimated rate
				$current{$values[$node_name_position]} = $rate_multiplier * $values[$rate_position];
			}
			if ($printval and (!$calibrate)) {
				unless ($values[3] eq "*") {
					print "$values[$node_name_position] $values[$rate_position]\n";
				}
			}
		} else { 
			# ---------------------
			# Use the age estimates
			if ($values[3] eq "*") { # Check if any asterisk indicating fixed age
				$current{$values[$node_name_position]} = $values[$age_position_alt];
			} else {
				$current{$values[$node_name_position]} = $values[$age_position];
			}
			if ($printval and (!$calibrate)) {
				if ($values[3] eq "*") {
					print "$values[$node_name_position] $values[$age_position_alt]\n";
				} else {
					print "$values[$node_name_position] $values[$age_position]\n";
				}
			}
		}
	} elsif (/^$method_string/) { # check indication of method type (since PL can revert to LF without much notice)
		@mtmp = split(/: /);
		chomp($mtmp[1]);
		if ($method[0]) {
			$new_method = 1;
			$mi=0;
			foreach(@method) {
				if ($_ eq $mtmp[1]) {
					$method_cntr[$mi]++;
					$new_method = 0;
					last;
				} else {
					$mi++;
				}
			}
			if ($new_method) {
				push(@method,$mtmp[1]);
				push(@method_cntr,1);
			}
		} else {
			$method[0] = $mtmp[1];
			$method_cntr[0] = 1;
	}
	} else {
		if (/^$search_string/) { # check if end of a separate analysis
			$cntr++;
			if ($printval and (!$calibrate)) {
				print "---- end of replicate $cntr\n";
			}
			#
			# Calibrate ages ?
			#
			if ($calibrate) {
				# Check that supplied node is one found
				if (! $current{$taxon}) {
					close (TF) || warn "Warning: Could not close input file\n";
					die "Error: The calibration node can't be used.\nCheck spelling and that the node is present in all replicates.\n";
				}
				if ($printval) {
					print "---- replicate $cntr\n";
				}
				$tmpcalage = $current{$taxon};
				foreach $i (keys(%current)) {
					if ($printval) {
						print "$current{$i}  ";
					}
					$current{$i} = $calage * $current{$i} / $tmpcalage;
					if ($printval) {
						print "$current{$i}\n";
					}
				}
			}
			#
			# Save data for one bootstrap analysis
			#
			foreach $i (keys(%current)) {
				if ($cnt{$i}) {
					$cnt{$i}++;
				} else {
					$cnt{$i}=1;
				}
				#
				# Lower range
				#
				if ($low{$i}) {
					if ($low{$i} > $current{$i}) {
						$low{$i} = $current{$i};
					}
				} else { 
					$low{$i} = $current{$i}; # if undefined
				} 
				#
				# Upper range
				#
				if ($high{$i}) {
					if ($high{$i} < $current{$i}) {
						$high{$i} = $current{$i};
					}
				} else { 
					$high{$i} = $current{$i}; # if undefined
				} 
				#
				# Sum of values
				#
				if ($sum{$i}) { 
					$sum{$i} += $current{$i};
				} else { 
					$sum{$i} = $current{$i}; # if undefined
				} 
				#
				# Sum of squared values
				#
				if ($sqsum{$i}) { 
					$sqsum{$i} += ($current{$i} ** 2); 
				} else { 
					$sqsum{$i} = $current{$i} ** 2; # if undefined
				}
				#
				# Save value in hash array
				#
				$nodes{$i}[$cnt{$i}-1] = $current{$i};
			}
			undef(%current);
		}
	}
}
#
# Close input file
#
close (TF) || warn "Warning: Could not close input file\n";
# print results
print "Output from \'$this_script\' version $version\n";
print "---------------------------------------\n";
if ($userates) {
	print "Note: rates are multiplied by $rate_multiplier\n";
}

foreach $i (keys(%low)) {
	if ($calibrate) {
		if ($i eq $taxon) {print "* "} else {print "  "}
	} else {
		print "  ";
	}
	if ($cnt{$i}>0) {
		$mean = $sum{$i} / $cnt{$i};
	} else {
		$mean = 0;
	}
	if ($cnt{$i}>1) {
		$SD = sqrt ( ( $sqsum{$i} - ( ( $sum{$i} ** 2 ) / $cnt{$i} ) ) / ($cnt{$i}-1) ); # Standard deviation (for sample)
    	$SE = $SD / sqrt ($cnt{$i}) ;
	} else {
		$SD = 0;
		$SE = 0;
	}
	#
	# Check if sample has normal distribution
	#
	if ($SD > 0) { # Skip this test if there is no variation
		#
		# Partition sample into classes
		#
		#
		
		$classize = $SD * $class_size_setting;
		$nrofclasses = 2 * $class_range_setting / $class_size_setting;
		@tmp = split (/\./, $nrofclasses); # round down
		$nrofclasses = $tmp[0];
		$start = $mean - ($class_range_setting * $SD);
		$bottom = $start;
		$lowhalf = $nrofclasses / 2;
		@tmp = split (/\./, $lowhalf); # round down
		for ($x = 0; $x < $nrofclasses ; ++$x) {
			$down[$x] = $start;
			$start += $classize;
			$up[$x] = $start;
			$class[$x]=0;
		}
		for ($x = 0; $x < $cnt{$i}; ++$x) {
			#
			# Calculate to what class it belongs 
			#
			$tmpclass = ($nodes{$i}[$x] - $bottom) / $classize;
			if ($tmpclass < 0) { # sample out of lower class bounds
				$tmpclass = 0;
				$down[0] = $nodes{$i}[$x]; # adjust lower class bounds of first class
			} elsif ($tmpclass > $nrofclasses) { # sample out of upper class bounds
				$tmpclass = $nrofclasses-1;
				$up[$nrofclasses-1] = $nodes{$i}[$x]; # adjust upper class bounds of last class
			} else {
				@tmp = split (/\./, $tmpclass); # truncate
				$tmpclass = $tmp[0] ;
			}
			# add to that class
			$class[$tmpclass]++;
		}
		#
		# Merge classes that contain less than 5 samples
		#
		$x = 0;
		while ($up[$x] < $mean) {
			if ($class[$x] < 5) {
				$class[$x+1] += $class[$x];
				$down[$x+1] = $down[$x];
				$class[$x] = 0;
			}
			$x++;
		}
		$x = $nrofclasses-1;
		while ($down[$x] > $mean) {
			if ($class[$x] < 5) {
				$class[$x-1] += $class[$x];
				$up[$x-1] = $up[$x];
				$class[$x] = 0;
			}
			$x--;
		}
		# Remove empty classes
		for ($x = $nrofclasses-1; $x >= 0; --$x) {
			if ($class[$x] == 0) {
				splice(@class,$x,1);
				splice(@down,$x,1);
				splice(@up,$x,1);
			}
		}
		$nrofclasses = @class;
		#
		#  Don't proceed if only one class present
		#
		if ($nrofclasses > 1) {
			$OneClassOnly = 0;
			#
			# Calculate expected frequencies for those classes
			#
			# n * ( uprob ( ( inner bound - mean) / standard deviation ) ) - ( uprob ( ( outer bound - mean) / standard deviation ) )
			#
			for ($x = 0; $x < $nrofclasses; ++$x) {
				$inner = 1 - Statistics::Distributions::uprob(($down[$x] - $mean) / $SD);
				$outer = 1 - Statistics::Distributions::uprob(($up[$x] - $mean) / $SD);
				if ($inner > $outer) {
					$xpclass[$x] = $cnt{$i} * ($inner-$outer)
				} else {
					$xpclass[$x] = $cnt{$i} * ($outer-$inner)
				}
			}
			#
			# Calculate chi square value for each class and sum over classes
			#
			# For each class chi square is ( ( (observed frequency - expected frequency) ** 2 ) / expected frequency )
			#
			$chi = 0;
			for ($x = 0; $x < $nrofclasses; ++$x) {
				$chi += ((($class[$x]-$xpclass[$x])**2) / $xpclass[$x]);
			}
			#
			# Compare chi square value with that for critical level
			#
			# Degrees of freedom is number of classes - 2 (i.e. nr of estimated parameters) - 1
			#
			$degrees = @class -3;
			if ($degrees < 1) {
				$OneClassOnly = 1;
			} else {
				if ($chi > Statistics::Distributions::chisqrdistr ($degrees,.05)) {
					# Normal distribution of sample rejected
					$normal=0;
				} else {
					# Normal distribution of sample not rejected
					$normal=1;
					#
				}
				# Calculate 95% confidence interval of mean. Note that the module
				# uses a one sided distribution. We want a two sided.
				#
				$tval = Statistics::Distributions::tdistr ($cnt{$i}-1,.025);
				$conflow = $mean - ($tval * $SE);
				$confup  = $mean + ($tval * $SE);
			}
		# end of: if ($nrofclasses > 1)
		} else { 
			$OneClassOnly = 1;
		}
		#
		# Print a diagram if requested
		#
		if ($diagram) {
			# Check biggest class
			$bigclass = 0;
			for ($x = 0; $x < $nrofclasses; ++$x) {
				if ($class[$x] > $bigclass) {$bigclass = $class[$x]}
			}
			# Print diagram
			print "Age estimate frequencies of node $i:\n";
			for ($y = $bigclass; $y >= 0; --$y) {
				printf "%5.0f ", $y;
				for ($x = 0; $x < $nrofclasses; ++$x) {
					if ($class[$x] >= $y) {
						print "\# ";
					} else {
						print "  ";
					}
				}
				print "\n";
			}
			# Print class bounds
			print "Class bounds:\n";
			for ($x = 0; $x < $nrofclasses; ++$x) {
				printf "%5.0f %4.3f - %4.3f\n", $x+1, $down[$x], $up[$x];
				#print "\n";
			}
		}
	# end of: if ($SD > 0)
	} 
		
	if ($cntr > 1) {
		printf "%-15s  Range: %10.3f-%4.3f  Mean: %10.3f  ", $i, $low{$i}, $high{$i}, $mean;
		if ($csv) {
			print OF $csvstart,$i,$csvmid,$low{$i},$csvmid,$high{$i},$csvmid,$mean;
		}
		if ($SD > 0) {
			if ($OneClassOnly) {
				printf "\n    Stand Dev: %4.3f (%4.3f - %4.3f)  Stand Err: %4.3f", $SD, $mean-$SD, $mean+$SD, $SE;
				print "\n    Test of sample distribution was not performed because of too little variation.  ";
				if ($csv) {
					print OF $csvmid,$SD,$csvmid,$mean-$SD,$csvmid,$mean+$SD,$csvmid,$SE,$csvmid,$csvmid;
				}
			} else {
			    # This version always print statistics
				printf "\n    Stand Dev: %4.3f (%4.3f - %4.3f)  Stand Err: %4.3f", $SD, $mean-$SD, $mean+$SD, $SE;
				print "  95% conf interval: ";
				printf "%4.3f - %4.3f", $conflow, $confup;
				if ($csv) {
					print OF $csvmid,$SD,$csvmid,$mean-$SD,$csvmid,$mean+$SD,$csvmid,$SE,$csvmid,$conflow,$csvmid,$confup;
				}
				if ($normal) { # Normal distribution was not rejected
					print "\n    Normal distribution of sample was NOT rejected at 0.05 significance level  ";
					printf "\n    Chi sq: %4.3f  df: %2.0f", $chi, $degrees;
				} else {
					print "\n    Normal distribution of sample was rejected at 0.05 significance level  ";
					printf "\n    Chi sq: %4.3f  df: %2.0f",$chi,$degrees;
				}
			}
		} else {
			if ($csv) {
				print OF $csvmid,$csvmid,$csvmid,$csvmid,$csvmid,$csvmid;
			}
		}
		print "\n";
		if ($cnt{$i} < $cntr) {
			print "    --> Note: this node was found in $cnt{$i} replicates only.\n";
		}
	} else {
		printf "%-15s  Age: %10.3f\n", $i, $low{$i};
		if ($csv) {
			print OF $csvstart,$i,$csvmid,$low{$i},$csvmid,$csvmid,$csvmid,$csvmid,$csvmid,$csvmid,$csvmid,$csvmid;
		}
	}
	if ($csv) {
		print OF $csvend;
	}

}
print "---------------------------------------\n";
if ($calibrate) {
	print "* = calibration node, at age $calage\n";
}
if (($cntr < 1) or ($cntr > 1)) {
	print "$cntr replicates found\n"
}
if (scalar(@method)==1) {
	print "All replicates used $method[0]\n";
} elsif (scalar(@method)>1) {
	print "*** WARNING *** Replicates used different methods\n";
	for ($mi=0;$mi<scalar(@method);$mi++) {
		print "  $method[$mi] - $method_cntr[$mi] times\n"
	}
}
if ($csv) {
	print "Results exported in csv format to file '" . $csvfilename . "'\n";
	close (OF) || warn "Warning: Could not close csv file\n";
}
exit(0);
