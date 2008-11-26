#########################################################################
# - Net::UCP 0.39 - 
# 
# Version : 0.39
# Date    : 29/11/2008
#
# Library based on EMI - UCP INTERFACE Specification 
# Version 3.5 of December 1999 
# Spcification Copyright (C) CMG telecommunication & Utilities BV Division 
# Advanced Technology
# 
# Library Copyright (C) 2004-2009 Marco Romano <nemux@cpan.org>
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.4 or,
# at your option, any later version of Perl 5 you may have available.
#
#########################################################################
package Net::UCP;

use strict;
use warnings;
use Carp;
use IO::Socket;
use IO::Select;
use Time::HiRes qw(setitimer ITIMER_REAL);

use Net::UCP::Common qw(:all);
use Net::UCP::IntTimeout;
use Net::UCP::TransactionManager;

require Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = ();

$VERSION = '0.39';

$VERSION = eval $VERSION; 

use constant TRUE => 1;

BEGIN { *logout = *close_link; }

sub new { bless({}, shift())->_init(@_); }

# login to SMSC
sub login {
    my $self = shift();
    my %args = (
		SMSC_ID    => '',
		SMSC_PW    => '',
		SHORT_CODE => undef,
		ONPI       => '',
		OTON       => '',
		STYP       => 1,       #def 1 (open session)
		VERS       => '0100',  #def 0100
		@_);

    # Conditionally open the socket unless already opened.
    $self->open_link() unless(defined($self->{SOCK}));
    unless(defined($self->{SOCK})) {
        return(defined(wantarray)?wantarray?(undef,0,''):undef:undef);
    }

    defined($args{SMSC_ID})&&length($args{SMSC_ID})||do {
	$self->{WARN}&&warn("Missing mandatory parameter 'SMSC_ID' when trying to login. Login failed");
	return(defined(wantarray)?wantarray?(undef,0,''):undef:undef);
    };
    
    defined($args{SMSC_PW})&&length($args{SMSC_PW})||do {
	$self->{WARN}&&warn("Missing mandatory parameter 'SMSC_PW' when trying to login. Login failed");
	return(defined(wantarray)?wantarray?(undef,0,''):undef:undef);
    };

    my $message_string = $self->make_message(
					     op        => '60',
					     operation => 1,
					     oadc      => $args{SMSC_ID},
					     oton      => $args{OTON},
					     onpi      => $args{ONPI},
					     styp      => $args{STYP},
					     pwd       => $args{SMSC_PW},
					     vers      => $args{VERS}
					     );
					 
    if ( defined $message_string ) { 
	my $timeout = $self->{TIMEOUT_OBJ}->get();        
	$self->transmit_msg($message_string, $timeout, 1);
    } else {
	return(defined(wantarray)?wantarray?(undef,0,''):undef:undef);
    }
}

# This method will also conditionally be called from the login() method.
sub open_link {
    my $self = shift;
    
    $self->{SOCK} = IO::Socket::INET->new(
					  PeerAddr  => $self->{SMSC_HOST},
					  PeerPort  => $self->{SMSC_PORT},
					  Proto     => 'tcp',
					  LocalAddr => defined($self->{SRC_HOST}) ? $self->{SRC_HOST} : undef,
					  LocalPort => defined($self->{SRC_PORT}) ? $self->{SRC_PORT} : undef
					  );

    defined($self->{SOCK})||do {
	$self->{WARN}&&warn("Failed to establish a socket connection with host $self->{SMSC_HOST} on port $self->{SMSC_PORT} : $!");
        return;
    };
    TRUE;
}


# To avoid keeping the socket open if not used any more.
sub close_link {
    my $self = shift;

    defined($self->{SOCK})||return;
    
    close($self->{SOCK});
    $self->{SOCK}=undef;
    $self->{TRN_OBJ}->reset_trn();
    TRUE;
}

# send SMS
sub send_sms {
    my $self = shift();
    my %args = (
		RECIPIENT      => '',
		MESSAGE_TEXT   => '',
		SENDER_TEXT    => '',
		UDH            => '',
		MESSAGE_BINARY => undef,
		FLASH          => undef,
		TIMEOUT        => undef,
		@_);

    my $timeout;

    if(defined($args{TIMEOUT})) {
        my $tv   = Net::UCP::IntTimeout->new( TIMEOUT => $args{TIMEOUT} );
        $timeout = $tv->get();
    }
    else {
        $timeout = $self->{TIMEOUT_OBJ}->get();
    }

    defined($args{RECIPIENT})&&length($args{RECIPIENT})||do {
        $self->{WARN}&&warn("Missing mandatory parameter 'RECIPIENT' when trying to send message. Transmission failed");
        return(defined(wantarray)?wantarray?(undef,0,''):undef:undef);
    };

    $args{RECIPIENT}=~s/^\+/00/;
    $args{RECIPIENT}=~/^\d+$/||do{
      $self->{WARN}&&warn("The recipient address contains illegal (non-numerical) characters: $args{RECIPIENT}\nMessage not sent ");
        return(defined(wantarray)?wantarray?(undef,0,''):undef:undef);
    };

    # It's OK to send an empty message, but not to use undef.
    defined($args{MESSAGE_TEXT})||($args{MESSAGE_TEXT}=' ');

    my $oadcTmp = '';
    my $otoaTmp = '';

    ($oadcTmp, $otoaTmp) = $self->_get_info_from($args{SENDER_TEXT}) if ((defined($args{SENDER_TEXT}) 
									    and 
									    length($args{SENDER_TEXT})));
    
    my $mclsTmp  = (defined($args{FLASH}) and ($args{FLASH} == 1)) ? 1 : ''; 
    my $class    = ($mclsTmp) ? 0 : 1;
 
    my %param_tmp = (
		     op        => '51',
		     operation => 1,
		     adc       => $args{RECIPIENT},
		     oadc      => $oadcTmp,		     
		     ac        => $self->{SHORT_CODE},
		     mt        => (defined($args{MESSAGE_BINARY}) ? '4' : '3'),
		     nb        => (defined($args{MESSAGE_BINARY}) ? 
				   (length($args{MESSAGE_BINARY})/2)*8 : ''),
		     dcs       => (defined($args{MESSAGE_BINARY}) ? '1' : ''),
		     mcls      => $mclsTmp,
		     otoa      => $otoaTmp,
		     xser      => (defined($args{MESSAGE_BINARY}) 
				   && 
				   defined($args{MESSAGE_BINARY}) 
				   ? 
				   make_xser("B", $args{UDH}, $class) : make_xser("T", $args{UDH}, $class)
				   )
		     );
    
    if (defined $args{MESSAGE_BINARY}) {
	$param_tmp{tmsg} = $args{MESSAGE_BINARY};
    } else {
	$param_tmp{amsg} = $args{MESSAGE_TEXT};
    }

    my $message_string = $self->make_message(%param_tmp);

    $self->transmit_msg($message_string, $timeout, 1);
}


sub send_sms_multipart {
    my $self = shift;
    
    my %argsLong =(
		   RECIPIENT      => '',
		   MESSAGE_TEXT   => '',
		   SENDER_TEXT    => '',
		   UDH            => undef,
		   MESSAGE_BINARY => undef,
		   FLASH          => undef,
		   TIMEOUT        => undef,
		   @_);

    my $chunkBlock = 134;                
    my $messageId  = random_int(1,255);  
    
    my $multiHash;
    
    my $txtTmp    = $argsLong{MESSAGE_TEXT};
    my $countPart = 0;
    my $chunk;
    
    while (length($txtTmp) != 0) {
	
        if (length($txtTmp) > 134) {
            $txtTmp =~ s/((.){134})//;
            $chunk = $1;
        } else {
            $chunk  = $txtTmp;
            $txtTmp = '';
        }
	
        $multiHash->{++$countPart} = $chunk;
	
    }
    
    my $textChunk = '';
    my $k        = '';
    my $udhChunk = '';
    my $ret;

    while (($k, $textChunk) = each %{$multiHash}) {
        $udhChunk = "0106050003" 
	    . sprintf("%02X", $messageId)
            . sprintf("%02X", $countPart)
            . sprintf("%02X", $k);
	
        $ret = $self->send_sms(
			       RECIPIENT      => $argsLong{RECIPIENT},
			       MESSAGE_TEXT   => $textChunk,
			       SENDER_TEXT    => $argsLong{SENDER_TEXT},
			       UDH            => $udhChunk,
			       );
    
	return $ret if (!$ret || !defined($ret)); #it could be better

    }
    
    return TRUE;

}

sub random_int ($$) {
    my($min, $max) = @_;

    return $min if $min == $max;
    
    ($min, $max) = ($max, $min)  if  $min > $max;
    return $min + int rand(1 + $max - $min);

}


sub _get_info_from {
    my ($self, $from) = @_;
    
    my ($oadc_tmp, $otoa_tmp);

    if ($from =~ /^([0-9]+)$/) {
	$otoa_tmp = '';
	if (length ($from) > 22) {substr($from,22) = ''}
	$oadc_tmp = $from;
    } elsif ($from =~ /^\+([0-9]+)$/) {
	$from =~ s/^.//;
	$otoa_tmp = '1139';
	if (length ($from) > 22) {substr($from,22) = ''}
	$oadc_tmp = $from;
    } else {
	$otoa_tmp = '5039';
	if (length ($from) > 11) {substr($from,11) = ''}
	$oadc_tmp = $from;
    }
    
    return ($oadc_tmp,$otoa_tmp);
}


