# -*-Perl-*-
################################################################
###
###			      Header.pm
###
### Author:  Internet Message Group <img@mew.org>
### Created: Oct 2, 1997
### Revised: Sep  5, 1998
###

my $PM_VERSION = "IM::Header.pm version 980905(IM100)";

package IM::Header;
require 5.003;
require Exporter;

use IM::Util;
use integer;
use strict;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(
	gen_message_id
	gen_date
	header_value
	add_header
	kill_header
	kill_empty_header
	sort_header
	hdr_cat
);

=head1 NAME

Header - IM Header

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use vars qw(@Week_str @Month_str $Cur_time
	    %Mid_hist $Prev_mid_time $Mid_rnd_hist);
@Week_str = qw(Sun Mon Tue Wed Thu Fri Sat);
@Month_str = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

sub cur_time ($) {
    my $part = shift;
    return $Cur_time if ($Cur_time && $part == 0);
    return $Cur_time = time;
}

##### GENERATE A MESSAGE-ID CHARACTER STRING #####
#
# gen_message_id(part)
#	part: part number of partial messages (for reuse)
#	return value: a unique message-id string
#
sub gen_message_id ($) {
    my $part = shift;
    return $Mid_hist{$part} if ($part > 0 && $Mid_hist{$part});
    my ($tm_sec, $tm_min, $tm_hour, $tm_mday, $tm_mon, $tm_year)
	= localtime(&cur_time($part));
    my ($mid_time) = sprintf("%d%02d%02d%02d%02d%02d",
	$tm_year+1900, $tm_mon+1, $tm_mday, $tm_hour, $tm_min, $tm_sec);
    my ($mid_rnd) = sprintf("%c", 0x41 + rand(26));
    if ($Prev_mid_time eq $mid_time) {
	while ($mid_rnd =~ /[$Mid_rnd_hist]/) {
	    $mid_rnd = sprintf("%c", 0x41 + rand(26));
	}
	$Mid_rnd_hist .= $mid_rnd;
    } else {
	$Prev_mid_time = $mid_time;
	$Mid_rnd_hist = $mid_rnd;
    }
    if ($main::Message_id_PID) {
	$mid_rnd = "-".$$.$mid_rnd;
    }
    my $mid_user;
    if ($main::Message_id_UID) {
	$mid_user = $<;
    } else {
	$mid_user = $main::Login;
    }
    my ($mid)
      = "<$mid_time$mid_rnd.$mid_user\@$main::Message_id_domain_name>";
    $Mid_hist{$part} = $mid if ($part > 0);
    return $mid;
}

