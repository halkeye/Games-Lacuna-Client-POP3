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
BEGIN {
    package POE::Kernel;
    use constant ASSERT_DEFAULT => $ENV{VIM} ? 1 : 0;
}
use Getopt::Long;

use constant API_KEY => '729088f7-3b44-4704-ab90-96ecc267617e';
use constant SERVER_NAME => 'pt.lacunaexpanse.com';

my $port = 110;
$port = 10113 if $ENV{VIM};
my $hostname = 'pop.' . SERVER_NAME;

GetOptions (
        "port=i" => \$port,
        'hostname=s' => \$hostname,
);

# A simple POP3 Server that demonstrates functionality
use POE qw(Component::Client::HTTP);
use POE::Component::Server::POP3;
use Data::Dumper;
use HTTP::Request;

my $debug = $ENV{VIM};
$debug = 0;
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
              lacuna_get_message_response
              )
        ],
    ],
);

$poe_kernel->run();
exit 0;

{
    my $clientCallId = 0;
    sub _makeClientCall
    {
        my ($kernel,$contextData, $url, $method, $data, $callback) = @_;
        
        $data = {
            id => $clientCallId++,
            method => $method,
            jsonrpc => '2.0',
            params => $data,
        };
        my $json = $j->objToJson($data);
        my $request = HTTP::Request->new( 
                POST => "http://pt.lacunaexpanse.com$url",
                [], $json,
        );
        #warn "Making call to http://pt.lacunaexpanse.com$url with $json";
        $request->{pop3_context} = $contextData;
        $kernel->post('ua', 'request', $callback, $request);
    }
}


sub _start
{
    my ($kernel,$self,$sender) = @_[KERNEL,OBJECT,SENDER];

    my $server = $_[HEAP]->{pop3d} = POE::Component::Server::POP3->spawn(
            hostname => $hostname,
            port => $port,
    );
    push @{$server->{cmds}}, 'top';
    warn "Server started on $port\n";
    return;
}

sub pop3d_registered
{
    my ($kernel,$self,$sender) = @_[KERNEL,OBJECT,SENDER];

    warn "Server successfully started\n";
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

    my $context = $request->{pop3_context};
    if (!$response->is_success)
    {
        warn ($response->content());
        $heap->{pop3d}->send_to_client($context->{id}, '-ERR Bad username or password');
        return;
    }
    my $client;
    eval {
        my $responseJSON = $j->jsonToObj($response->content());
        $client = $heap->{clients}->{$context->{id}} || {};
        $client->{session_id} = $responseJSON->{result}->{session_id};
        $client->{has_new_messages} = $responseJSON->{result}->{status}->{has_new_messages};
        $client->{auth} = 1;

        $heap->{clients}->{$context->{id}} = $client;
        #$heap = $request->{pop3_heap};
    };
    if (!$client)
    {
        warn "Lack of client";
        print "Error: $@\n" if $@;
        $heap->{pop3d}->send_to_client($context->{id}, '-ERR Error has occurred');
        return;
    }

    return _makeClientCall(
            $kernel,
            $context,
            '/inbox', 
            'view_inbox', 
            [ $client->{session_id}, { page_number => 1} ],
            'lacuna_get_inbox_response',
    );
    return;
}