#make_xser() subfunction.
#
#Parameters:
#1)Message Type   (it can be "T" -> Text or "B" -> Binary messages)
#2)UserDataHeader (in hexadecimal without octet length)
#3)Message Class  (optional)
##################################
sub make_xser {
    my $type=shift;
    my $udh=shift;
    my $class=shift;

    my $xser_ret = '';
    
    $class = 1 if ($class eq '');

#count UDH octest numbers
    my $udh_len = sprintf("%02X",length($udh)/2);

#count octets numbers of DD field
#numero totale di ottetti
    my $udh_oct = sprintf("%02X",(length($udh)/2)+1);

    if (not $class) {

        $type eq "T" and $xser_ret='020110';
	
        if ($udh =~ m/\d+/ and $type eq "T") {
            $xser_ret = $udh;
        }
	
    } else {
	
        if ($udh =~ m/\d+/ and $type eq "T") {
            $xser_ret = $udh;
        } else {
            $xser_ret='';
        }
	
    }
    
#XSER for binary message with udh
#XSER multipart
#TT 02 -> Xser per DCS
#LL 01 -> ottetti DD
#DD 00 -> imposta data coding scheme a 8 bit
#TT 01 -> Xser per UDH
#LL $udh_oct -> otetti UDH information field
#DD -> contiene UDH field specificato dall'utente
    
    $type eq "B" and $xser_ret='02011501'.$udh_oct.$udh_len.$udh;
    
    return $xser_ret;
    
}

sub _init {
    my $self = shift;

    $self->{OBJ_EMI_COMMON} = new Net::UCP::Common;
    $self->{TRN_OBJ}        = new Net::UCP::TransactionManager;
    $self->{TIMEOUT_OBJ}    = new Net::UCP::IntTimeout; 
   
    return $self if @_ == 0;
 
    my %args = (
		FAKE        => 0, 
		SMSC_HOST   => '',
		SMSC_PORT   => DEF_SMSC_PORT,
		SENDER_TEXT => '',
		WARN        => 0,
		TIMEOUT     => undef,
		SRC_HOST    => undef,
		SRC_PORT    => undef,
		@_);

    if ($args{FAKE} == 0) {

	$self->{WARN} = defined($args{WARN}) ? $args{WARN} ? 1 : 0 : 0;
	$self->{TIMEOUT_OBJ}->set($args{TIMEOUT});
	
	defined($args{SMSC_HOST}) && length($args{SMSC_HOST}) || do {
	    $self->{WARN}&&warn("Mandatory entity 'SMSC_HOST' was missing when creating an object of class ".
				__PACKAGE__.
				". Object not created");
	    return;       # Failed to instantiate this object.
	};
	defined($args{SMSC_PORT})&&length($args{SMSC_PORT})||do{
	    $self->{WARN}&&warn("Mandatory entity 'SMSC_PORT' was missing when creating an object of class ".
				__PACKAGE__.
				". Object not created");
	    return;       # Failed to instantiate this object.
	};
	$args{SMSC_PORT}=~/^\d+$/||do{
	    $self->{WARN}&&warn("Non-numerical data found in entity 'SMSC_PORT' when creating an object of class ".
				__PACKAGE__.
				". Object not created");
	    return;       # Failed to instantiate this object.
	};
	
	$self->{SMSC_HOST}   = $args{SMSC_HOST};
	$self->{SMSC_PORT}   = $args{SMSC_PORT};
	$self->{SENDER_TEXT} = defined($args{SENDER_TEXT})&&length($args{SENDER_TEXT})?$args{SENDER_TEXT}:__PACKAGE__;
	
	$self->{SRC_HOST} = $args{SRC_HOST};
	$self->{SRC_PORT} = $args{SRC_PORT};
	
	$self->{SOCK} = undef;
	
	# Some systems have not implemented alarm().
	# On such systems, calling alarm() will create a run-time error.
	# Determine if we dare calling alarm() or not.
	
	#I must work on it...
	
	eval{alarm(0)};
	$self->{CAN_ALARM} = $@ ? 0 : 1;
    }

    $self;
}



##RAW MODE

#timeout, action
#clear = 0,1
#################
sub wait_in_loop {
    my ($self) = shift;
    my %arg = @_;
    my ($retval, $bits);
    
    my $socket = $self->{SOCK};

    if (exists($arg{timeout}) and $arg{timeout} > 0) {
	$SIG{ALRM} = (exists($arg{action}) and ref($arg{action}) eq 'CODE') ? $arg{action} : \&_sig_alarm;
	setitimer(ITIMER_REAL, $arg{timeout}, 0);
    }
    
    while ($socket) {
	$bits = '';
        vec($bits,fileno($socket),1) = 1;
        $retval = 0;
        $retval = select($bits,undef,undef,undef);
        
	if ($retval) {
	    my ($buffer,$response);
	    do {
                read($socket,$buffer,1);
                $response.=$buffer;
            } until ($buffer eq ETX);   
	    
	    if (exists $arg{clear}) {
		$self->remove_ucp_enclosure(\$response) if ($arg{clear});
	    }
	    
	    setitimer(ITIMER_REAL, $arg{timeout}, 0);
	    return $response;
	}
    }

    setitimer(ITIMER_REAL, $arg{timeout}, 0);
    return undef;
}

sub remove_ucp_enclosure {
    my ($self, $msg) = @_;   
    $$msg =~ s/@{[ETX]}|@{[STX]}//g;
}

sub add_ucp_enclosure {
    my ($self, $msg) = @_;  
    $$msg = STX . $$msg . ETX;
}

sub _sig_alarm { croak "No response from SMSC\n"; }

#RAW functions
###########################
sub make_message {
    my $self = shift;
    my %arg = @_;
 
    my $op = $arg{op};
    my $string = undef;
    
    if ($op eq "01") { $string = $self->make_01(%arg) }
    elsif ($op eq "02") { $string = $self->make_02(%arg) }
    elsif ($op eq "03") { $string = $self->make_03(%arg) }
    elsif ($op eq "30") { $string = $self->make_30(%arg) }
    elsif ($op eq "31") { $string = $self->make_31(%arg) }
    elsif ($op eq "51") { $string = $self->make_51(%arg) }
    elsif ($op eq "52") { $string = $self->make_52(%arg) }
    elsif ($op eq "53") { $string = $self->make_53(%arg) }
    elsif ($op eq "54") { $string = $self->make_54(%arg) }
    elsif ($op eq "55") { $string = $self->make_55(%arg) }
    elsif ($op eq "56") { $string = $self->make_56(%arg) }
    elsif ($op eq "57") { $string = $self->make_57(%arg) }
    elsif ($op eq "58") { $string = $self->make_58(%arg) }
    elsif ($op eq "60") { $string = $self->make_60(%arg) }
    elsif ($op eq "61") { $string = $self->make_61(%arg) }

    return $string;
}

