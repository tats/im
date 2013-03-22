# -*-Perl-*-
################################################################
###
###			  TcpTransaction.pm
###
### Author:  Internet Message Group <img@mew.org>
### Created: Apr 23, 1997
### Revised: Oct 25, 1999
###

my $PM_VERSION = "IM::TcpTransaction.pm version 991025(IM133)";

package IM::TcpTransaction;
require 5.003;
require Exporter;
use IM::Config qw(dns_timeout connect_timeout command_timeout rcv_buf_siz);
use Socket;
use IM::Util;
use IM::Ssh;
use integer;
use strict;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(log_transaction
	connect_server tcp_command send_command next_response send_data
	command_response set_command_response tcp_logging
	get_session_log set_cur_server get_cur_server
	pool_priv_sock);

=head1 NAME

TcpTransaction - TCP Transaction processing interface for SMTP and NNTP

=head1 SYNOPSIS

$socket = &connect_server(server_list, protocol, log_flag);
$return_code = &tcp_command(socket, command_string, log_flag);
@response = &command_response;
&set_command_response(response_string_list);

=head1 DESCRIPTION

=cut

use vars qw($Cur_server $Session_log $TcpSockName
	    $SOCK @Response $Logging @SockPool @Sock6Pool);
BEGIN {
    $Cur_server = '';
    $Session_log = '';
    $TcpSockName = 'tcp00';
}

sub log_transaction () {
    use IM::Log;
}

