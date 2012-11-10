package ConfigGazeta;
use strict;
use include::Config;
@ConfigGazeta::ISA = qw(Config);

=pod

=head1 NAME

ConfigGazeta - represents the Gazeta plugin configuration

=head1 SYNOPSIS

 use include::ConfigGazeta;
 $config = ConfigGazeta->new('fileName.xml');

=head1 DESCRIPTION

Constructor runs the SUPER::new method with 'Gazeta' as second argument to get the Gazeta section config. Defaults method sets the default value. It also describes available options in the Gazeta section.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Konrad Klimaszewski.

Date: july 2012

=cut

sub new {
	my $class = shift;
	my $fileName = shift;
	
	my $self = $class->SUPER::new($fileName,'Gazeta');

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