sub parse_message {
    my ($self, $resp) = @_;
 
    my $ref_mess = undef;

    if ($resp =~ m/^\d{2}\/\d{5}\/.*\/01\/.*/) { $ref_mess = $self->parse_01($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/02\/.*/) { $ref_mess = $self->parse_02($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/03\/.*/) { $ref_mess = $self->parse_03($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/30\/.*/) { $ref_mess = $self->parse_30($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/31\/.*/) { $ref_mess = $self->parse_31($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/51\/.*/) { $ref_mess = $self->parse_51($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/52\/.*/) { $ref_mess = $self->parse_52($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/53\/.*/) { $ref_mess = $self->parse_53($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/54\/.*/) { $ref_mess = $self->parse_54($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/55\/.*/) { $ref_mess = $self->parse_55($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/56\/.*/) { $ref_mess = $self->parse_56($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/57\/.*/) { $ref_mess = $self->parse_57($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/58\/.*/) { $ref_mess = $self->parse_58($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/60\/.*/) { $ref_mess = $self->parse_60($resp) }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.*\/61\/.*/) { $ref_mess = $self->parse_61($resp) }

    return $ref_mess;
}

# OPERATION TYPE 01
sub parse_01 {
    my ($self, $response)=@_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->{OBJ_EMI_COMMON}->checksum($resp_tmp);

    my (@ucp) = split(UCP_DELIMITER,$response);
   
    $mess{trn} = $ucp[0];
    $mess{len} = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot} = $ucp[3];
    
    if ($mess{type} eq "O") {
	$mess{adc} = $ucp[4];
	$mess{oadc} = $ucp[5];
	$mess{ac} = $ucp[6];
	$mess{mt} = $ucp[7];
	$mess{nmsg} = $mess{mt} == 2 ? $ucp[8] : '';
	$mess{amsg} = $mess{mt} == 3 ? $self->{OBJ_EMI_COMMON}->ia5_decode($ucp[8]) : '';
	$mess{checksum} = $ucp[9];
    } else {
	if ($ucp[4] eq ACK) {
	    $mess{ack} = $ucp[4];
	    $mess{sm} = $ucp[5];
	    $mess{checksum} = $ucp[6];
	} else {
	    $mess{nack} = $ucp[4];
	    $mess{ec} = $ucp[5];
	    $mess{sm} = $ucp[6];
	    $mess{checksum} = $ucp[7];
	}
    }
    
    return \%mess;
}

sub make_01 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;
    
    if (exists $arg{operation} and $arg{operation} == 1) {
	
	my $text = (exists $arg{nmsg} && !exists $arg{amsg}) 
	    ? $arg{nmsg} 
	: $self->{OBJ_EMI_COMMON}->ia5_encode($arg{amsg}); 

	my $string = 
	    (exists $arg{adc} ? $arg{adc} : '') .
	    UCP_DELIMITER .
	    (exists $arg{oadc} ? $arg{oadc} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{ac} ? $arg{ac} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{mt} ? $arg{mt} : '') .
	    UCP_DELIMITER .
	    $text;
	
	my $header = sprintf("%02d",$self->{TRN_OBJ}->next_trn()) .
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->data_len($string) .
	    UCP_DELIMITER .
	    'O'.                                   
	    UCP_DELIMITER .
	    '01';                                  
	
	$message_string = $header.
	    UCP_DELIMITER .
	    $string . 
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->checksum($header .
					      UCP_DELIMITER .
					      $string .
					      UCP_DELIMITER);

    } elsif (exists($arg{result}) and $arg{result} == 1) {

	if (exists $arg{ack} and $arg{ack} ne '') {
	
	    my $string = 
		$arg{ack} .
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '');

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER . 
		'R'.                                   
		UCP_DELIMITER .
		'01';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);

	} elsif (exists $arg{nack} and $arg{nack} ne '') {
	  
	    my $string = 
		$arg{nack} .
		UCP_DELIMITER .
		(exists $arg{ec} ? $arg{ec} : '') .
	        UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '');
	    
	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'01';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	}
    }
    
    return $message_string;
}

#OP 02
sub parse_02 {
    my ($self, $response)=@_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->{OBJ_EMI_COMMON}->checksum($resp_tmp);
    
    my (@ucp) = split(UCP_DELIMITER,$response);
    #header...
    $mess{trn} = $ucp[0];
    $mess{len} = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot} = $ucp[3];
    
    if ($mess{type} eq "O") {
	$mess{npl} = $ucp[4];
	$mess{rads} = $ucp[5];
	$mess{oadc} = $ucp[6];
	$mess{ac} = $ucp[7];
	$mess{mt} = $ucp[8];
	$mess{nmsg} = $mess{mt} == 2 ? $ucp[9] : '';
	$mess{amsg} = $mess{mt} == 3 ? $self->{OBJ_EMI_COMMON}->ia5_decode($ucp[9]) : '';
	$mess{checksum} = $ucp[10];
    } else {
	if ($ucp[4] eq ACK) {
	    $mess{ack} = $ucp[4];
	    $mess{sm} = $ucp[5];
	    $mess{checksum} = $ucp[6];
	} else {
	    $mess{nack} = $ucp[4];
	    $mess{ec} = $ucp[5];
	    $mess{sm} = $ucp[6];
	    $mess{checksum} = $ucp[7];
	}
    }
    
    return \%mess;
}


sub make_02 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (exists $arg{operation} and $arg{operation} == 1) {

	my $text = (exists $arg{nmsg} && !exists $arg{amsg}) 
	    ? $arg{nmsg} 
	: $self->{OBJ_EMI_COMMON}->ia5_encode($arg{amsg}); 

	my $string = 
	    (exists $arg{npl} ? $arg{npl} : '') .
	    UCP_DELIMITER .
	    (exists $arg{rads} ? $arg{rads} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{oadc} ? $arg{oadc} : '') .
	    UCP_DELIMITER .
	    (exists $arg{ac} ? $arg{ac} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{mt} ? $arg{mt} : '') .
	    UCP_DELIMITER .
	    $text;

	my $header = sprintf("%02d",$self->{TRN_OBJ}->next_trn()) .
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->data_len($string) .
	    UCP_DELIMITER.
	    'O'.                                   
	    UCP_DELIMITER.
	    '02';                                  
	
	$message_string = $header.
	    UCP_DELIMITER .
	    $string . 
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->checksum($header .
					      UCP_DELIMITER .
					      $string .
					      UCP_DELIMITER);
	
    } elsif (exists($arg{result}) and $arg{result} == 1) {

	if (exists $arg{ack} and $arg{ack} ne '') {
	
	    my $string = 
		$arg{ack} .
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '') ;

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'02';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);

	} elsif (exists $arg{nack} and $arg{nack} ne '') {
	    
	    my $string = 
		$arg{nack} .
		UCP_DELIMITER .
		(exists $arg{ec} ? $arg{ec} : '') . 
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '') ;

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'02';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	}
    }
    
    return $message_string;
}


#OP 03
sub parse_03 {
    my ($self, $response)=@_;
    my %mess ;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->{OBJ_EMI_COMMON}->checksum($resp_tmp);
    
    my (@ucp) = split(UCP_DELIMITER,$response);
    #header...
    $mess{trn} = $ucp[0];
    $mess{len} = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot} = $ucp[3];
    
    if ($mess{type} eq "O") {
	$mess{rad} = $ucp[4];
	$mess{oadc} = $ucp[5];
	$mess{ac} = $ucp[6];
	$mess{npl} = $ucp[7]; #must be 0
	$mess{gas} = $ucp[8]; #empty if npl 0	
	$mess{rp} = $ucp[9];
	$mess{pr} = $ucp[10];
	$mess{lpr} = $ucp[11];
	$mess{ur} = $ucp[12];
	$mess{lur} = $ucp[13];
	$mess{rc} = $ucp[14];
	$mess{lrc} = $ucp[15];
	$mess{dd} = $ucp[16];
	$mess{ddt} = $ucp[17];
	$mess{mt} = $ucp[18];
	$mess{nmsg} = $mess{mt} == 2 ? $ucp[19] : '';
	$mess{amsg} = $mess{mt} == 3 ? $self->{OBJ_EMI_COMMON}->ia5_decode($ucp[19]) : '';
	$mess{checksum} = $ucp[20];
    } else {
	if ($ucp[4] eq ACK) {
	    $mess{ack} = $ucp[4];
	    $mess{sm} = $ucp[5];
	    $mess{checksum} = $ucp[6];
	} else {
	    $mess{nack} = $ucp[4];
	    $mess{ec} = $ucp[5];
	    $mess{sm} = $ucp[6];
	    $mess{checksum} = $ucp[7];
	}
    }
    
    return \%mess;
}


sub make_03 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (exists $arg{operation} and $arg{operation} == 1) {

	my $text = (exists $arg{nmsg} && !exists $arg{amsg}) 
	    ? $arg{nmsg} 
	: $self->{OBJ_EMI_COMMON}->ia5_encode($arg{amsg}); 

	my $string = 
	    (exists $arg{rad} ? $arg{rad} : '') .
	    UCP_DELIMITER .
	    (exists $arg{oadc} ? $arg{oadc} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{ac} ? $arg{ac} : '') .
	    UCP_DELIMITER .
	    (exists $arg{npl} ? $arg{npl} : '') .
	    UCP_DELIMITER .
	    (exists $arg{gas} ? $arg{gas} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{rp} ? $arg{rp} : '') .
	    UCP_DELIMITER .
	    (exists $arg{pr} ? $arg{pr} : '') .
	    UCP_DELIMITER .
	    (exists $arg{lpr} ? $arg{lpr} : '') .
	    UCP_DELIMITER .
	    (exists $arg{ur} ? $arg{ur} : '') .
	    UCP_DELIMITER .
	    (exists $arg{lur} ? $arg{lur} : '') .
	    UCP_DELIMITER .
	    (exists $arg{rc} ? $arg{rc} : '') .
	    UCP_DELIMITER .
	    (exists $arg{lrc} ? $arg{lrc} : '') .
	    UCP_DELIMITER .
	    (exists $arg{dd} ? $arg{dd} : '') .
	    UCP_DELIMITER .
	    (exists $arg{ddt} ? $arg{ddt} : '') .
	    UCP_DELIMITER .
	    (exists $arg{mt} ? $arg{mt} : '') .
	    UCP_DELIMITER .
	    $text;

	my $header = sprintf("%02d",$self->{TRN_OBJ}->next_trn()) .
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->data_len($string) .
	    UCP_DELIMITER.
	    'O'.                                   
	    UCP_DELIMITER.
	    '03';                                  
	
	$message_string = $header.
	    UCP_DELIMITER .
	    $string . 
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->checksum($header .
					      UCP_DELIMITER .
					      $string .
					      UCP_DELIMITER);

    } elsif (exists($arg{result}) and $arg{result} == 1) {

	if (exists $arg{ack} and $arg{ack} ne '') {
	
	    my $string = 
		$arg{ack} .
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '');

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'03';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);

	} elsif (exists $arg{nack} and $arg{nack} ne '') {
	    
	    my $string = 
		$arg{nack} .
		UCP_DELIMITER .
		(exists $arg{ec} ? $arg{ec} : '') . 
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : ''); 

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'03';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	}
    }
    
    return $message_string;
}


#OP 30
sub parse_30 {
    my ($self, $response)=@_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->{OBJ_EMI_COMMON}->checksum($resp_tmp);

    my (@ucp) = split(UCP_DELIMITER,$response);
    #header...
    $mess{trn} = $ucp[0];
    $mess{len} = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot} = $ucp[3];
    
    if ($mess{type} eq "O") {
	$mess{adc} = $ucp[4];
	$mess{oadc} = $ucp[5];
	$mess{ac} = $ucp[6];
	$mess{nrq} = $ucp[7];
	$mess{nad} = $ucp[8];
	$mess{npid} = $ucp[9];
	$mess{dd} = $ucp[10];
	$mess{ddt} = $ucp[11];
	$mess{vp} = $ucp[12];
	$mess{amsg} = $self->{OBJ_EMI_COMMON}->ia5_decode($ucp[13]);
	$mess{checksum} = $ucp[14];
    } else {
	if ($ucp[4] eq ACK) {
	    $mess{ack} = $ucp[4];
	    $mess{mvp} = $ucp[5];
	    $mess{sm} = $ucp[6];
	    $mess{checksum} = $ucp[7];
	} else {
	    $mess{nack} = $ucp[4];
	    $mess{ec} = $ucp[5];
	    $mess{sm} = $ucp[6];
	    $mess{checksum} = $ucp[7];
	}
    }
    
    return \%mess;
}


