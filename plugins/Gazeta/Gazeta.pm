package Gazeta;
use constant PLUGIN_NAME => Gazeta;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use Encode;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use DateTime::Format::Strptime;
use plugins::Gazeta::include::ConfigGazeta;
use strict;

=pod

=head1 NAME

Gazera - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://tv.gazeta.pl website.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Konrad Klimaszewski

Date: july 2012

=cut

sub new {
    my $class = shift;
    my $config = shift;
    my $config_file = shift;

    my $self = {};
    $self->{'config'}        = $config;
    $self->{'plugin_config'} = ConfigGazeta->new($config_file);
    $self->{'url'}           = 'http://tv.gazeta.pl';
    $self->{'channels_subpage'}  = 'program_tv/0,110740,8750044.html';
    $self->{'channels'}      = {};

    bless( $self, $class );

    return $self;
}

#gets channel names list and returns events list
sub get {
    my $self = shift;
    my $channels = shift;

    foreach my $name (keys(%{$channels})) {
        $self->log(PLUGIN_NAME, "Downloading schedule for " . $name, " ");
        $channels->{$name} = $self->getChannelEvents($name);
        $self->log("", "");
    }

    return $channels;
}

#gets channels list with each one's events and exports it
sub save {
    my $self = shift;
    my $events = shift;

    $self->log(PLUGIN_NAME, "This plugin doesn't support export.");
}

sub getChannelEvents {
    my $self = shift;
    my $name = shift;

    my $events = (); 
    my $days   = $self->{'plugin_config'}->get('DAYS');

    for(my $i=1; $i <= $days; $i++) {
        my $dayEvents = $self->getChannelEventsForDay($name, $i);
        if ($dayEvents) {
            push @{$events}, @{$dayEvents};
        } else {
            last;
        }
    }

    return $events;
}

sub getChannelEventsForDay {
    my $self = shift;
    my $name = shift;
    my $day  = shift;

    my $events = (); 
    my $browser = WWW::Mechanize->new( 'agent' => BROWSER );

    my $dateString  = time2str("%Y-%m-%d", time+(60*60*24*($day-1)));
    my $channel_uri = $self->findChannelUriByNameAndDate($name, $dateString);

    if (!$channel_uri) {
        $self->log(PLUGIN_NAME, "Could not find schedule for " . $name);

        return $events;
    }

    $browser->get($channel_uri);

    my $content = $browser->content();
    # $content = encode('utf8', $content); 

    while($content =~ m/.*?<div class="time/sm) {
        # somehow this is faster than the same expression in while loop
        # $content =~ s/.*?<div class="time.*?">(.*?)<\/div>.*?<a href="(.*?)">(.*?)<\/a>.*?<p>(.*?)<\/p>.*?<p>(.*?)<\/div><div class="duration">(.*?)<\/div>(.*)/$7/sm; 
        $content =~ s/.*?<div class="time.*?">(.*?)<\/div>.*?<a href="(.*?)">(.*?)<\/a>.*?<p>(.*?)<\/p>.*?<p>(.*?)<\/div>.*?<div class="duration">(.*?)<\/div>.*?<div class="runtime">(.*?)<\/div>(.*)/$8/sm;
        print $1, ";", $2, ";", $3, ";", $4, ";", $5, ";", $6, ";", $7, "\n";
        my $hour         = $1;
        my $length       = $7;
        my $show_length  = $6;
        my $title        = $3;
        my $title2       = '';
        my $episode      = '';
        my $category     = $4;
        my $year         = '';
        my $longUrl      = $2;
        my $description  = $5;
        my $description2 = '';
        $length =~ s/\D//g;

        $title =~ s/_/-/g if $title;

        return $events if $hour !~ /([0-9]{1,2}:[0-9]{2})/;

        #get full description if available and needed (follows another link so it costs time)
        if($self->{'plugin_config'}->get('FULL_DESCRIPTION') == 1 && $longUrl !~ //) {
            $browser->get($self->{'url'}.'/'.$longUrl);
            my $tmp = $browser->content();
            if($tmp =~ /.*?<h1>.*<br\s*\/><small>(.*?)<\/small>.*<\/h1>/sm) {
                $title2 = $1;
            } elsif ($tmp =~ /.*?<h1>.*<small>(.*?)<\/small>.*<\/h1>/sm) {
                $title2 = "($1)" if $1;
            }
            $title2 =~ s/_/-/g if $title2;
            my $info;
            my $desc;
            if($tmp =~ /.*?<div class="opis">(.*?)<\/div>/sm) {
                $info = $1;
                $episode = $1-1 if $info =~/.*?<strong>\s*odc\.\s*(\d+)/sm;
                my $season = $1-1 if $info =~/.*?<strong>\s*odc\..*\(sezon\s*(\d+)\)/sm;
                if($season) {
                    $episode = "$season.$episode.0"
                } elsif($episode ne '') {
                    $episode = "0.$episode.0"
                }
            }
            if($tmp =~ /.*?<div class="opis">.*?<br\s*\/>(.*?)\|(.*?)<\/div>.*?<iframe.*?>.*?<p>(.*?)<\/p>/sm) {
                my $type = $1;
                my $len = $2;
                my $desc = $3;
                $len =~ s/<br(.*?)>/\n/smgi;
                $len =~ s/^\s+//sm;
                $len =~ s/\s+$//sm;
                $desc =~ s/^\s+//sm;
                $desc =~ s/\s+$//sm;
                $description  = "$len; $desc";
                if($type =~ /(.*?)(\d\d\d\d)\s*/sm) {
                    $type = $1;
                    $year = $2;
                }
                if($type =~ /\s*(.*?)\s*\-\s*(.*)\s*/sm) {
                    $category = $1;
                    $description = $2." | ".$description;
                } else {
                    $category=$type;
                }
            }
            $description2 = $1 if $tmp =~ /.*?<p class="ekipa">(.*?)<\/p>.*/sm;
            $category =~ s/^\s+//sm;
            $category =~ s/\s+$//sm;
            $description =~ s/^\s+//sm;
            $description2 =~ s/^\s+//sm;
            $description2 =~ s/\s+$//sm;
            $description2 =~ s/wykonawcy:/; wykonawcy:/sm if $description2;
        }

        #convert hour to unix timestamp, if it's after midnight, change base date string
        $dateString = time2str("%Y-%m-%d",time+(60*60*24*($day))) if $hour =~ /0[0-3]{1}:[0-9]{2}/;
        $hour = str2time($dateString." ".$hour);
        # print "STD: ", $hour2, "\n"; 
        # my $strpt = new DateTime::Format::Strptime( 
            # pattern => "%Y-%m-%d %H:%M", 
            # locale => 'pl_PL', 
            # time_zone => "Europe/Warsaw"); 
        # my $dateObj = $strpt->parse_datetime($dateString." ".$hour); 
        # $dateObj->set_time_zone("GMT"); 
        # $hour = $dateObj->epoch(); 
        # print "NEW: ", $hour, "\n"; 
        # print "DIF: ", ($hour2-$hour)/3600, "\n"; 

        #create event
        my $event = Event->new();
        $event->set('start', $hour);
        $event->set('stop', $hour+$length*60);
        $event->set('title', $title);
        $event->set('title2', $title2);
        $event->set('description', $self->clean($description));
        $event->set('description2', $self->clean($description2));
        $event->set('category', $category);
        $event->set('episode', $episode);
        $event->set('year', $year);

        #set the previous event stop timestamp
        my $previous = $#{$events};
        $events->[$previous]->set('stop',$event->{'start'}) if $previous > -1;

        #put event to the events array
        push @{$events}, $event;
    }

    $self->log("", "#", " ");

    return $events;
}

