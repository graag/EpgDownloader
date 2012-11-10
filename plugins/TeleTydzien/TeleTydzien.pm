package TeleTydzien;
use constant PLUGIN_NAME => TeleTydzien;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use Encode;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use DateTime::Format::Strptime;
use plugins::TeleTydzien::include::ConfigTeleTydzien;
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
    $self->{'plugin_config'} = ConfigTeleTydzien->new($config_file);
    $self->{'url'}           = 'http://www.teletydzien.pl/program-tv';
    $self->{'channels_subpage'}  = 'lista-stacji';
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

    for(my $i=0; $i < $days; $i++) {
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

    my $dateString  = time2str("%Y-%m-%d", time+(60*60*24*($day)));
    my $channel_uri = $self->findChannelUriByNameAndDate($name, $day);

    if (!$channel_uri) {
        $self->log(PLUGIN_NAME, "Could not find schedule for " . $name);

        return $events;
    }

    $browser->get($channel_uri);

    my $content = $browser->content();
    # $content = encode('utf8', $content); 

    while($content =~ m/.*?<div class="emission-time/sm) {
        # somehow this is faster than the same expression in while loop
        $content =~ s/.*?<div class="item-wrap">\s*<div class="emission-time">\s*(.*?)\s*<\/div>.*?<a href="(.*?)" class="title" title="(.*?)">(.*?)<\/a>(.*?)<div class="clear">.*?<\/div>(.*)/$6/sm;
        my $hour         = $1;
        my $length       = 5;
        my $title        = $self->clean($3);
        my $title2       = $self->clean($4);
        my $episode      = '';
        my $season       = '';
        my $category     = '';
        my $year         = '';
        my $country      = '';
        my $longUrl      = $self->{'url'} . '/' . $2;
        my $description  = '';
        my $description2 = '';
        my $info = $5;
        if($info =~ /<span class="part">odcinek:\s*(.*?)<\/span>/) {
            $episode = $1;
        }
        if($info =~ /<span class="cat tv-type.*?">(.*?)<\/span>/) {
            $category = $1;
        }
        if($title2 =~ /$title:\s*(.*)/) {
            $title2 = $1;
        } else {
            $title2 = '';
        }

        $length =~ s/\D//g;
        $title =~ s/_/-/g if $title;

        return $events if $hour !~ s/.*([0-9]{1,2}:[0-9]{2}).*/$1/sm;

        #get full description if available and needed (follows another link so it costs time)
        if($self->{'plugin_config'}->get('FULL_DESCRIPTION') == 1 && $longUrl !~ //) {
            $browser->get($longUrl);
            my $tmp = $browser->content();
            $tmp =~ s/.*<div class="content">(.*?)<div class="print-indicator">(.*)/$1/sm;
            my $tmp2 = $2;
            $tmp =~ /.*<div class="additional-info">.*?<ul>(.*?)<\/ul>.*?<ul>(.*?)<\/ul>.*?<ul>(.*?)<\/ul>(.*?)<div class="clear"><\/div>/sm;

            my $age_block = $1;
            my $audio_block = $2;
            my $data_block = $3;
            my $aux_data_block = $4;

            if($data_block =~ s/<span class="item">(\d+)\s*min<\/span>//sm) {
                $length = $1;
            }
            if($data_block =~ s/<span class="item">(.*?)\s*([\d\-]+)<\/span>//sm) {
                $country = $1;
                $year = $2;
                $year =~ s/(\d{4}).*/$1/;
            }

            if($aux_data_block =~ /<span class="desc">Sezon:<\/span>\s*(.*?)\s*<\/span>/sm) {
                $season = $1;
            }

            if($tmp =~ /<strong class="type">\s*(.*?):\s*<\/strong>\s*(.*?)\s*<\/div>/) {
                $category = $1;
                $description = $2;
            }
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

        if($episode) {
            if($episode =~ /(\d+)\/(\d+)/) {
                $episode = $1-1 . '/' . $2;
            } elsif ($episode =~ /(\d+)-ost\./) {
                $episode = $1-1 . '/' . $1;
            } else {
                print $episode, "\n" if $episode !~ /^\d+$/;
                $episode -= 1;
            }
        }

        if($season) {
            $episode = $season-1 . ".$episode.0"
        } elsif($episode ne '') {
            $episode = "0.$episode.0"
        }

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
        $event->set('country', $country);

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
    $text =~ s/&quot;/"/smg;
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

    $content =~ s/.*<div class="list">\s*<div class="channel-list-item">(.*?)<div class="channel-list-footer">/$1/sm;

    while($content =~ s/.*?<a href="(.*?)"\s+title="(.*?)">.*?<\/a>(.*)/$3/sm) {
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
    my $day = shift;

    my $channel_uri = $self->findChannelUriByName($name);
    $channel_uri .= ",o," . $day;

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