sub make_30 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (exists $arg{operation} and $arg{operation} == 1) {

	my $text = $self->{OBJ_EMI_COMMON}->ia5_encode($arg{amsg}); 

	my $string = 
	    (exists $arg{adc} ? $arg{adc} : '') .
	    UCP_DELIMITER .
	    (exists $arg{oadc} ? $arg{oadc} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{ac} ? $arg{ac} : '') .
	    UCP_DELIMITER .
	    (exists $arg{nrq} ? $arg{nrq} : '') .
	    UCP_DELIMITER .
	    (exists $arg{nad} ? $arg{nad} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{npid} ? $arg{npid} : '') .
	    UCP_DELIMITER .
	    (exists $arg{dd} ? $arg{dd} : '') .
	    UCP_DELIMITER .
	    (exists $arg{ddt} ? $arg{ddt} : '') .
	    UCP_DELIMITER .
	    (exists $arg{vp} ? $arg{vp} : '') .
	    UCP_DELIMITER .
	    $text;

	my $header = sprintf("%02d",$self->{TRN_OBJ}->next_trn()) .
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->data_len($string) .
	    UCP_DELIMITER.
	    'O'.                                   
	    UCP_DELIMITER.
	    '30';                                  
	
	$message_string = $header.
	    UCP_DELIMITER .
	    $string . 
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->checksum($header .
					      UCP_DELIMITER .
					      $string .
					      UCP_DELIMITER);

    } elsif (exists($arg{result}) and $arg{result} == 1) {

	if (exists $arg{ack} and $arg{ack} ne '') {
	
	    my $string = 
		$arg{ack} .
		UCP_DELIMITER .
		(exists $arg{mvp} ? $arg{mvp} : '') .
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '') ;

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'30';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	    
	} elsif (exists $arg{nack} and $arg{nack} ne '') {
	    
	    my $string = 
		$arg{nack} .
		UCP_DELIMITER .
		(exists $arg{ec} ? $arg{ec} : '') . 
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : ''); 

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'30';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	}
    }
    
    return $message_string;
}


#OP 31
sub parse_31 {
    my ($self, $response)=@_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->{OBJ_EMI_COMMON}->checksum($resp_tmp);

    my (@ucp) = split(UCP_DELIMITER,$response);
    #header...
    $mess{trn} = $ucp[0];
    $mess{len} = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot} = $ucp[3];
    
    if ($mess{type} eq "O") {
	$mess{adc} = $ucp[4];
	$mess{pid} = $ucp[5];
	$mess{checksum} = $ucp[6];
    } else {
	if ($ucp[4] eq ACK) {
	    $mess{ack} = $ucp[4];
	    $mess{sm} = $ucp[5];
	    $mess{checksum} = $ucp[6];
	} else {
	    $mess{nack} = $ucp[4];
	    $mess{ec} = $ucp[5];
	    $mess{sm} = $ucp[6];
	    $mess{checksum} = $ucp[7];
	}
    }
    
    return \%mess;
}


sub make_31 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (exists $arg{operation} and $arg{operation} == 1) {

	my $string = 
	    (exists $arg{adc} ? $arg{adc} : '') .
	    UCP_DELIMITER .
	    (exists $arg{pid} ? $arg{pid} : '') ; 
	    
	my $header = sprintf("%02d",$self->{TRN_OBJ}->next_trn()) .
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->data_len($string) .
	    UCP_DELIMITER.
	    'O'.                                   
	    UCP_DELIMITER.
	    '31';                                  
	
	$message_string = $header.
	    UCP_DELIMITER .
	    $string . 
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->checksum($header .
					      UCP_DELIMITER .
					      $string .
					      UCP_DELIMITER);

    } elsif (exists($arg{result}) and $arg{result} == 1) {

	if (exists $arg{ack} and $arg{ack} ne '') {
	
	    my $string = 
		$arg{ack} .
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '') ;

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'31';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	    
	} elsif (exists $arg{nack} and $arg{nack} ne '') {
	    
	    my $string = 
		$arg{nack} .
		UCP_DELIMITER .
		(exists $arg{ec} ? $arg{ec} : '') . 
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : ''); 

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'31';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	}
    }
    
    return $message_string;
}


#OP 5x abstract
sub _parse_5x {
    my ($self, $response)=@_;
    my %mess;

    my $resp_tmp = $response; 
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->{OBJ_EMI_COMMON}->checksum($resp_tmp);

    my (@ucp) = split(UCP_DELIMITER,$response);
    #header...
    $mess{trn} = $ucp[0];
    $mess{len} = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot} = $ucp[3];
    
    if ($mess{type} eq "O") {
	$mess{adc} = $ucp[4];
	$mess{otoa} = $ucp[32];
	$mess{oadc} = ($mess{otoa} eq "5039") ? $self->{OBJ_EMI_COMMON}->decode_7bit(substr($ucp[5],2)) : $ucp[5];
	$mess{ac} = $ucp[6];
	$mess{nrq} = $ucp[7];
	$mess{nadc} = $ucp[8]; 
	$mess{nt} = $ucp[9];
	$mess{npid} = $ucp[10];
	$mess{lrq} = $ucp[11];
	$mess{lrad} = $ucp[12];
	$mess{lpid} = $ucp[13];
	$mess{dd} = $ucp[14];
	$mess{ddt} = $ucp[15];
	$mess{vp} = $ucp[16];
	$mess{rpid} = $ucp[17];
	$mess{scts} = $ucp[18];
        $mess{dst} = $ucp[19];
	$mess{rsn} = $ucp[20];
	$mess{dscts} = $ucp[21];
	$mess{mt} = $ucp[22];
	$mess{nb} = $ucp[23];
        $mess{nmsg} = $ucp[24] if ($mess{mt} && $mess{mt} == 2);
        $mess{amsg} = $self->{OBJ_EMI_COMMON}->ia5_decode($ucp[24]) if ($mess{mt} && $mess{mt} == 3);
	$mess{tmsg} = $ucp[24] if ($mess{mt} && $mess{mt} == 4);
	$mess{mms} = $ucp[25];
	$mess{pr} = $ucp[26];
	$mess{dcs} = $ucp[27];
	$mess{mcls} = $ucp[28];
	$mess{rpi} = $ucp[29];
	$mess{cpg} = $ucp[30];
	$mess{rply} = $ucp[31];
	$mess{hplmn} = $ucp[33];
	$mess{xser} = $ucp[34];
	$mess{res4} = $ucp[35];
	$mess{res5} = $ucp[36];
	$mess{checksum} = $ucp[37];
    } else {
	if ($ucp[4] eq ACK) {
	    $mess{ack} = $ucp[4];
	    $mess{mvp} = $ucp[5];
	    $mess{sm} = $ucp[6];
	    $mess{checksum} = $ucp[7];
	} else {
	    $mess{nack} = $ucp[4];
	    $mess{ec} = $ucp[5];
	    $mess{sm} = $ucp[6];
	    $mess{checksum} = $ucp[7];
	}
    }
    
    return \%mess;

}

sub _make_5x {
    my ($self) = shift;
    my $arg = shift;
    my $op_type = shift;
    
    my $message_string = undef;

    if (exists $arg->{operation} and $arg->{operation} == 1) {

	my $text = '';
	my $from = '';

	if (exists $arg->{amsg}) {
	    $text = $self->{OBJ_EMI_COMMON}->ia5_encode($arg->{amsg});
	} else {
	    $text = exists $arg->{nmsg} && !exists $arg->{tmsg} ? $arg->{nmsg} : $arg->{tmsg};
	}
	
	$from = $arg->{otoa} eq '5039' 
	    ? $self->{OBJ_EMI_COMMON}->encode_7bit($arg->{oadc}) 
	    : $arg->{oadc} 
	if exists $arg->{otoa} ;
	    
	my $string = 
	    (exists $arg->{adc} ? $arg->{adc} : '') .
	    UCP_DELIMITER .
	    $from . 
	    UCP_DELIMITER .
	    (exists $arg->{ac} ? $arg->{ac} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{nrq} ? $arg->{nrq} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{nadc} ? $arg->{nadc} : '') . 
	    UCP_DELIMITER .
	    (exists $arg->{nt} ? $arg->{nt} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{npid} ? $arg->{npid} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{lrq} ? $arg->{lrq} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{lrad} ? $arg->{lrad} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{lpid} ? $arg->{lpid} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{dd} ? $arg->{dd} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{ddt} ? $arg->{ddt} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{vp} ? $arg->{vp} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{rpid} ? $arg->{rpid} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{scts} ? $arg->{scts} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{dst} ? $arg->{dst} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{rsn} ? $arg->{rsn} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{dscts} ? $arg->{dscts} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{mt} ? $arg->{mt} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{nb} ? $arg->{nb} : '') .
	    UCP_DELIMITER .
	    $text .
	    UCP_DELIMITER .
	    (exists $arg->{mms} ? $arg->{mms} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{pr} ? $arg->{pr} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{dcs} ? $arg->{dcs} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{mcls} ? $arg->{mcls} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{rpi} ? $arg->{rpi} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{cpg} ? $arg->{cpg} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{rply} ? $arg->{rply} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{otoa} ? $arg->{otoa} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{hplmn} ? $arg->{hplmn} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{xser} ? $arg->{xser} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{res4} ? $arg->{res4} : '') .
	    UCP_DELIMITER .
	    (exists $arg->{res5} ? $arg->{res5} : '') 
	    ;
	    
	my $header = sprintf("%02d",$self->{TRN_OBJ}->next_trn()) .
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->data_len($string) .
	    UCP_DELIMITER.
	    'O'.                                   
	    UCP_DELIMITER.
	    $op_type;                                  
	
	$message_string = $header.
	    UCP_DELIMITER .
	    $string . 
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->checksum($header .
					      UCP_DELIMITER .
					      $string .
					      UCP_DELIMITER);

    } elsif (exists($arg->{result}) and $arg->{result} == 1) {
	
	if (exists $arg->{ack} and $arg->{ack} ne '') {
	    
	    my $string = 
		$arg->{ack} .
		UCP_DELIMITER .
		(exists $arg->{mvp} ? $arg->{mvp} : '') .
	        UCP_DELIMITER .
		(exists $arg->{sm} ? $arg->{sm} : '') ;

	    my $header = sprintf("%02d",$arg->{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		$op_type;                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);

	} elsif (exists $arg->{nack} and $arg->{nack} ne '') {
	    
	    my $string = 
		$arg->{nack} .
		UCP_DELIMITER .
		(exists $arg->{ec} ? $arg->{ec} : '') . 
		UCP_DELIMITER .
		(exists $arg->{sm} ? $arg->{sm} : '') ; 

	    my $header = sprintf("%02d",$arg->{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		$op_type;                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	}
    }
    
    return $message_string;
}

#submit
sub parse_51 {
    my ($self, $response)=@_;
    return $self->_parse_5x($response);
}

#OP 52 delivery short message
sub parse_52 {
    my ($self, $response)=@_;
    return $self->_parse_5x($response);
}

sub parse_53 {
    my ($self, $response)=@_;
    return $self->_parse_5x($response);
}

sub parse_54 {
    my ($self, $response)=@_;
    return $self->_parse_5x($response);
}

sub parse_55 {
    my ($self, $response)=@_;
    return $self->_parse_5x($response);
}

sub parse_56 {
    my ($self, $response)=@_;
    return $self->_parse_5x($response);
}

sub parse_57 {
    my ($self, $response)=@_;
    return $self->_parse_5x($response);
}

sub parse_58 {
    my ($self, $response)=@_;
    return $self->_parse_5x($response);
}

sub make_51 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg,'51');
}

sub make_52 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg,'52');
}

