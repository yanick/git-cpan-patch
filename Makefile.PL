use lib 'inc';
use ExtUtils::AutoInstall(
			  -core  => [ 'Carp'         => '0.00',
				      'IO::Socket'   => '0.00', 
				      'IO::Select'   => '0.00', 
				      'Time::HiRes'  => '0.00',
				      'Net::UCP::Common'             => '0.05',
				      'Net::UCP::IntTimeout'         => '0.05',
				      'Net::UCP::TransactionManager' => '0.02',]
			  );
WriteMakefile(
	      NAME              => 'Net::UCP',
	      VERSION_FROM      => 'lib/Net/UCP.pm', 
	      PREREQ_PM          => { 
		    Net::UCP::Common             => 0.05,
		    Net::UCP::IntTimeout         => 0.05,
		    Net::UCP::TransactionManager => 0.02
		},
	      ($] >= 5.006 ?     
	       (ABSTRACT_FROM  => 'lib/Net/UCP.pm', 
		AUTHOR         => 'Marco Romano <nemux@cpan.org>') : ()),
	      );