sub clean {
    my $self = shift;
    my $text = shift;

    $text =~ s/&nbsp;/ /smg;
    $text =~ s/<br(.*?)>/\n/smgi;
    $text =~ s/<(\/?)(.*?)>//smg;
    $text =~ s/\s+/ /g;

    return $text;
}

sub getChannels {
    my $self = shift;

    if (keys %{$self->{'channels'}} < 1) {
        $self->{'channels'} = $self->parseChannelsFromWebsite();
    }

    return $self->{'channels'};
}

sub parseChannelsFromWebsite {
    my $self = shift;

    my $channels = {}; 
    my $browser  = WWW::Mechanize->new( 'agent' => BROWSER );

    $browser->get($self->{'url'}.'/'.$self->{'channels_subpage'});

    my $content = encode('utf8', $browser->content());

    $content =~ s/.*<div class="mod mod_favorite_channels_index">(.*?)<\/div> <!-- \.mod_favorites_channels_index -->.*/$1/sm;

    while($content =~ s/.*?<a href="(.*?)"><span>(.*?)<\/span><\/a>(.*)/$3/sm) {
        my $url   = $self->{'url'} . '/' . $1;
        my $name  = $2;

        $channels->{$name} = $url;
    }

    return $channels;
}

sub findChannelUriByName {
    my $self = shift;
    my $name = shift;

    $name = encode('utf8', $name);

    my $channels = $self->getChannels();

    return $channels->{$name} || '';
}

sub findChannelUriByNameAndDate {
    my $self = shift;
    my $name = shift;
    my $date = shift;

    my $channel_uri = $self->findChannelUriByName($name);
    $channel_uri =~ s/,,,,,/,,,$date,0,/;

    return $channel_uri;
}

sub log {
    my $self = shift;
    my $sender = shift;
    my $message = shift;
    my $newLine = shift || "\n";

    Misc::pluginMessage($sender, $message, $newLine);
}

1;