sub make_53 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg,'53');
}

sub make_54 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg,'54');
}

sub make_55 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg,'55');
}

sub make_56 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg,'56');
}

sub make_57 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg,'57');
}

sub make_58 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg,'58');
}


#OP 60 abstract
sub parse_60 {
    my ($self, $response)=@_;
    my %mess;

    my $resp_tmp = $response; 
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->{OBJ_EMI_COMMON}->checksum($resp_tmp);

    my (@ucp) = split(UCP_DELIMITER,$response);
    #header...
    $mess{trn}  = $ucp[0];
    $mess{len}  = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot}   = $ucp[3];
    
    if ($mess{type} eq "O") {
	$mess{oadc} = $ucp[4];
	$mess{oton} = $ucp[5];
	$mess{onpi} = $ucp[6];
	$mess{styp} = $ucp[7];
	$mess{pwd} = $self->{OBJ_EMI_COMMON}->ia5_decode($ucp[8]); 
	$mess{npwd} = $self->{OBJ_EMI_COMMON}->ia5_decode($ucp[9]);
	$mess{vers} = $ucp[10];
	$mess{ladc} = $ucp[11];
	$mess{lton} = $ucp[12];
	$mess{lnpi} = $ucp[13];
	$mess{opid} = $ucp[14];
	$mess{res1} = $ucp[15];
	$mess{checksum} = $ucp[16];
    } else {
	if ($ucp[4] eq ACK) {
	    $mess{ack} = $ucp[4];
	    $mess{sm} = $ucp[5];
	    $mess{checksum} = $ucp[6];
	} else {
	    $mess{nack} = $ucp[4];
	    $mess{ec} = $ucp[5];
	    $mess{sm} = $ucp[6];
	    $mess{checksum} = $ucp[7];
	}
    }
    
    return \%mess;
}

sub parse_61 {
    my ($self, $response)=@_;
    return $self->parse_60($response);
}


sub make_60 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (exists $arg{operation} and $arg{operation} == 1) {

	my $string = 
	    (exists $arg{oadc} ? $arg{oadc} : '') .
	    UCP_DELIMITER .
	    (exists $arg{oton} ? $arg{oton} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{onpi} ? $arg{onpi} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{styp} ? $arg{styp} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{pwd} ? $self->{OBJ_EMI_COMMON}->ia5_encode($arg{pwd}) : '') . 
	    UCP_DELIMITER .
	    (exists $arg{npwd} ? $self->{OBJ_EMI_COMMON}->ia5_encode($arg{npwd}) : '') . 
	    UCP_DELIMITER .
	    (exists $arg{vers} ? $arg{vers} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{ladc} ? $arg{ladc} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{lton} ? $arg{lton} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{lnpi} ? $arg{lnpi} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{opid} ? $arg{opid} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{res1} ? $arg{res1} : '') ; 
	
	my $header = sprintf("%02d",$self->{TRN_OBJ}->next_trn()) .
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->data_len($string) .
	    UCP_DELIMITER.
	    'O'.                                   
	    UCP_DELIMITER.
	    '60';                                  
	
	$message_string = $header.
	    UCP_DELIMITER .
	    $string . 
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->checksum($header .
					      UCP_DELIMITER .
					      $string .
					      UCP_DELIMITER);

    } elsif (exists($arg{result}) and $arg{result} == 1) {

	if (exists $arg{ack} and $arg{ack} ne '') {
	
	    my $string = 
		$arg{ack} .
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '') ;

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'60';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	    
	} elsif (exists $arg{nack} and $arg{nack} ne '') {
	    
	    my $string = 
		$arg{nack} .
		UCP_DELIMITER .
		(exists $arg{ec} ? $arg{ec} : '') . 
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '') ; 

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'60';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	}
    }
    
    return $message_string;
}


sub make_61 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (exists $arg{operation} and $arg{operation} == 1) {

	my $string = 
	    (exists $arg{oadc} ? $arg{oadc} : '') .
	    UCP_DELIMITER .
	    (exists $arg{oton} ? $arg{oton} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{onpi} ? $arg{onpi} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{styp} ? $arg{styp} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{pwd} ? $self->{OBJ_EMI_COMMON}->ia5_encode($arg{pwd}) : '') . 
	    UCP_DELIMITER .
	    (exists $arg{npwd} ? $self->{OBJ_EMI_COMMON}->ia5_encode($arg{npwd}) : '') . 
	    UCP_DELIMITER .
	    (exists $arg{vers} ? $arg{vers} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{ladc} ? $arg{ladc} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{lton} ? $arg{lton} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{lnpi} ? $arg{lnpi} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{opid} ? $arg{opid} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{res1} ? $arg{res1} : '') . 
	    UCP_DELIMITER .
	    (exists $arg{res2} ? $arg{res2} : '') ; 
	
	my $header = sprintf("%02d",$self->{TRN_OBJ}->next_trn()) .
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->data_len($string) .
	    UCP_DELIMITER.
	    'O'.                                   
	    UCP_DELIMITER.
	    '61';                                  
	
	$message_string = $header.
	    UCP_DELIMITER .
	    $string . 
	    UCP_DELIMITER .
	    $self->{OBJ_EMI_COMMON}->checksum($header .
					      UCP_DELIMITER .
					      $string .
					      UCP_DELIMITER);

    } elsif (exists($arg{result}) and $arg{result} == 1) {

	if (exists $arg{ack} and $arg{ack} ne '') {
	
	    my $string = 
		$arg{ack} .
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '') ;

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'61';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	    
	} elsif (exists $arg{nack} and $arg{nack} ne '') {
	    
	    my $string = 
		$arg{nack} .
		UCP_DELIMITER .
		(exists $arg{ec} ? $arg{ec} : '') . 
		UCP_DELIMITER .
		(exists $arg{sm} ? $arg{sm} : '') ; 

	    my $header = sprintf("%02d",$arg{trn}) .
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->data_len($string) .
		UCP_DELIMITER.
		'R'.                                   
		UCP_DELIMITER.
		'61';                                  

	    $message_string = $header.
		UCP_DELIMITER .
		$string . 
		UCP_DELIMITER .
		$self->{OBJ_EMI_COMMON}->checksum($header .
						  UCP_DELIMITER .
						  $string .
						  UCP_DELIMITER);
	}
    }
    
    return $message_string;
}

#it doesn't get response!
#param : host, port, listen
#param : output, action, sending
#param : reading_mode  (0 = line feed at the end, 1 = reading defined message length - default 1Kb)
#param  : max_len (for reading_mode = 1)
##################################
sub create_fake_smsc {
    my $self = shift;
    my %opt = @_;
    
    my $remote_socket = undef;
    
    my $main_socket = new IO::Socket::INET (LocalHost => exists $opt{host} && $opt{host} ne '' ? $opt{host} : '127.0.0.1',
					    LocalPort => exists $opt{port} && $opt{port} ne '' ? $opt{port} : 6666,
					    Listen => exists $opt{listen} ? $opt{listen} : 5,
					    Proto => 'tcp',
					    Reuse => 1,
					    );
    croak "Fake SMSC could not be created, [$!]\n" unless ($main_socket);
    

    my $debug = (exists $opt{output} and $opt{output} == 1) ? 1 : 0; 

    my $reading_mode = 0;
    if (exists $opt{reading_mode}) {
	if ($opt{reading_mode} != 0 && $opt{reading_mode} != 1) {
	    $reading_mode = 0;
	} else {
	    $reading_mode = $opt{reading_mode};
	}
    } 
    
    my $max_len = (exists $opt{max_len} and $opt{max_len} >= 1) ? $opt{max_len} : 1024; 
    
    my $readable_handles = new IO::Select();
    $readable_handles->add($main_socket);

    my ($sock, $new_sock);
    
    while (1) {
	my ($new_readable) = IO::Select->select($readable_handles, undef, undef, undef);
	foreach $sock (@$new_readable) {
	    if ($sock == $main_socket) {
		$new_sock = $sock->accept();
		$readable_handles->add($new_sock);
	    } else {

		print "[*] Reading on socket [$sock]\n" if $debug;
		my $message = 0;

		$message = <$sock> if (!$reading_mode);
		$sock->recv($message, $max_len) if ($reading_mode == 1);
		
		if ($message) {
		    $message =~ s/[\n\r]//g;
		    if ($debug) {
			print "\n\n[*] UCP string -\n";
			print "-"x30;
			print "\n" . $message . "\n";
			print "-"x30;
			print "\n";
		    }
		    
		    if (exists $opt{action} and ref($opt{action}) eq "CODE") {
			my $resp_be = $opt{action}($message);
			print $sock $resp_be if (defined($resp_be) && ($resp_be ne ''));

			if (exists $opt{sending} and ref($opt{sending}) eq "CODE") {
			    my $next_ucp_message = $opt{sending}();
			    print $sock $next_ucp_message if (defined($next_ucp_message) && ($next_ucp_message ne ''));
                        }

		    } else {
			my $response = $self->parse_message($message);
			if (ref($response) eq "HASH") {			    
			    foreach my $k (keys %{$response}) {
				print "\nP.Name: [$k] - Value:\t$response->{$k}" if $debug;
			    }
			} else {
			    print "Error while parsing message\n";
			}
		    }
		} else {
		    
		    print "[*] Closing socket [$sock]\n" if $debug;
		    $readable_handles->remove($sock);
		    close($sock);
		
		}
	    }
	}
    }
    
    return;
}

