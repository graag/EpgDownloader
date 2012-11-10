package ConfigTeleTydzien;
use strict;
use include::Config;
@ConfigTeleTydzien::ISA = qw(Config);

=pod

=head1 NAME

ConfigTeleTydzien - represents the TeleTydzien plugin configuration

=head1 SYNOPSIS

 use include::ConfigTeleTydzien;
 $config = ConfigTeleTydzien->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'TeleTydzien' as second argument to get the TeleTydzien section config. Defaults method sets the default value. It also describes available options in the TeleTydzien section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Konrad Klimaszewski.

Date: july 2012

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'TeleTydzien');

	bless( $self, $class );
	return $self;
}

sub defaults {
	return {
		'DAYS'			=> '1',
		'FULL_DESCRIPTION' 	=> '0'
	};
}


1;
