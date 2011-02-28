#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  poe-server.pl
#
#        USAGE:  ./poe-server.pl
#
#  DESCRIPTION:
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Gavin Mogan (Gavin), <gavin@kodekoan.com>
#      COMPANY:  KodeKoan
#      VERSION:  1.0
#      CREATED:  27/02/2011 11:49:48 PST
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use lib qw(lib);

# A simple POP3 Server that demonstrates functionality
use POE;
use POE::Component::Server::POP3;
use Plugin;
use Games::Lacuna::POP3::Plugin::TOP;
use Data::Dumper;

use POE::Component::Server::POP3;

my $debug = 0;
if ($debug)
{
    {
        my $func = \&POE::Component::Server::POP3::_conn_input;
        *POE::Component::Server::POP3::_conn_input = sub {
            my ($kernel,$self,$input,$id) = @_[KERNEL,OBJECT,ARG0,ARG1];
            print STDERR "<= $id> $input\n";
            return $func->(@_);
        };
    }
    {
        my $func = \&POE::Component::Server::POP3::_send_to_client;
        *POE::Component::Server::POP3::_send_to_client = sub {
            my ($kernel,$self,$id,$output) = @_[KERNEL,OBJECT,ARG0..ARG1];
            print STDERR "=> $id> $output\n";
            #$output = "\r\n" if !$output;
            #$output .= "\r\n";
            return $func->(@_);
        };
    }
}

use JSON::Any;
my $j = JSON::Any->new(utf8=>1);