##### GANARATE A DATE CHARACTER STRING #####
#
# gen_date(format)
#	format:
#		0 = "DD MMM YYYY HH:MM:SS TZ" (mainly for news)
#		1 = "WWW, DD MMM YYYY HH:MM:SS TZ"
#		2 = "WWW MMM DD HH:MM:SS YYYY" (mainly for UNIX From)
#	return value: date string generated with current time
#
sub gen_date ($) {
    my $format = shift;
    my ($tm_sec, $tm_min, $tm_hour, $tm_mday, $tm_mon, $tm_year,
	$tm_wk, $tm_yday, $tm_isdst, $tm_tz);
    if ($main::NewsGMTdate && $main::News_flag) {
	($tm_sec, $tm_min, $tm_hour, $tm_mday, $tm_mon, $tm_year,
	    $tm_wk, $tm_yday) = gmtime(&cur_time(0));
	$tm_tz = 'GMT';
    } else {
	($tm_sec, $tm_min, $tm_hour, $tm_mday, $tm_mon, $tm_year,
	  $tm_wk, $tm_yday, $tm_isdst) = localtime(&cur_time(0));
	my $off;
	if ($ENV{'TZ'} =~ /^([A-Z]+)([-+])?(\d+)(?::(\d\d)(?::\d\d)?)?([A-Z]+)?(?:([-+])?(\d+)(?::(\d\d)(?::\d\d)?)?)?/) {
	    $tm_tz = $1;
	    $off = $3 * 60 + $4;
	    $off = -$off if ($2 ne '-');
	    if ($tm_isdst && $5 ne '') {
		$tm_tz = $5;
		if ($7 ne '') {
		    $off = $7 * 60 + $8;
		    $off = -$off if ($6 ne '-');
		} else {
		    $off += 60;
		}
	    }
	} else {
	    my ($gm_sec, $gm_min, $gm_hour, $gm_mday, $gm_mon,
	      $gm_year, $gm_wk, $gm_yday) = gmtime(&cur_time(0));
	    $off = ($tm_hour - $gm_hour) * 60 + $tm_min - $gm_min;
	    if ($tm_year < $gm_year) {
		$off -= 24 * 60;
	    } elsif ($tm_year > $gm_year) {
		$off += 24 * 60;
	    } elsif ($tm_yday < $gm_yday) {
		$off -= 24 * 60;
	    } elsif ($tm_yday > $gm_yday) {
		$off += 24 * 60;
	    }
	}
	my $tzc = " ($tm_tz)" if ($tm_tz ne '');
	if ($off == 0) {
	    $tm_tz = 'GMT';
	} elsif ($off > 0) {
	    $tm_tz = sprintf("+%02d%02d%s", $off/60, $off%60, $tzc);
	} else {
	    $off = -$off;
	    $tm_tz = sprintf("-%02d%02d%s", $off/60, $off%60, $tzc);
	}
    }
    if ($format == 0) {
	return sprintf("%02d %s %d %02d:%02d:%02d %s", $tm_mday,
	  $Month_str[$tm_mon], $tm_year+1900, $tm_hour, $tm_min,
	  $tm_sec, $tm_tz);
    } elsif ($format == 1) {
	return sprintf("%s, %02d %s %d %02d:%02d:%02d %s", $Week_str[$tm_wk],
	  $tm_mday, $Month_str[$tm_mon], $tm_year+1900, $tm_hour, $tm_min,
	  $tm_sec, $tm_tz);
    } else {
	return sprintf("%s %s %2d %02d:%02d:%02d %s", $Week_str[$tm_wk],
	  $Month_str[$tm_mon], $tm_mday, $tm_hour, $tm_min, $tm_sec,
	  $tm_year+1900);
    }
}

##### GET VALUE OF SPECIFIED HEADER LINE #####
#
# header_value(header, field)
#	header: reference to a message header array
#	field: field name of which value needed
#	return value: value for specified field OR null
#
sub header_value ($$) {
    my ($Header, $field_name) = @_;
    my $val;
    local $_;

    foreach (@$Header) {
	if (/^$field_name:\s*(.*)/is) {
	    ($val = $1) =~ s/\s*$//;
	    return $val;
	}
    }
    return '';
}

##### ADD A HEADER LINE #####
#
# add_header(header, replace_flag, field_name, field_value)
#	header: reference to a message header array
#	replace_flag: old headers are deleted if true
#	field_name: field name to be entered
#	field_value: field value to be entered with
#	return value: none
#
sub add_header ($$$$) {
    my ($Header, $replace_flag, $field_name, $field_value) = @_;

    $field_value .= "\n" if ($field_value !~ /\n$/);
    im_debug("adding header> $field_name: $field_value")
	if (&debug('header'));
    if ($replace_flag) {
	my $i;
	for ($i = 0; $i <= $#$Header; $i++) {
	    if ($$Header[$i] =~ /^$field_name:/i) {
		$$Header[$i] = "$field_name: $field_value";
		return;
	    }
	}
    }
    push (@$Header, "$field_name: $field_value");
}

