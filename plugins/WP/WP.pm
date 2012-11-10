package WP;
use constant PLUGIN_NAME => WP;
use constant BROWSER => 'Opera/7.54 (X11; Linux i686; U)';
use Encode;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use DateTime::Format::Strptime;
use plugins::WP::include::ConfigWP;
use Data::Dumper;
use utf8;
use strict;

=pod

=head1 NAME

WP - EpgDownloader plugin

=head1 DESCRIPTION

This plugin can import tv schedule from http://tv.wp.pl website.

=head1 COPYRIGHT

This software is released under the GNU GPL version 2.

Author: Jakub Zalas <jakub@zalas.net>.

Date: march, april 2006, october 2008, april 2010

=cut

sub new {
    my $class = shift;
    my $config = shift;
    my $config_file = shift;

    my $self = {};
    $self->{'config'}        = $config;
    $self->{'plugin_config'} = ConfigWP->new($config_file);
    $self->{'channel_config'} = { "stop_fix" => 1 };
    $self->{'url'}           = 'http://tv.wp.pl';
    # $self->{'url'}           = 'file:///home/konrad/Temp/EpgDownloader/data/WP'; 
    $self->{'channels_subpage'}  = 'kanaly-lista.html';
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
        $self->{'channel_config'}->{'stop_fix'} = $channels->{$name}->{'stop_fix'};
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

    # $self->log(PLUGIN_NAME, "getChannelEventsForDay: content obtained"); #Debug 
    # print Dumper($content); #Debug 

    while($content =~ m/.*?<td class="tvTime">/sm) {
        # somehow this is faster than the same expression in while loop
        $content =~ s#.*?<td class="tvTime">.*?<a href="?pr_tele_id,(.*?),mprogram.html"?><div class="tvHour">(.*?)<\/div>.*?</a>.*?<div class="tvProg">(.*?)</div><div class="tvDesc"><span>(.*?)</span></div>.*?</tr>(.*?)#$5#sm;
        # print Dumper($content); #Debug 
        my $hour    = $2;
        my $length  = 1;
        my $title   = $3;
        my $title2  = '';
        my $episode = '';
        my $category= '';
        my $country = '';
        my $year = '';
        my $longUrl = $self->{'url'} . "/prid,$1,opis.html";
        my $description  = $4;
        my $description2 = '';
        my $director = '';
        my @cast = ();

        $description =~ s/.*<span>(.*?)/$1/sm;

        $title =~ s/_/-/g if $title;

        return $events if $hour !~ /([0-9]{1,2}:[0-9]{2})/;

        #get full description if available and needed (follows another link so it costs time)
        if($self->{'plugin_config'}->get('FULL_DESCRIPTION') == 1 && $longUrl !~ //) {
            $browser->get($longUrl);
            my $tmp = $browser->content();
            if($tmp =~ m%.*?<div id="programDetails">.*?<h1>(.*?)(:\s*(.*?))?(<span class="age.*?>.*?</span>.*?)?</h1>.*?<span class="pdData1">\s*(odc. (\d+))?\s*(<span>\(sezon (\d+)\)</span>)?</span>.*?<span class="pdData2">\s*(\((.*?)\))?\s*</span>.*?<span class="pdData3">\s*(\d+) min, (.*?)\s*(,(.*?))? ([\d-]+)?\s*(\|.*?)?</span>.*?<span class="txt">\s*(<p>(.*?)</p>)?.*?<div class="data">\s*(<p><span>reżyseria: </span>(.*?)</p>)?\s*(<p><span>wykonawcy: </span>(.*?)</p>)?.*?<div id="stgFooter">%sm) {
                # print "1 Tit: $1\n"; 
                # print "2 Sub: $2\n"; 
                # print "3 Sub: $3\n"; 
                # print "4 Age: $4\n"; 
                # print "5 D1: $5\n"; 
                # print "6 Ep: $6\n"; 
                # print "7 Se: $7\n"; 
                # print "8 Se: $8\n"; 
                # print "9 D2: $9\n"; 
                # print "10 Orig: $10\n"; 
                # print "11 Len: $11\n"; 
                # print "12 Type: $12\n"; 
                # print "13 D3: $13\n"; 
                # print "14 Country: $14\n"; 
                # print "15 Year: $15\n"; 
                # print "16 After Year: $16\n"; 
                # print "17 Desc: $17\n"; 
                # print "18 Desc: $18\n"; 
                # print "19 Dir: $19\n"; 
                # print "20 Dir: $20\n"; 
                # print "21 Cast: $21\n"; 
                # print "22 Cast: $22\n"; 
                $title = $1;
                $title2 = $3 if $3;
                $episode = $6-1 if $6;
                my $season = $8-1 if $8;
                if($season) {
                    $episode = "$season.$episode.0"
                } elsif($episode ne '') {
                    $episode = "0.$episode.0"
                }
                $length = $11;
                $category = $12;
                $country = $14 if $14;
                $year = $15 if $15;
                $description = $18 if $18;
                $director = $20 if $20;
                my $actors = $22 if $22;
                if($actors) {
                    $actors = $self->clean($actors);
                    my $buffer = $actors;
                    $buffer =~ s/\(.*?\)//g;
                    @cast = split(/,/, $buffer);
                    for my $actor (@cast) {
                        $actor = $self->clean($actor);
                    }
                }
                $description2 = "($year)" if $year;
                $description2 = "$country $description2" if $country;
                $description2 .= ", reżyseria: $director" if $director;
                $description2 .= ", obsada: $actors" if $actors;
            }

            $self->log("", "", ".");
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
        $event->set('title', $self->clean($title));
        $event->set('title2', $self->clean($title2));
        $event->set('description', $self->clean($description));
        $event->set('description2', $self->clean($description2));
        $event->set('category', $category);
        $event->set('episode', $episode);
        $event->set('year', $year);
        $event->set('country', $self->clean($country));
        $event->set('length', $length);
        $event->set('director', $self->clean($director));
        $event->set('cast', \@cast);

        #set the previous event stop timestamp
        if($self->{'channel_config'}->{'stop_fix'}) {
            my $previous = $#{$events};
            $events->[$previous]->set('stop',$event->{'start'}) if $previous > -1;
        }

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
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

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
    # $self->log(PLUGIN_NAME, "parseChannelsFromWebsite"); # Debug

    my $channels = {}; 
    my $browser  = WWW::Mechanize->new( 'agent' => BROWSER );

    $browser->get($self->{'url'}.'/'.$self->{'channels_subpage'});

    my $content = encode('utf8', $browser->content());

    # print Dumper($content); # Debug

    while ($content =~ s/.*?<a href="(.*?)" data-stid="(\d+)">(.*?)<\/a>//sm) {
        my $url   = $self->{'url'} . "/id," . $2 . ",mprogramy.html";
        my $name  = $3;

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
    $channel_uri =~ s/,mprogramy/,d,$date,mprogramy/;

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
