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

BEGIN {
    package POE::Kernel;
    use constant ASSERT_DEFAULT => 1;
}
# A simple POP3 Server that demonstrates functionality
use POE qw(Component::Client::HTTP);
use POE::Component::Server::POP3;
use Data::Dumper;
use HTTP::Request;

my $debug = 1;
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

POE::Component::Client::HTTP->spawn(
    Agent     => 'Lacuna-POP3-Server/0.01',   # defaults to something long
    Alias     => 'ua',                  # defaults to 'weeble'
);

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

              lacuna_login_response
              lacuna_get_inbox_response
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

    $heap->{clients}->{$id} = {
        auth => 0,
        messages => {},
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

# This is the sub which is called when the session receives a
# 'response' event.
sub lacuna_login_response
{
    my ($heap, $kernel, $request_packet, $response_packet) = @_[HEAP, KERNEL, ARG0, ARG1];

    # HTTP::Request
    my $request = $request_packet->[0];
    # HTTP::Response
    my $response = $response_packet->[0];

    my $id = $request->{pop3_conn_id};
    if (!$response->is_success)
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Bad username or password');
        return;
    }
    my $client;
    eval {
        my $responseJSON = $j->jsonToObj($response->content());
        # {"id":5,"method":"login","jsonrpc":"2.0","params":["halkeye","---password---","53137d8f-3544-4118-9001-b0acbec70b3d"]}
        $client = $heap->{clients}->{$id} || {};
        $client->{session_id} = $responseJSON->{result}->{session_id};
        $client->{has_new_messages} = $responseJSON->{result}->{status}->{has_new_messages};
        $client->{auth} = 1;

        $heap->{clients}->{$id} = $client;
        #$heap = $request->{pop3_heap};
    };
    if (!$client)
    {
        warn "Lack of client";
        print "Error: $@\n" if $@;
        $heap->{pop3d}->send_to_client($id, '-ERR Error has occurred');
        return;
    }

    $request = HTTP::Request->new( 
            POST => 'http://pt.lacunaexpanse.com/inbox',
            [],
            '{"id":8,"method":"view_inbox","jsonrpc":"2.0","params":["' . $client->{session_id} . '",{"page_number":1}]}',
    );
    $request->{pop3_conn_id} = $id;
    $kernel->post('ua', 'request', 'lacuna_get_inbox_response', $request);
    return;
}

sub lacuna_get_inbox_response
{
    my ($heap, $self, $request_packet, $response_packet) = @_[HEAP, OBJECT, ARG0, ARG1];

    # HTTP::Request
    my $request = $request_packet->[0];
    # HTTP::Response
    my $response = $response_packet->[0];

    my $id = $request->{pop3_conn_id};
    if (!$response->is_success)
    {
        warn $response->content();
        $heap->{pop3d}->send_to_client($id, '-ERR Error Occurred - get_inbox');
        return;
    }
    my $client;
    my $input_formatter = DateTime::Format::Strptime->new(
        pattern  => '%d %m %Y %H:%M:%S %z',
        locale   => 'en_US',
        on_error => 'croak',
    );

    my $output_formatter = DateTime::Format::Mail->new();
    eval {
        my $responseJSON = $j->jsonToObj($response->content());
        # {"jsonrpc":"2.0","id":8,"result":{"messages":[{"date":"28 02 2011 02:01:19 +0000","subject":"Glyph Discovered!","body_preview":"Great news! Our archaeologists","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","id":"1626283","has_replied":"0"}],"message_count":"338"}}
        $client = $heap->{clients}->{$id} || {};

        my $count = 1;
        foreach my $msg (@{$responseJSON->{result}->{messages}})
        {
            #use Data::GUID;
            my $id = $msg->{id}; #.Data::GUID->new->as_string();

            my $dt = $input_formatter->parse_datetime($msg->{date});
            my $date = $output_formatter->format_datetime($dt);
            # For filtering
            my @tagHeaders = map { ['X-Lacuna-Mail-Type-'.$_, 1] } @{$msg->{tags}};
            #"has_read":"1","id":"1616502","has_replied":"0"

            $client->{messages}->{$count} = {
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
                #body => [
                #    "I could not locate the plan you wanted me to find. I'm sure it is there somewhere. Give me another chance later and I'll locate it and complete my mission.",
                #    "",
                #    "Agent Null of Gavania 3",
                #],
            };
            $count++;
        }
        $heap->{clients}->{$id} = $client;
        $heap->{pop3d}->send_to_client($id, '+OK Mailbox open, 0 messages');
    };

    if (!$client)
    {
        warn "Error: $@\n" if $@;
        warn "Lack of client";
        $heap->{pop3d}->send_to_client($id, '-ERR Error has occurred');
        return;
    }
}

sub pop3d_cmd_pass
{
    my ($heap, $self, $kernel, $id) = @_[HEAP, OBJECT, KERNEL, ARG0];
    my $pass = (split /\s+/, $_[ARG1])[0];
    unless ($pass)
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Missing password argument');
        return;
    }

    my $user = $heap->{clients}->{id}->{user};
    my $request = HTTP::Request->new( 
            POST => 'http://pt.lacunaexpanse.com/empire',
            [], '{"id":5,"method":"login","jsonrpc":"2.0","params":["'.$user.'","'.$pass.'","53137d8f-3544-4118-9001-b0acbec70b3d"]}'
    );
    $request->{pop3_conn_id} = $id;
    $kernel->post('ua', 'request', 'lacuna_login_response', $request);
    return;
    
    # pt.lacunaexpanse.com
    #
    # {"id":8,"method":"view_inbox","jsonrpc":"2.0","params":["2b52ce9d-5cad-40fa-9d24-c7af4d30f224",{"page_number":1}]}
    # {"jsonrpc":"2.0","id":8,"result":{"messages":[{"date":"28 02 2011 02:01:19 +0000","subject":"Glyph Discovered!","body_preview":"Great news! Our archaeologists","to_id":"583","tags":["Alert"],"from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","id":"1626283","has_replied":"0"}],"message_count":"338"}}
    #
    # {"id":9,"method":"read_message","jsonrpc":"2.0","params":["2b52ce9d-5cad-40fa-9d24-c7af4d30f224","1623899"]}
    # {"jsonrpc":"2.0","id":9,"result":{"message":{"attachments":null,"date":"27 02 2011 23:33:48 +0000","subject":"Pollution Causing Outrage","in_reply_to":null,"to_id":"583","tags":["Alert"],"body":"The citizens of {Planet 123456 Planet Name} are up in arms about the level of pollution being produced by the continued growth on the planet.\n\nYou should find a way to manage the waste or their discontent could affect the progress of the empire dramatically.\n\nRegards,\n\nYour Humble Assistant\n","from_id":"583","to":"halkeye","from":"halkeye","has_read":"1","has_replied":"0","id":"1623899","recipients":["halkeye"],"has_archived":"0"}}}
    #
    # {"id":10,"method":"archive_messages","jsonrpc":"2.0","params":["2b52ce9d-5cad-40fa-9d24-c7af4d30f224",["1623899"]]}
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