##### KILL SPECIFIED HEADER LINES #####
#
# kill_header(header, field_name, leave_first)
#	header: reference to a message header array
#	field_name: field name to be deleted
#	leave_first: leave the first appeared header line if true
#	return value: none
#
sub kill_header ($$$) {
    my ($Header, $field_name, $leave_first) = @_;

    my $i;
    for ($i = 0; $i <= $#$Header; $i++) {
	if ($$Header[$i] =~ /^$field_name:/i) {
	    if ($leave_first) {
		$leave_first = 0;
		next;
	    }
	    im_debug("killing $$Header[$i]") if (&debug('header'));
	    $$Header[$i] = " KILLED $$Header[$i]";
	}
    }
}

##### KILL EMPTY HEADER LINES #####
#
# kill_empty_header(header)
#	header: reference to a message header array
#	return value: none
#
sub kill_empty_header ($) {
    my $Header = shift;

    my $i;
    for ($i = 0; $i <= $#$Header; $i++) {
	if ($$Header[$i] =~ /^[\w-]+:\s*$/) {
	    im_debug("killing $$Header[$i]") if (&debug('header'));
	    $$Header[$i] = " KILLED $$Header[$i]";
	}
    }
}

##### SORT HEADER LINES #####
#
# sort_header(header, name_list)
#	header: reference to a message header array
#	name_list: leave the first appeared header line if true
#	return value: none
#
sub sort_header ($$) {
    my ($Header, $name_list) = @_;
    my ($i, $label, @tail);

    foreach $label (split(',', $name_list)) {
	for ($i = 0; $i <= $#$Header; ) {
	    if ($$Header[$i] =~ /^$label:/i) {
		push (@tail, $$Header[$i]);
		splice(@$Header, $i, 1);
	    } else {
		$i++;
	    }
	}
    }
    push (@$Header, @tail);
}

##### HEADER CONCATINATION #####
#
# hdr_cat(str1, str2, space)
#	str1: a preceeding header string
#	str2: a header string to be appended to str1
#	space: separatig space
#	return value: a concatinated header string
#
sub hdr_cat ($$$) {
    my ($str1, $str2, $space) = @_;

    if ($str1 eq '') {
	if ($space eq '' || $space eq 'any') {
	    return $str2;
	} else {
	    return "$space$str2";
	}
    }
    if ($str1 =~ /\n[\t ]+$/) {
	if ($space eq '' || $space eq 'any') {
		return "$str1$str2";
	} else {
		return "$str1$space$str2";
	}
    }
#   if ($space =~ /\n/) {
#	return "$str1$space$str2";
#   }
    $str1 =~ /([^\n]*)$/;
    my $l1 = length($1);
    $str2 =~ /^([^\n]*)/;
    my $l2 = length($1);
    if (!$main::NoFolding
	&& ($l1 + length($space) + $l2 + 1 > $main::Folding_length)) {
	if ($space eq '' || $space eq 'any') {
	    return "$str1\n\t$str2";
	} else {
	    return "$str1\n$space$str2";
	}
    }
    $space = ' ' if ($space eq 'any');
    return "$str1$space$str2";
}

1;

### Copyright (C) 1997, 1998 IM developing team.
### All rights reserved.
### 
### Redistribution and use in source and binary forms, with or without
### modification, are permitted provided that the following conditions
### are met:
### 
### 1. Redistributions of source code must retain the above copyright
###    notice, this list of conditions and the following disclaimer.
### 2. Redistributions in binary form must reproduce the above copyright
###    notice, this list of conditions and the following disclaimer in the
###    documentation and/or other materials provided with the distribution.
### 3. Neither the name of the team nor the names of its contributors
###    may be used to endorse or promote products derived from this software
###    without specific prior written permission.
### 
### THIS SOFTWARE IS PROVIDED BY THE TEAM AND CONTRIBUTORS ``AS IS'' AND
### ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
### IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
### PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE TEAM OR CONTRIBUTORS BE
### LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
### CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
### SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
### BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
### WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
### OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
### IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