sub transmit_msg {
    my($self, $message_string, $timeout, $need_resp) = @_;

    my($rd,$buffer,$response,$acknack,$errcode,$errtxt,$ack);

    defined($timeout) || do{ $timeout = 0 };

    if (!defined($self->{SOCK})) {
	die "Unable to send message : smsc socket is not initialized, maybe u are using it in FAKE mode... ";
    }
    my $enclosed = STX . $message_string . ETX;

    print {$self->{SOCK}} $enclosed || do {
        $errtxt = "Failed to print to SMSC socket. Remote end closed?";
        $self->{WARN} && warn($errtxt);
        return(defined(wantarray) ? wantarray?(undef,0,$errtxt) : undef : undef);
    };
    
    $self->{SOCK}->flush();

    if ($need_resp == 1) {
	do  {
	    # If this system implements alarm(), we will do a non-blocking read.
	    if($self->{CAN_ALARM}) {
		eval {
		    $rd=undef;
		    local($SIG{ALRM})=sub{die("alarm\n")}; # NB: \n required
		    alarm($timeout);
		    $rd=read($self->{SOCK},$buffer,1);
		    alarm(0);
		};
		# Propagate unexpected errors.
		$@&&$@ne"alarm\n"&&die($@);
	    }
	    else {
		# No alarm() implemented. Must do a (potentially) blocking call to read().
		$rd=read($self->{SOCK},$buffer,1);
	    }
	    defined($rd)||do{ # undef, read error.
		$errtxt="Failed to read from SMSC socket. Never received ETX. Remote end closed?";
		$self->{WARN}&&warn($errtxt);
		return(defined(wantarray)?wantarray?(undef,0,$errtxt):undef:undef);
	    };
	    $rd||do{ # Zero, end of 'file'.
		$errtxt="Never received ETX from SMSC. Remote end closed?";
		$self->{WARN}&&warn($errtxt);
		return(defined(wantarray)?wantarray?(undef,0,$errtxt):undef:undef);
	    };
	    $response.=$buffer;
	}   until($buffer eq ETX);

	(undef,undef,undef,undef,$acknack,$errcode,$errtxt,undef)=split(UCP_DELIMITER, $response);
	if($acknack eq ACK) {
	    ($ack,$errcode,$errtxt)=(TRUE,0,'');
	}
	else {
	    $ack    = 0;
	    $errtxt =~ s/^\s+//;
	    $errtxt =~ s/\s+$//;
	}
    
	$errtxt .= "\nSent : " . $message_string . "\nReceive : " . $response . "\n";
	defined(wantarray) ? wantarray ? ($ack, $errcode, $errtxt) : $ack : undef;
    
    } else {
	defined(wantarray) ? wantarray ? (undef, undef, undef) : undef : undef;
    }

}

1;

__END__

=head1 NAME

Net::UCP - Perl extension for EMI - UCP Protocol.

=head1 SYNOPSIS

    use Net::UCP;

    $emi = Net::UCP->new(
	         	 SMSC_HOST   => 'smsc.somedomain.tld', 
		         SMSC_PORT   => 3024, 
		         SENDER_TEXT => 'My Self 123', 
		         SRC_HOST=   => 'my.host.tld', 
		         SRC_PORT    => '1666',
			 FAKE => 0,
			 );

=head1 DESCRIPTION

This module implements a B<Client> Interface to the B<EMI - UCP Interface> specification,
This Protocol can be used to comunicate with an SMSC (Short Message Service Centre)

Usually the Network connection is based on TCP/IP or X.25. 

You will of course be required to have a valid login at the SMSC to use their services.
(Unless there is an SMSC which provides their services for free. Please, let me know about any 
such service provider.) If you want to help my project send me info about some SMSC account.

A Net::UCP object must be created with the new() constructor.
Once this has been done, all commands are accessed via method calls on the object.

If you have a good know-how about EMI/UCP or if you have patience to read 
specification you can use this module in raw mode. 
See RAW MODE for more informations.

=head1 EXAMPLE
   
    use Encode;   #you need it to convert text to GSM 03.38 Default Alphabet. See DATA CODING section
    use Net::UCP;
    
    ($recipient,$text,$sender) = @ARGV;
     
    my ($acknowledge, $error_number, $error_text);

    $emi = Net::UCP->new(SMSC_HOST   => 'smsc.somedomain.tld',
			 SMSC_PORT   => 3024,
			 SENDER_TEXT => 'MyApp',
			 SRC_HOST    => '10.10.10.21', #optional see below
			 SRC_PORT    => '1666',        #optional see below
			 WARN        => 1,
			 FAKE        => 0
			 ) or die("Failed to create SMSC object");
    
    $emi->open_link() or die($!);

    ($acknowledge,$error_number,$error_text) = $emi->login(
							   SMSC_ID    => 'your_account_id',
							   SMSC_PW    => 'your password',
							   SHORT_CODE => 'your Auth Code',
							   OTON       => '5',        #optional
							   ONPI       => '1',        #optional 
							   VERS       => '0100',     #optional
							   );
    
    die ("Login to SMSC failed. Error nbr: $error_number, Error txt: $error_text\n") unless($acknowledge);
    
    ($acknowledge,$error_number,$error_text) = $emi->send_sms(
							      RECIPIENT      => $recipient, #mand.
							      MESSAGE_TEXT   => $text,      #opt
							      SENDER_TEXT    => $sender,    #opt
							      );
    
    die("Sending SMS failed. Error nbr: $error_number, Error txt: $error_text\n") unless($acknowledge);
    
    $emi->close_link();

=head1 CONSTRUCTOR

=over 4

=item new() 


The parameters may be given in arbitrary order.

C<SMSC_HOST=E<gt>> B<Mandatory>. The hostname B<or> ip-address of the SMSC.

C<SMSC_PORT=E<gt>> Optional. The TCP/IP port number of your SMSC. If omitted, port number 3024 will be used by default.

C<SMSC_HOST=E<gt>> Optional. Your ip appdress.

C<SRC_PORT=E<gt>> Optional. The TCP/IP source port number. You need to set it if you want to use auth. method based on AC.

C<SENDER_TEXT=E<gt>> Optional. The text that will appear in the receivers mobile phone, identifying you as a sender.
If omitted, the text 'Net::UCP' will be used by default.
You will probably want to provide a more meaningful text than that.

C<TIMEOUT=E<gt>> Optional.
A timeout, given in seconds, to wait for an acknowledgement of an SMS message transmission.
The value must be numeric, positive and within the range of B<0> (zero) to B<60>.
Failing this, or if the parameter is omitted, the default timeout of 15 seconds will be applied.
The value of this parameter will be used in all calls to the send_sms() method.
If the SMSC does not respond with an ACK or a NACK during this period,
the send_sms() method will return a NACK to the caller.
If the value of B<0> (zero) is given, no timeout will occur but the send_sms() method will wait B<indefinitively> for
a response. Note that the value given to the constructor can temporarily be overruled
in the call to the send_sms() method. As a final note, please remember that not all systems have implemented 
the C<alarm()> call, which is used to create a timeout.
On such systems, this module will still do a blocking call when reading data from the SMSC.

C<WARN=E<gt>> Optional. If this parameter is given and if it evaluates to I<true>,
then any warnings and errors will be written to C<STDERR>.
If omitted, or if the parameter evaluates to I<false>, then nothing is written to C<STDERR>.
It is B<strongly> recommended to turn on warnings during the development of an application using the Net::UCP 
module. When development is finished, the developer may chose to not require warnings but to handle all error 
situations completely in the main application by checking the return values from Net::UCP.

The constructor returns I<undef> if mandatory information is missing or invalid parameter values are detected.
In this case, the object is discarded (out of scope) by the Perl interpreter and you cannot call any methods 
on the object handle.

Any errors detected will be printed on C<STDERR> if the C<WARN=E<gt>> parameter evaluates to I<true>.

B<Test> the return value from the constructor!

=back

=head1 METHODS

=over 4

=item open_link()

Open the communication link to the SMSC.
In reality, this opens up a socket to the SMSC.
Be aware that this is B<not> an authenticated login but that the login() method must also be called 
before any SMS messagescan be sent to the SMSC if you will use an Authentication based on Login and Password.

open_link() is useful since the main application can verify that it's at all possible to communicate with the SMSC.
(Think: getting through a firewall.)

This method takes no parameters since it will use the data given in the constructor parameters.

Any errors detected will be printed on C<STDERR> if the C<WARN=E<gt>> parameter in the constructor evaluates to I<true>.

C<open_link()> returns B<true> on success and B<undef> in case something went wrong.

=item login()

You are able to use authentication based on Operation 60 of EMI Protocol.
Authenticates against the SMSC with the given SMSC-id and password.

B<or>

Directly through Operation 51.
Authenticates against the SMSC with the given SHORT_CODE (AC parameter).

If the open_link() method has not explicitly been called by the main application,
the login() method will do it before trying to authenticate with the SMSC.

The parameters may be given in arbitrary order.

C<SHORT_CODE=E<gt>> A valid Authentication Code Mandatory for Auth based on OP 51.

C<SMSC_ID=E<gt>> A string which should be a valid account ID at the SMSC.

C<SMSC_PW=E<gt>> A valid password at the SMSC.

Optional Parameters (Beta):

C<OTON=E<gt>> Originator Type of Number

it could be :
 
              1 = International Number (Starts with the country code) 
              2 = National Number (Default value is omitted)
              6 = Abbreviated Number (short number alias)              
              
C<ONPI=E<gt>> Originator Numbering Plan Id