our $json = qq#
{"jsonrpc":"2.0","id":53,"result":{"messages":[{"date":"27 02 2011 17:32:18 +0000","subject":"Pollution Causing Outrage","body_preview":"The citizens of {Planet 1","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","id":"1616502","has_replied":"0"},{"date":"27 02 2011 16:37:04 +0000","subject":"Probe Detected!","body_preview":"Our probe in the {Starmap 95 1","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1615620","has_replied":"0"},{"date":"27 02 2011 13:36:09 +0000","subject":"Re: Probe Destructions","body_preview":"Sorry for any loss of your pro","to_id":"583","tags":["Correspondence"],"from_id":"5806","to":"halkeye","from":"Galaga","has_read":"1","id":"1612552","has_replied":"0"},{"date":"27 02 2011 13:25:52 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612170","has_replied":"0"},{"date":"27 02 2011 13:25:52 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612169","has_replied":"0"},{"date":"27 02 2011 13:25:51 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612168","has_replied":"0"},{"date":"27 02 2011 13:25:51 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612167","has_replied":"0"},{"date":"27 02 2011 13:25:51 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612166","has_replied":"0"},{"date":"27 02 2011 13:25:51 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612165","has_replied":"0"},{"date":"27 02 2011 13:25:51 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612164","has_replied":"0"},{"date":"27 02 2011 13:25:49 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612163","has_replied":"0"},{"date":"27 02 2011 13:25:49 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612162","has_replied":"0"},{"date":"27 02 2011 13:25:49 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612161","has_replied":"0"},{"date":"27 02 2011 13:25:49 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612160","has_replied":"0"},{"date":"27 02 2011 13:25:49 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612159","has_replied":"0"},{"date":"27 02 2011 13:25:49 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612158","has_replied":"0"},{"date":"27 02 2011 13:25:49 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612157","has_replied":"0"},{"date":"27 02 2011 13:25:49 +0000","subject":"Put Me To Work","body_preview":"I'm ready to work. What do you","to_id":"583","tags":["Intelligence"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1612156","has_replied":"0"},{"date":"27 02 2011 12:15:06 +0000","subject":"Built Junk Henge Sculpture","body_preview":"Congratulations, We were just","to_id":"583","tags":["Medal"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"0","id":"1611234","has_replied":"0"},{"date":"27 02 2011 08:02:07 +0000","subject":"Probe Detected!","body_preview":"Our probe in the {Starmap -87 ","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","id":"1607715","has_replied":"0"},{"date":"27 02 2011 08:02:07 +0000","subject":"Probe Detected!","body_preview":"Our probe in the {Starmap -93 ","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","id":"1607714","has_replied":"0"},{"date":"27 02 2011 06:07:26 +0000","subject":"Probe Destroyed","body_preview":"We just lost contact with our ","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","id":"1606130","has_replied":"0"},{"date":"27 02 2011 06:07:26 +0000","subject":"Probe Destroyed","body_preview":"We just lost contact with our ","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","id":"1606126","has_replied":"0"},{"date":"27 02 2011 06:07:26 +0000","subject":"Probe Destroyed","body_preview":"We just lost contact with our ","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","id":"1606119","has_replied":"0"},{"date":"27 02 2011 06:07:26 +0000","subject":"Probe Destroyed","body_preview":"We just lost contact with our ","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","id":"1606115","has_replied":"0"}],"message_count":"321"}}
#;

our $jsonData = $j->jsonToObj($json);

POE::Session->create(
    package_states => [
        'main' => [
            qw(
              _start
              pop3d_registered
              pop3d_connection
              pop3d_disconnected
              pop3d_cmd_quit
              pop3d_cmd_user
              pop3d_cmd_pass
              pop3d_cmd_stat
              pop3d_cmd_list
              pop3d_cmd_uidl
              pop3d_cmd_top
              pop3d_cmd_retr
              pop3d_cmd_dele
              pop3d_cmd_noop
              )
        ],
    ],
);

$poe_kernel->run();
exit 0;

sub _start
{
    my ($kernel,$self,$sender) = @_[KERNEL,OBJECT,SENDER];

    my $server = $_[HEAP]->{pop3d} = POE::Component::Server::POP3->spawn(
            hostname => 'pop.us1.lacunaexpanse.com',
            port => 10113,
    );
    push @{$server->{cmds}}, 'top';
    warn "Server started on 10113\n";
    return;
}

sub pop3d_registered
{
    my ($kernel,$self,$sender) = @_[KERNEL,OBJECT,SENDER];

    warn "Server successfully started\n";
    #my $plugin = Plugin->new();
    #$_[HEAP]->{pop3d}->plugin_add('TestPlugin', $plugin);
    #$_[HEAP]->{pop3d}->plugin_add('UIDLPlugin', Games::Lacuna::POP3::Plugin::UIDL);
    #$_[HEAP]->{pop3d}->plugin_add('UIDLPlugin', Games::Lacuna::POP3::Plugin::TOP->new);
    # Successfully started pop3d
    return;
}

use DateTime::Format::Strptime;
use DateTime::Format::Mail;
use DateTime;

sub pop3d_connection
{
    my ($heap, $id) = @_[HEAP, ARG0];
    warn "New Connection: $id\n";

    my $input_formatter = DateTime::Format::Strptime->new(
        pattern  => '%d %m %Y %H:%M:%S %z',
        locale   => 'en_US',
        on_error => 'croak',
    );

    my $output_formatter = DateTime::Format::Mail->new();


    my $messages = {};
    my $count = 1;
    foreach my $msg (@{$jsonData->{result}->{messages}})
    {
        use Data::GUID;
        my $id = $msg->{id}; #.Data::GUID->new->as_string();

        my $dt = $input_formatter->parse_datetime($msg->{date});
        my $date = $output_formatter->format_datetime($dt);
        # For filtering
        my @tagHeaders = map { ['X-Lacuna-Mail-Type-'.$_, 1] } @{$msg->{tags}};
        #"has_read":"1","id":"1616502","has_replied":"0"

        $messages->{$count} = {
            id => $id,
            headers => [
                ['Message-ID' => $id],
                ['Date' => $date],
                ['From' => $msg->{from}.'@lacuna'],
                ['To' => $msg->{to} . '@lacuna'],
                ['Subject' => '[' . join(',', @{$msg->{tags}}) . '] ' . $msg->{subject}],
                ['Mime-Version' => '1.0'],
                ['Content-Type' => 'text/plain; charset=utf-8'],
                ['Content-Transfer-Encoding' => 'quoted-printable'],
                @tagHeaders,
            ],
            body => [
                "I could not locate the plan you wanted me to find. I'm sure it is there somewhere. Give me another chance later and I'll locate it and complete my mission.",
                "",
                "Agent Null of Gavania 3",
            ],
        };
        $count++;
    }
    $heap->{clients}->{$id} = {
        auth => 0,
        messages => $messages,
    };
    return;
}

sub pop3d_disconnected
{
    my ($heap, $id) = @_[HEAP, ARG0];
    warn "New Disconnection: $id\n";
    delete $heap->{clients}->{$id};
    return;
}

sub pop3d_cmd_quit
{
    my ($heap, $id) = @_[HEAP, ARG0];

    # Process mailbox in some way
    $heap->{pop3d}->send_to_client($id, '+OK POP3 server signing off');
    return;
}

sub pop3d_cmd_user
{
    my ($heap, $id) = @_[HEAP, ARG0];
    my $user = (split /\s+/, $_[ARG1])[0];
    unless ($user)
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Missing username argument');
        return;
    }
    $heap->{clients}->{$id}->{user} = $user;
    $heap->{pop3d}->send_to_client($id, '+OK User name accepted, password please');
    return;
}

sub pop3d_cmd_pass
{
    my ($heap, $id) = @_[HEAP, ARG0];
    my $pass = (split /\s+/, $_[ARG1])[0];
    unless ($pass)
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Missing password argument');
        return;
    }
    $heap->{clients}->{$id}->{pass} = $pass;

    # Check the password
    $heap->{clients}->{$id}->{auth} = 1;
    #FIXME
    $heap->{pop3d}->send_to_client($id, '+OK Mailbox open, 0 messages');
    return;
}

sub pop3d_cmd_stat
{
    my ($heap, $id) = @_[HEAP, ARG0];
    unless ($heap->{clients}->{$id}->{auth})
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Unknown AUTHORIZATION state command');
        return;
    }
    my $count = scalar(keys %{$heap->{clients}->{$id}->{messages}})-1;
    $heap->{pop3d}->send_to_client($id, "+OK $count 10000");
    return;
}

sub pop3d_cmd_noop
{
    my ($heap, $id) = @_[HEAP, ARG0];
    unless ($heap->{clients}->{$id}->{auth})
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Unknown AUTHORIZATION state command');
        return;
    }
    $heap->{pop3d}->send_to_client($id, '+OK No-op to you too!');
    return;
}

sub pop3d_cmd_uidl
{
    my ($heap, $id) = @_[HEAP, ARG0];
    unless ($heap->{clients}->{$id}->{auth})
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Unknown AUTHORIZATION state command');
        return;
    }
    $heap->{pop3d}->send_to_client($id, '+OK');
    {
        my $count = scalar(keys %{$heap->{clients}->{$id}->{messages}})-1;
        foreach my $mid (1..$count)
        {
            my $message = $heap->{clients}->{$id}->{messages}->{$mid};
            $heap->{pop3d}->send_to_client($id, "$mid " . $message->{id});
            $mid++;
        }
    }

    $heap->{pop3d}->send_to_client($id, '.');
    return;
}

sub pop3d_cmd_top
{
    my ($heap, $id) = @_[HEAP, ARG0];
    my ($msgId, $lines) = split(' ', $_[ARG1]);
    unless ($heap->{clients}->{$id}->{auth})
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Unknown AUTHORIZATION state command');
        return;
    }
    if (!$msgId)
    {
        warn "donno how to handle no $msgId";
        return;
    }
    $heap->{pop3d}->send_to_client($id, '+OK');
    foreach my $header (@{$heap->{clients}->{$id}->{messages}->{$msgId}->{headers}})
    {
        $heap->{pop3d}->send_to_client($id, $header->[0] . ': ' . $header->[1]);
    }
    $heap->{pop3d}->send_to_client($id, "\n");
    $heap->{pop3d}->send_to_client($id, '.');
    return;
}

sub pop3d_cmd_list
{
    my ($heap, $id, $msgId ) = @_[HEAP, ARG0, ARG1];
    unless ($heap->{clients}->{$id}->{auth})
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Unknown AUTHORIZATION state command');
        return;
    }
    if ($msgId)
    {
        #if ($msgId == 1)
        {
            $heap->{pop3d}->send_to_client($id, "+OK $msgId 1000");
            return;
        }
    }
    $heap->{pop3d}->send_to_client($id, '+OK Mailbox scan listing follows');
    {
        my $count = scalar(keys %{$heap->{clients}->{$id}->{messages}})-1;
        foreach my $mid (1..$count)
        {
            my $message = $heap->{clients}->{$id}->{messages}->{$mid};
            next unless $message;
            $heap->{pop3d}->send_to_client($id, "$mid 1000");
            $mid++;
        }
    }
    $heap->{pop3d}->send_to_client($id, '.');
    return;
}