##### MAKE TCP CONNECTION TO SPECIFIED SERVER #####
#
# connect_server(server_list, protocol, root)
#	server_list: comma separated server list
#	protocol: protocol name to be used with the servers
#	root: privilidge port required
#	return value: handle if success
#
sub connect_server ($$$) {
    my ($servers, $proto, $root) = @_;

    if ($#$servers < 0) {
	im_err("no server specified for $proto\n");
	return '';
    }

    $SIG{'ALRM'} = \&alarm_func;

    no strict 'refs'; # XXX
    local (*SOCK) = \*{$TcpSockName};
    $SOCK = $proto;
    @Response = ();
    my ($pe_name, $pe_aliases, $pe_proto);
    my ($se_name, $se_aliases, $se_port);
    ($pe_name, $pe_aliases, $pe_proto) = getprotobyname ('tcp') if (unixp());
    unless ($pe_name) {
	$pe_proto = 6;
    }
    ($se_name, $se_aliases, $se_port) = getservbyname ($proto, 'tcp')
	if (unixp());
    unless ($se_name) {
	if ($proto eq 'smtp') {
	    $se_port = 25;
	} elsif ($proto eq 'http') {
	    $se_port = 80;
	} elsif ($proto eq 'nntp') {
	    $se_port = 119;
	} elsif ($proto eq 'pop3') {
	    $se_port = 110;
	} elsif ($proto eq 'imap') {
	    $se_port = 143;
	} else {
	    im_err("unknown service: $proto\n");
	    return '';
	}
    }
    my ($he_name, $he_alias, $he_type, $he_len, $he_addr, @he_addrs);
    my ($family, $s, $localport, $remoteport, $sin);
    while ($s = shift(@$servers)) {
	my ($r) = ($#$servers >= 0) ? 'skipped' : 'failed';
	# manage server[/remoteport]%localport
	if ($s =~ s/\%(\d+)$//) {
	    $localport = $1;
	    $Cur_server = $s;
	    if ($s =~ s/\/(\d+)$//) {
		$remoteport = $1;
	    } else {
		$remoteport = $se_port;
	    }
	    if ($main::SSH_server eq 'localhost') {
		im_warn( "Don't use port-forwarding to `localhost'.\n" );
		$Cur_server = "$s/$remoteport";
	    } else {
		if ( $remoteport = &ssh_proxy($s,$remoteport,$localport,$main::SSH_server) ) {
		    $s = 'localhost';
		    $Cur_server = "$Cur_server%$remoteport";
		} else { # Connection failed.
		    im_warn( "Can't login to $main::SSH_server\n" );
		    if ($proto eq 'smtp') {
			&log_action($proto, $Cur_server,
				    join(',', @main::Recipients), $r, @Response);
		    } else { # NNTP
			&log_action($proto, $Cur_server,
				    $main::Newsgroups, $r, @Response);
		    }
		    next;
		}
	    }
	}
	# manage server[/remoteport] notation
	elsif ($s =~ /([^\/]*)\/(\d+)$/) {
	    $remoteport = $2;
	    $s = $1;
	    $Cur_server = "$s/$remoteport";
	} else {
	    $remoteport = $se_port;
	    $Cur_server = $s;
	}
	if ($s =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
	    @he_addrs = (pack('C4', $1, $2, $3, $4));
	    $family = AF_INET;
	} elsif ($s =~ /^[\da-f:]+$/i) {
	    if ($s =~ /::.*::/) {
		im_err("bad server address in IPv6 format: $s\n");
		return '';
	    }
	    if ($s =~ /::/) {
		(my $t = $s) =~ s/[^:]//g;
		my $n = 7 - length($t);
		$t = ':0:';
		while ($n--) {
		    $t .= '0:';
		}
		$s =~ s/::/$t/;
	    }
	    if ($s =~ /^([\da-f]*):([\da-f]*):([\da-f]*):([\da-f]*):([\da-f]*):([\da-f]*):([\da-f]*):([\da-f]*)$/i) {
		@he_addrs = (pack('n8',
		    hex("0x$1"), hex("0x$2"), hex("0x$3"), hex("0x$4"),
		    hex("0x$5"), hex("0x$6"), hex("0x$7"), hex("0x$8")));
		$family = inet6_family(); # AF_INET6
	    } else {
		im_err("bad server address in IPv6 format: $s\n");
		return '';
	    }
	} else {
	    alarm(dns_timeout()) unless win95p();
	    $0 = progname() . ": gethostbyname($s)";
	    ($he_name, $he_alias, $he_type, $he_len, @he_addrs)
	      = gethostbyname ($s);
	    alarm(0) unless win95p();
	    unless ($he_name) {
		im_warn("address unknown for $s\n");
		@Response = ("address unknown for $s");
		if ($proto eq 'smtp') {
		    &log_action($proto, $Cur_server,
				join(',', @main::Recipients), $r, @Response);
		} else { # NNTP
		    &log_action($proto, $Cur_server,
				$main::Newsgroups, $r, @Response);
		}
		next;
	    }
	    $family = $he_type;
	}

	foreach $he_addr (@he_addrs) {
	    if ($root && unixp()) {
		my $name = priv_sock($family);
		if ($name eq '') {
		    im_err("privilege port pool is empty.\n");
		    return '';
		}
		*SOCK = \*{$name};
		$SOCK = $proto;
	    } else {
		unless (socket(SOCK, $family, SOCK_STREAM, $pe_proto)) {
		    im_err("socket creation failed: $!.\n");
		    return '';
		}
		if (defined(rcv_buf_siz())) {
                    unless (setsockopt(SOCK, SOL_SOCKET, SO_RCVBUF, int(rcv_buf_siz()))) {
                        im_err("setsockopt failed: $!.\n");
                        return '';
		    }
                }
	    }

	    if ($family == AF_INET) {
		$sin = &pack_sockaddr_in($remoteport, $he_addr);
	    } else { # AF_INET6
		$sin = inet6_pack_sockaddr_in6($family, $remoteport, $he_addr);
	    }
	    im_notice("opening $proto session to $s($remoteport).\n");
	    alarm(connect_timeout()) unless win95p();
	    $0 = progname() . ": connecting to $s with $proto";
	    if (connect (SOCK, $sin)) {
		alarm(0) unless win95p();
		select (SOCK); $| = 1; select (STDOUT);
		$Session_log .= 
		    "Transcription of $proto session follows:\n" if ($Logging);
		im_debug("handle $TcpSockName allocated.\n")
		    if (&debug('tcp'));
		$TcpSockName++;
		return *SOCK;
	    }
	    @Response = ($!);
	    alarm(0) unless win95p();
	    close(SOCK);
	}
	im_notice("$proto server $s($remoteport) did not respond.\n");
	if ($proto eq 'smtp') {
	    &log_action($proto, $Cur_server,
			join(',', @main::Recipients), $r, @Response);
	} else { # NNTP
	    &log_action($proto, $Cur_server,
			$main::Newsgroups, $r, @Response);
	}
    }
    im_warn("WARNING: $proto connection was not established.\n");
    return '';
}

##### CLIENT-SERVER HANDSHAKE #####
#
# tcp_command(channel, command, fake_message)
#	channel: socket descriptor to send the command
#	command: command string to be sent
#	return value:
#		 0: success
#		 1: recoverable error (should be retried)
#		-1: unrecoverable error
#
sub tcp_command ($$$) {
    my ($CHAN, $command, $fake) = @_;
    my ($resp, $stat, $rcode, $logcmd);

    @Response = ();
    $stat = '';
    if ($fake) {
	$logcmd = $fake;
    } else {
	$logcmd = $command;
    }
    if ($command) {
	im_notice("<<< $logcmd\n");
	$Session_log .= "<<< $logcmd\n" if ($Logging);
	unless (print $CHAN "$command\r\n") {
	    # may be channel truoble
	    @Response = ($!);
	    return 1;
	}
	$0 = progname() . ": $logcmd ($Cur_server)";
    } else {
## if you have mysterious TCP/IP bug on IRIX/SGI
#	print $CHAN ' ';
## endif
	$0 = progname() . ": greeting ($Cur_server)";
    }
    do {
	alarm(command_timeout()) unless win95p();
	$! = 0;
	$resp = <$CHAN>;
	unless (win95p()) {
	    alarm(0);
	    if ($!) {	# may be channel truoble
		@Response = ("$!");
		return 1;
	    }
	}
	$resp =~ s/[\r\n]+$//;
	if ($resp =~ /^([0-9][0-9][0-9])/) {
	    $rcode = $1;
	    if ($stat eq '' && $rcode !~ /^0/) {
		$stat = $rcode;
	    }
	    push(@Response, $resp) if ($rcode !~ /^0/);	# XXX
	}
	im_notice(">>> $resp\n");
	$Session_log .= ">>> $resp\n" if ($Logging);
	last if ($resp =~ /^\.$/);
    } while ($resp =~ /^...-/ || $resp =~ /^[^1-9]/);
    return 0 if ($stat =~ /^[23]../);
    return 1 if ($stat =~ /^4../);
    return -1;
}

##### CLIENT-SERVER HANDSHAKE #####
#
# send_command(channel, command, fake_message)
#	return value: the first line of responses
#
sub send_command ($$$) {
    my ($CHAN, $command, $fake) = @_;
    my ($resp, $logcmd);
    if ($command) {
	print $CHAN "$command\r\n";
	if ($fake) {
	    $logcmd = $fake;
	} else {
	    $logcmd = $command;
	}
	im_notice("<<< $logcmd\n");
	$Session_log .= "<<< $logcmd\n" if ($Logging);
	$0 = progname() . ": $logcmd ($Cur_server)";
    } else {
	$0 = progname() . ": greeting ($Cur_server)";
    }
    alarm(command_timeout()) unless win95p();
    $! = 0;
    $resp = <$CHAN>;
    unless (win95p()) {
	alarm(0);
	if ($!) {	# may be channel truoble
	    im_notice("$!\n");
	    return '';
	}
    }
    $resp =~ s/[\r\n]+/\n/;
    im_notice(">>> $resp");
    $Session_log .= ">>> $resp" if ($Logging);
    chomp $resp;
    return $resp;
}

sub send_data ($$$) {
    my ($CHAN, $data, $fake) = @_;
    my ($logdata);
    $data =~ s/\r?\n?$//;
    print $CHAN "$data\r\n";
    if ($fake) {
	$logdata = $fake;
    } else {
	$logdata = $data;
    }
    im_notice("<<< $logdata\n");
    $Session_log .= "<<< $logdata\n" if ($Logging);
}

sub next_response ($) {
    my $CHAN = shift;
    my $resp;

    alarm(command_timeout()) unless win95p();
    $! = 0;
    $resp = <$CHAN>;
    unless (win95p()) {
	alarm(0);
	if ($!) {	# may be channel truoble
	    im_notice("$!\n");
	    return '';
	}
    }
    $resp =~ s/[\r\n]+/\n/;
    im_notice(">>> $resp");
    $Session_log .= ">>> $resp" if ($Logging);
    chomp $resp;
    return $resp;
}

sub command_response () {
    return @Response;
}

sub set_command_response (@) {
    @Response = @_;
}

sub tcp_logging ($) {
#   conversations are saved in $Session_log if true
    $Logging = shift;
}

sub get_session_log () {
    return $Session_log;
}

sub set_cur_server ($) {
    $Cur_server = shift;
}

sub get_cur_server () {
    return $Cur_server;
}

sub pool_priv_sock ($) {
    my $count = shift;

    pool_priv_sock_af($count, AF_INET);
    pool_priv_sock_af($count, inet6_family());
}

sub pool_priv_sock_af ($$) {
    my ($count, $family) = @_;
    my $privport = 1023;

    no strict 'refs'; # XXX
    my ($pe_name, $pe_aliases, $pe_proto);
    ($pe_name, $pe_aliases, $pe_proto) = getprotobyname ('tcp');
    unless ($pe_name) {
	$pe_proto = 6;
    }
    while ($count--) {
	unless (socket(*{$TcpSockName}, $family, SOCK_STREAM, $pe_proto)) {
	    im_err("socket creation failed: $!.\n");
	    return -1;
	}
	while ($privport > 0) {
	    my ($ANYADDR, $psin);

	    im_debug("binding port $privport.\n") if (&debug('tcp'));
	    if ($family == AF_INET) {
		$ANYADDR = pack('C4', 0, 0, 0, 0);
		$psin = pack_sockaddr_in($privport, $ANYADDR);
	    } else {
		$ANYADDR = pack('C16', 0, 0, 0, 0, 0, 0, 0, 0,
				       0, 0, 0, 0, 0, 0, 0, 0);
		$psin = inet6_pack_sockaddr_in6($family, $privport, $ANYADDR);
	    }
	    last if (bind (*{$TcpSockName}, $psin));
	    im_warn("privileged socket binding failed: $!.\n")
		if (&debug('tcp'));
	    $privport--;
	}
	if ($privport == 0) {
	    im_err("binding to privileged port failed: $!.\n");
	    return -1;
	}
	im_notice("pool_priv_sock: $TcpSockName got\n");
	if ($family == AF_INET) {
	    push(@SockPool, $TcpSockName);
	} else {
	    push(@Sock6Pool, $TcpSockName);
	}
	$TcpSockName++;
    }
    return 0;
}

sub priv_sock ($) {
    my ($family) = shift;
    my ($sock_name);

    if ($family == AF_INET) {
	return '' if ($#SockPool < 0);
	$sock_name = shift(@SockPool);
    } else {
	return '' if ($#Sock6Pool < 0);
	$sock_name = shift(@Sock6Pool);
    }
    im_notice("priv_sock: $sock_name\n");
    return $sock_name;
}

sub alarm_func {
    im_die("connection error\n");
}

sub inet6_pack_sockaddr_in6 ($$;$) {
    my ($family, $port, $he_addr) = @_;

    if (eval '&AF_INET6') {   # perl supports IPv6
	return pack_sockaddr_in6($port, $he_addr);
    } else {
	return pack('CCnN', 1+1+2+4+16+4, $family, $port, 0) . $he_addr .
		    pack('N', 0);
    }
}

sub inet6_family () {
    return eval '&AF_INET6' || 24;
}

1;

### Copyright (C) 1997, 1998, 1999 IM developing team
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