it could be :

              1 = E.164 address (default value if omitted)
              3 = X.121 address
              5 = Private (TCP/IP address/abbreviated number address)

C<STYP=E<gt>> Subtype of Operation
     
              1 = add item to mo-list
              2 = remove item from mo-list
              3 = verify item mo-list
              4 = add item to mt-list
              5 = remove item from mt-list
              6 = verify item mt-list


C<VERS=E<gt>> (Test) default value is 0100

Any errors detected will be printed on C<STDERR> if the C<WARN=E<gt>> parameter in the constructor evaluates to I<true>.

B<Return values:>

In void context, login() will always return undef.
login() will return a I<true> value if you will use it only to set Authentication Code.

In scalar context, login() will return I<true> for success, I<false> for transmission failure
and I<undef> for application related errors.
Application related errors may be for instance that a mandatory parameter is missing.
All such errors will be printed on C<STDERR> if the C<WARN=E<gt>> parameter in the constructor evaluates to I<true>.

In array context, login() will return three values: C<($acknowledge, $error_number, $error_text);>
where C<$acknowledge> holds the same value as when the method is called in scalar context
(i.e. I<true>, I<false> or I<undef>),
C<$error_number> contains a numerical error code from the SMSC and
C<$error_text> contains a (relatively) explanatory text about the error.

Be aware that both C<$error_number> and C<$error_text> are provided in a response from the SMSC,
which means that the data quality of these entities depends on how well the SMSC has implemented the protocol.

If C<$acknowledge> is I<undef>, then C<$error_number> will be set to 0 (zero) and C<$error_text> will
contain a zero length string.

It is B<strongly recommended to call login() in an array context>, since this provides for an improved error handling
in the main application.

=item send_sms()

=item EXAMPLE 

    $binary_message  = "024A3A7125CD7DD1A1A5CD7DB1BDD994040045225D04985585D85D84106906985D84984A85585D85D84104D";
    $binary_message .= "04104D85D0690410A24824C49A6289B09D093126986A800";

    $emi->send_sms(
		   RECIPIENT      => '391232345678', 
		   MESSAGE_TEXT   => 'A Message', 
		   SENDER_TEXT    => 'Marco', 
		   FLASH          => 1,
		   UDH            => '050415811581',
		   MESSAGE_BYNARY => $binary_message,
		   TIMEOUT        => 5 
		   );

Submits the SMS message to the SMSC (Operation 51) and waits for an SMSC acknowledge.

The parameters may be given in arbitrary order.

C<RECIPIENT=E<gt>> B<Mandatory>.

This is the phone number of the recipient in international format with leading a '+' or '00'.

C<MESSAGE_TEXT=E<gt>> Optional. A text message to be transmitted.

It is accepted to transfer an empty message,
so if this parameter is missing, a space character will be sent (0x20).

C<FLASH=E<gt>> Optional. With this parameter you are able to send a Class 0 messages.

    
              1) Set to 1 Flash Message enabled     (Class 0)
              2) Other value Flash Message disabled (No Class)


C<MESSAGE_BINARY=E<gt>> Optional. A binary message to be transmitted.

C<UDH=E<gt>> Optional. User Data Header (you need to set UDH to use MESSAGE_BINARY).

First UDH Octet (length) will be internally calculated for this reason you need to omitted it.

C<SENDER_TEXT=E<gt>> Optional. The text that will appear in the receivers mobile phone, identifying you as a sender.

    In this version you are able to set:

              1) alphanumeric sender  ( Marco81        )
              2) numeric sender       ( 67166155111    )
              3) international format ( +3934112331112 ) 


This text will B<temporarily> replace the text given to the constructor.
If omitted, the text already given to the constructor will be used.

C<TIMEOUT=E<gt>> Optional.

A timeout, given in seconds, to wait for an acknowledgement of this SMS message transmission.
The value must be numeric, positive and within the range of B<0> (zero) to B<60>.
Failing this, or if the parameter is omitted,
the timeout established in the new() constructor will be applied.
If the SMSC does not respond with an ACK or a NACK during this period,
the send_sms() method will return a NACK to the caller.
If the value of B<0> (zero) is given, no timeout will occur but the send_sms() method will wait B<indefinitively> 
for a response. On a system that has not implemented the C<alarm()> call,
which is used to create a timeout,
this module will still do a blocking call when reading data from the SMSC.

Any errors detected will be printed on C<STDERR> if the C<WARN=E<gt>> parameter in the constructor evaluates to I<true>.

B<Return values:>

In void context, send_sms() will always return undef.

In scalar context, send_sms() will return I<true> for success, I<false> for transmission failure
and I<undef> for application related errors.
Application related errors may be for instance that a mandatory parameter is missing.
All such errors will be printed on C<STDERR> if the C<WARN=E<gt>> parameter in the constructor evaluates to I<true>.

In array context, send_sms() will return the three values: C<($acknowledge, $error_number, $error_text);>
where C<$acknowledge> holds the same value as when the method is called in scalar context
(i.e. I<true>, I<false> or I<undef>),
C<$error_number> contains a numerical error code from the SMSC and
C<$error_text> contains a (relatively) explanatory text about the error.

Be aware that both C<$error_number> and C<$error_text> are provided in a response from the SMSC,
which means that the data quality of these entities depends on how well the SMSC has implemented the protocol.

If C<$acknowledge> is I<undef>, then C<$error_number> will be set to 0 (zero) and C<$error_text> will
contain a zero length string.

It is B<strongly recommended to call send_sms() in array context>,
since this provides for an improved error handling in the main application.

B<Note!>
The fact that the message was successfully transmitted to the SMSC does B<not>
guarantee immediate delivery to the recipient or in fact any delivery at all.

B<About the timeout.>
Not all Perl systems are able to provide the timeout.
The timeout is internally implemented with the alarm() call.
If your system has implemented alarm(), then any timeout value provided will be honored.
If not, you may provide any value you wish for the timeout,
it will still be ignored and reading the ACK from the SMSC will block until everything is read.

If the SMSC fails to send you the full response B<your application will freeze>.
If your system B<does> implement alarm() but you do B<not> provide any timeout value,
then the default timeout of 15 seconds will be applied.

You may test this on your own system by executing the following on a command line:

C<perl -e "alarm(0)">

If the response is that alarm() is not implemented, then you're out of luck.
You can still use the module, but in case the SMSC doesn't respond as expected
your application will wait B<indefinitively>.

=item send_sms_multipart()

use it as send_sms() but you are able to send messages with text length bigger then 160 characters. 

    $emi->send_sms_multipart(
			     RECIPIENT      => '+393291212121',
			     MESSAGE_TEXT   => 'Message text with more then 160 characters',
			     SENDER_TEXT    => 'Marco',
			     );