sub pop3d_cmd_dele
{
    my ($heap, $id, $msgId) = @_[HEAP, ARG0, ARG1];
    unless ($heap->{clients}->{$id}->{auth})
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Unknown AUTHORIZATION state command');
        return;
    }
    unless ($heap->{clients}->{$id}->{messages}->{$msgId})
    {
        $heap->{pop3d}->send_to_client($id, "-ERR message $msgId already deleted");
        return;
    }
    delete $heap->{clients}->{$id}->{messages}->{$msgId};
    $heap->{pop3d}->send_to_client($id, "+OK message $msgId deleted");
    return;
}

sub pop3d_cmd_retr
{
    my ($heap, $id, $msgId) = @_[HEAP, ARG0, ARG1];
    unless ($heap->{clients}->{$id}->{auth})
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Unknown AUTHORIZATION state command');
        return;
    }
        
    my $body = "";
    foreach my $line (@{$heap->{clients}->{$id}->{messages}->{$msgId}->{body}})
    {
        # byte-stuff lines starting with .
        $line =~ s/^\./\.\./o;
        $line .= "\r\n";
        $body .= $line;
    }
    
    $heap->{pop3d}->send_to_client($id, '+OK '.length($body).' octets');
    foreach my $header (@{$heap->{clients}->{$id}->{messages}->{$msgId}->{headers}})
    {
        $heap->{pop3d}->send_to_client($id, $header->[0] . ': ' . $header->[1]);
    }
    $heap->{pop3d}->send_to_client($id, "");
    $heap->{pop3d}->send_to_client($id, $body);
    $heap->{pop3d}->send_to_client($id, ".");
    return;
}