sub lacuna_get_inbox_response
{
    my ($heap, $self, $request_packet, $response_packet) = @_[HEAP, OBJECT, ARG0, ARG1];

    # HTTP::Request
    my $request = $request_packet->[0];
    # HTTP::Response
    my $response = $response_packet->[0];

    my $context = $request->{pop3_context};
    if (!$response->is_success)
    {
        warn $response->content();
        $heap->{pop3d}->send_to_client($context->{id}, '-ERR Error Occurred - get_inbox');
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
        $client = $heap->{clients}->{$context->{id}} || {};

        my $count = 1;
        foreach my $msg (@{$responseJSON->{result}->{messages}})
        {
            #use Data::GUID;
            my $id = $msg->{id}; #.Data::GUID->new->as_string();

            my $dt = $input_formatter->parse_datetime($msg->{date});
            my $date = $output_formatter->format_datetime($dt);

            # For filtering
            my %headers = (
                    'Message-ID' => $id,
                    'Date' => $date,
                    'From' => $msg->{from}.'@' . SERVER_NAME,
                    'Subject' => '[' . join(',', @{$msg->{tags}}) . '] ' . $msg->{subject},
                    'To' => $msg->{to}, # fallback
                    'Mime-Version' => '1.0',
                    'Content-Type' => 'text/plain; charset=utf-8',
                    'Content-Transfer-Encoding' => 'quoted-printable',
            );

            foreach (@{$msg->{tags}})
            {
                $headers{'X-Lacuna-Mail-Type-'.$_} = 1;
            }

            $client->{messages}->{$count} = {
                id => $id,
                headers => \%headers,
            };
            # 'To' => join(" ,", map { $_ . ' <' . $_ . '@' . SERVER_NAME . '>' } @{$msg->{recipients}}) ],
            $count++;
        }
        $heap->{clients}->{$context->{id}} = $client;
        $heap->{pop3d}->send_to_client($context->{id}, '+OK Mailbox open, 0 messages');
    };

    if (!$client)
    {
        warn "Error: $@\n" if $@;
        warn "Lack of client";
        $heap->{pop3d}->send_to_client($context->{id}, '-ERR Error has occurred');
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

    my $user = $heap->{clients}->{$id}->{user};
    return _makeClientCall(
            $kernel,
            { id => $id},
            '/empire', 
            'login', 
            [ $user, $pass, API_KEY ],
            'lacuna_login_response',
    );
    
    # pt.lacunaexpanse.com
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
    my ($heap, $kernel, $id, $msgId) = @_[HEAP, KERNEL, ARG0, ARG1];
    my $client = $heap->{clients}->{$id};
    unless ($client && $client->{auth})
    {
        $heap->{pop3d}->send_to_client($id, '-ERR Unknown AUTHORIZATION state command');
        return;
    }

    my $message = $client->{messages}->{$msgId};

    return _makeClientCall(
            $kernel,
            { id => $id, msgId => $msgId, message => $message},
            '/inbox', 
            'read_message', 
            [ $client->{session_id}, $message->{id} ],
            'lacuna_get_message_response',
    ) if (!$message->{body});

    return _send_msg_body($heap, $id, $message);
}

sub _send_msg_body
{
    my ($heap, $id, $message) = @_;

    my $body = "";
    foreach my $line (@{$message->{body}})
    {
        # byte-stuff lines starting with .
        $line =~ s/^\./\.\./o;
        $line .= "\r\n";
        $body .= $line;
    }
    
    $heap->{pop3d}->send_to_client($id, '+OK '.length($body).' octets');
    foreach my $header (keys %{$message->{headers}})
    {
        $heap->{pop3d}->send_to_client($id, $header . ': ' . $message->{headers}->{$header});
    }
    $heap->{pop3d}->send_to_client($id, "");
    $heap->{pop3d}->send_to_client($id, $body);
    $heap->{pop3d}->send_to_client($id, ".");
    return;
}

sub lacuna_get_message_response
{
    my ($heap, $kernel, $request_packet, $response_packet) = @_[HEAP, KERNEL, ARG0, ARG1];

    # HTTP::Request
    my $request = $request_packet->[0];
    # HTTP::Response
    my $response = $response_packet->[0];

    my $context = $request->{pop3_context};
    if (!$response->is_success)
    {
        $heap->{pop3d}->send_to_client($context->{id}, '-ERR Unable to locate message');
        return;
    }

    my $client;
    eval {
        my $responseJSON = $j->jsonToObj($response->content());
        my $msg = $responseJSON->{result}->{message};

        $context->{message}->{headers}->{'To'} = join(" ,", map { $_ . ' <' . $_ . '@' . SERVER_NAME . '>' } @{$msg->{recipients}})
            if $msg->{recipients};
        $context->{message}->{body} = [split('\n', $msg->{body})];
    };
    return _send_msg_body($heap, $context->{id}, $context->{message}) unless $@;
    warn "Error: $@";
    $heap->{pop3d}->send_to_client($context->{id}, '-ERR Error has occurred');
    return;
}