( Don't use it in a production environment. Please test it and contact me for improvment and bugs )

=item logout()

=item close_link()

logout() is an alias for close_link().
Whichever method name is used, the B<very same code> will be executed.

What goes up, must also come down.
If the main application will continue working on other tasks once the SMS message was sent,
it is possible to explicitly close the communications link to the SMSC with this method.

If the Net::UCP object handle (returned by the new() method) goes out of scope in the main application,
the link will be implicitly closed and in this case it is not necessary to explicitly close the link.

In reality, this method closes the socket established with the SMSC and does some additional house-keeping.
Once the link is closed,
a new call to either open_link() or to login() will try to re-establish the communications link (socket) with the SMSC.

returns nothing (void)

=head1 RAW MODE

=head2 How to use it in "RAW MODE" 

 You can use Net::UCP in "raw mode" and it means you can bypass wrapper method like send_sms or login and other stuff 
 like that. You can manage your UCP string calling method make_message() and parse_message() (see below).
 
 For example : to authenticate your client you will be able to create your ucp 60 string calling make_message( op => 60 ... ) 
 and send it to smsc using transmit_msg() method. When SMSC will get back to you with an ucp response you will parse it 
 calling parse_message() which gets back a reference to an HASH with ucp protocol fields as keys and their contents as keys values. 

=head2 Parsing Message in Raw Mode

=item parse_message()

with this method you are able to parse any string get back from SMSC without know what kind 
of message SMSC has given to you.

it returns a ref to an hash that contains message parsed with message parameters as keys (LOWERCASE)
or undef on error. (it's a wrapper of parse_* functions reported below) 

Every hash reference get back from parse_message contains "my_checksum" key, its value is checksum 
recalculated from module, you can use this value to check checksum get back from ucp client. 

=item EXAMPLE 

     use Data::Dumper;

     my $smsc_message = "06/00043/R/01/A/01234567890:090196103258/4E";
    
     $ref_msg = $ucp->parse_message($smsc_message);

     print "This is a " . $ref_msg->{type} . " type\n";
     print "OT -> " . $ref_msg->{ot} . "\n\n"; 

     print "\nDUMP\n";
     print Dumper($ref_msg);

=head2 Making Message in Raw Mode

=item make_message()

with this method you are able to make UCP strings (it's a wrapper of functions below)
it returns a scalar value with UCP string or undef on error.

=item EXAMPLE

#we are making a ucp 01 operation type "O".

    my $ucp_string = $upc->make_message(
                                        op => 01,
                                        operation => 1,
                                        adc  => '01234567890',
                                        oadc => '09876543210',
                                        ac   => '',
                                        mt   => 3,
                                        amsg => 'Short Message'
                                       );

    
#we are making a ucp 01 operation type "R". (result)

    my $ucp_string = $ucp->make_message(
                                        op => 01,
                                        result => 1,
                                        trn    => '47',
                                        nack   => 'N',
                                        ec     => '02',
                                        sm     => 'Syntax Error
                                        );


#op 51 submit short message 

     $ucp_string = $ucp->make_message(
                                      op => '51',
                                      operation => 1,
                                      adc   => '00393311212',
                                      oadc  => 'ALPHA@NUM',
                                      mt   => 3,
                                      amsg => 'Short Message for NEMUX',
                                      mcls => 1,
                                      otoa => 5039,
                                      );

     #you get back something like that :
     #02/00130/O/51/00393311212/10412614190438AB4D/////////////////3//
     #53686F7274204D65737361676520666F72204E454D5558////1////5039/////C8

     #ready for being sent through transmit_msg() to your SMSC


=head2 All Parsing Functions Name

For all operations exist a method parse_[OP_NN] 
       
      Operation 01 -> parse_01();
      Operation 02 -> parse_02();
      Operation 03 -> parse_03();
      Operation 30 -> parse_30();
      Operation 31 -> parse_31();
      Operation 51 -> parse_51();
      Operation 52 -> parse_52();
      Operation 53 -> parse_53();
      Operation 54 -> parse_54();
      Operation 55 -> parse_55();
      Operation 56 -> parse_56();
      Operation 57 -> parse_57();
      Operation 58 -> parse_58();
      Operation 60 -> parse_60();
      Operation 61 -> parse_61();      
     
every functions return a reference to a hash (as seen for parse_message())
or undef on error.

=head2 All Making Functions Name

For all operations exist a method make_[OP_NN] 

      Operation 01 -> make_01();
      Operation 02 -> make_02();
      Operation 03 -> make_03();
      Operation 30 -> make_30();
      Operation 31 -> make_31();
      Operation 51 -> make_51();
      Operation 52 -> make_52();
      Operation 53 -> make_53();
      Operation 54 -> make_54();
      Operation 55 -> make_55();
      Operation 56 -> make_56();
      Operation 57 -> make_57();
      Operation 58 -> make_58();
      Operation 60 -> make_60();
      Operation 61 -> make_61();

every functions return a scalar value with message string or undef on error. 
For every function is possible to set as parameters in input the same name of operation's parameters.

=item EXAMPLE 

#make operation
    
    $ucp_string = $ucp->make_01(
				operation => 1,
				adc  => '01234567890',
				oadc => '09876543210',
				ac   => '',
				mt   => 3,
				amsg => 'Short Message'
				);

    if ( defined($ucp_string) ) { 
	
	($ack, $error_code, $error_text) = $ucp->transmit_msg( $ucp_string, 5, 1 ); 
    
    }

SMSC side

    $ucp->make_01(
		  result => 1,
		  trn    => '07',
		  ack    => 'A',
		  sm     => '01234567890:090196103258'
		  );

or... nack
    
    $ucp->make_01(
	          result => 1,
		  trn    => '47',
		  nack   => 'N',
		  ec     => '02',     
		  sm     => 'Syntax Error'
		  );

another example.. op 02

    $ucp_string = $ucp->make_02(
				operation => 1,
				npl   => '3',
				rads  => '003932412341/00393291111/00393451231',
				oadc => '123',
				ac   => '',
				mt   => 3,
				amsg => 'Short Message to 3 subscribers'
				);

=head2 Other Methods

=item remove_ucp_enclosure()

this method REMOVE STX and ETX characters from string received in input and return nothing. 

=item EXAMPLE 
    
    $emi_obj->remove_ucp_enclosure(\$ucp_message);

=item add_ucp_enclosure()

this method ADD STX and ETX characters to string received in input and return nothing. 

=item EXAMPLE 
    
    $emi_obj->add_ucp_enclosure(\$ucp_message);

=item wait_in_loop() 

It needs three parameters (timeout, action, clear) clear is a boolean value, when clear is equal "1",
method removes characters STX and ETX from all messages received.

With wait_in_loop() method you are able to get back 
every messages from SMSC.

First parameter is timeout in second.
Second parameter is a ref to a subroutine. This subroutine will be call when timeout will be caught up. 

Second patameter is mandatory and it has no sense if timeout is undefined or less or equal 0. 
If it isn't set up, wait_in_loop will die leaving a message on standard output when timeout will be caught up. 

it will get back a scalar value with a message string or undef value.

=item EXAMPLE

    my $message;

    sub make_something {
	print "Timeout reached...";
	exit 0;
    }

    $message = $emi->wait_in_loop(
		                  timeout => 30,
		                  action => \&make_something
		                 );

    if (defined($message)) {
        print "I Get Back From SMSC ... " . $message . "\n";
    } else {
        print "No Message from SMSC\n";
    }

without timeout, it waits "in loop" until something get back.

    $message = $emi->wait_in_loop();

with clear equal 1 it removes STX and ETX characters.

    $message = $emi->wait_in_loop(clear => 1);

=item transmit_msg()

with this method you are able to transmit messages to the SMSC directly, it will get back SMSC
response if you need it.

Parameters are 3 : ucp message, timeout in second, boolean value as flag for response.

Retrun value are 3 (in array context) = ack, error_code, error_text. 
If you don't need response these 3 values will be undef.
In a void context, get beck only ack or nack, or undef on transmission problem. 

You don't need response in some cases, 

    1) you are sending a RESPONSE (Operation "R")
    2) [for example] you are receving messages from SMSC through a child uses wait_in_loop 
       (it could be an idea)
    
=item EXAMPLE 

    $timeout = 10; #ten seconds timeout
    $i_need_response = 1;
 
    ($ack, $error_code, $error_text) = $ucp->transmit_msg($ucp_message, $timeout, $i_need_response);

=head1 SMSCfAKE 

=head2 Description 

This module version support second release of SMSCfAKE, with this feature you are able to start a simple smsc 
that receive messages from any client. It parses and prints out UCP messages. 
Using C<action> parameter is possible to add a call back that SMSCfAKE will call when it will receive an UCP 
string. In order to improve the possibility to use it as an application tester i've added another parameter :
C<sending> to add another call back that it will call after first call back C<action>

Simple Interaction Diagram :

         Client                                  SMSCfAKE 
           |             send UCP string             |  
           | --------------------------------------> |
           |   send "action" call back return value  |        
           | <-------------------------------------- |
           |   send "sending" call back return value |
           | <-------------------------------------- |
           |                                         |
           |                                         |
           |                                         |

Example :

   1) Client send    : OP 51 type O (submit sms)
   2) SMSCfAKE send  : OP 51 type R (submit sms response)
   3) SMSCfAKE send  : OP 53 type O (delivery notification)

=head2 How-to create a simple Fake SMSC

Is possible to create a simple Fake SMSC through method reported below. 

=item create_smsc_fake()

It accepts 8 optional parameters :  host, port, listen, output, action, sending, reading_mode, max_len

    1) host : set smsc address (default are 127.0.0.1)
    2) port : set smsc port (default are 6666)
    3) listen : max listen (default 5)
    4) output : set to 1, if you want to see on standard output string UCP got back from client
    5) action : your internal subroutine reference. It must to accept a scalar value as input, its content 
                will be UCP String got back from client. 
                It could be get back a UCP string response into a scalar value. This value will be printed 
                get back to the client.
                Without this parameter smsc fake parse UCP string and will print it on stdout.
    6) sending      : (another internal subroutine useful to send another UCP string to client)
    7) reading_mode : it can be equal to 0 to receive UCP string with new line at the end 
                      it can be equal to 1 to receive UCP string without new line at the end
    8) max_len      : max byte length of ucp string receive in reading_mode 1 default value 1024 (1Kb)

=item EXAMPLE 

   $ucp = Net::UCP->new(FAKE => 1);
   $ucp->create_fake_smsc();

   $ucp = Net::UCP->new(FAKE => 1);

   sub code_ref($) {
       my $ucp_string = shift;
    
       $ucp->parse_message($ucp_string);

       return $ucp_string_respone;
   }
   
   $ucp->create_fake_smsc(
			  host   => 10.10.10.21,
			  port   => 1234,
			  action => \&code_ref
			  );

   $ucp->create_fake_smsc(
			  host         => 10.10.10.21,
			  port         => 5000,
			  listen       => 10,
			  output       => 1,
			  reading_mode => 1,
			  max_len      => 2048,
			  action       => \&ucp_response_call_back,
			  sending      => \&delivery_notification_call_back
			  );

   
=head1 DATA CODING

SMSC default alphabet is GSM 03.38 ( ftp://ftp.unicode.org/Public/MAPPINGS/ETSI/GSM0338.TXT )

the easiest way to make this conversion is to use Encode module and its encode method

=item Encoding Example 

  use Encode;
  
  #doing that UCP module will do right 7bit conversion and the result will be : 10412614190438AB4D 
  my $sender = encode('gsm0338', 'ALPHA@NUM');  
  my $amsg_example = encode('gsm0338', 'Short Message for NEMUX by Net::UCP');

  #ucp string will be : 
  #01/00154/O/51/00393201001/10412614190438AB4D/////////////////3//
  #53686F7274204D65737361676520666F72204E454D5558206279204E65743A3A554350\////1////5039/////C7

  $ucp_string = $emi->make_message(
                                   op => '51',
                                   operation => 1,
                                   adc   => '00393201001',
                                   oadc  => $sender,
                                   mt   => 3,
                                   amsg => $amsg_example,
                                   mcls => 1,
                                   otoa => 5039,
                                 );
		
   if ( defined($ucp_string) ) {
       ($acknowledge, $error_number, $error_text) = $emi->transmit_msg( $ucp_string, 10, 1 );
        print $error_text ."\n";
   } else {
       die "Error while making UCP String OP 51\n";
   }
		
   $emi->close_link();

=back

=head1 SEE ALSO

C<IO::Socket>, C<IO::Select>, C<Encode>, C<Net::UCP::Common>, C<Net::UCP::IntTimeout>, C<Net::UCP::TransactionManager>

=head1 AUTHOR

Marco Romano, E<lt>nemux@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2008 by Marco Romano

  This library is free software; you can redistribute it and/or modify
  it under the same terms as Perl itself, either Perl version 5.8.4 or,
  at your option, any later version of Perl 5 you may have available.

=cut

sub AUTOLOAD {
    my($method, $class);

    $method = $AUTOLOAD;
    $method =~ s/.*:://;
    $class = ref($_[0]) || $_[0];

    croak "$class Method=$method";
}
