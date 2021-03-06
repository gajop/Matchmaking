# We define our plugin class
package Matchmaking;

# We use strict Perl syntax for cleaner code
use strict;

use JSON::PP;
use SpringAutoHostInterface;

# We use the SPADS plugin API module
use SpadsPluginApi;

# We don't want warnings when the plugin is reloaded
no warnings 'redefine';

# This is the first version of the plugin
my $pluginVersion='0.1';

my $requiredSpadsVersion='0.11.5';

sub getVersion { return $pluginVersion; }
sub getRequiredSpadsVersion { return $requiredSpadsVersion; }

# This is our constructor, called when the plugin is loaded by SPADS (mandatory callback)
sub new {

  # Constructors take the class name as first parameter
  my $class=shift;

  # We create a hash which will contain the plugin data
  my $self = { queues => {}, 
			   tmpQueue => undef };

  # We instanciate this hash as an object of the given class
  bless($self,$class);

  # We call the API function "slog" to log a notice message (level 3) when the plugin is loaded
  slog("Plugin loaded (version $pluginVersion)",3);

  $self->init();

  # We return the instantiated plugin
  return $self;

}

sub parseJsonCmd {
	my @cmd = @_;
	@cmd = @cmd[1 .. $#cmd];
	my ($fieldName,$json)=@_;
	return decode_json(join(' ', @cmd))
}

sub init {
  my $self = shift;
  addLobbyCommandHandler({ FAILED => \&hLobbyFailed,
                           OPENQUEUE => \&hLobbyOpenQueue,
                           JOINQUEUEREQUEST => \&hLobbyJoinQueueRequest,
                           QUEUELEFT => \&hLobbyQueueLeft,
                           READYCHECKRESPONSE => \&hLobbyReadyCheckResponse,
                           REMOVEUSER => \&hLobbyRemoveUser,
  });

  # Using this plugin means we don't use battles
  slog("Using matchmaking plugin, closing battle...", 3); 
  closeBattle("Running in Queue mode...");
  
  my $queue = { "name" => "BADSD1", "gameNames" => [ "Balanced Annihilation V8.12" ], "mapNames" => [ "DeltaSiegeDry" ] , "engineVersions" => [ "101" ], "title" => "BADSD24/7", "description" => "Join the grind", "minPlayers" => 10, "maxPlayers" => 30, "teamJoinAllowed" => JSON::PP::true };
  $self->addQueue($queue);
  $queue = { "name" => "BADSD2", "gameNames" => [ "Balanced Annihilation V8.12" ], "mapNames" => [ "DeltaSiegeDry" ] , "engineVersions" => [ "101" ], "title" => "BA 1v1", "description" => "Join the grind", "minPlayers" => 10, "maxPlayers" => 30, "teamJoinAllowed" => JSON::PP::true };
  $self->addQueue($queue);
  
  $queue = { "name" => "CURSED", "gameNames" => [ "Cursed v5" ], "mapNames" => [ "DeltaSiegeDry" ] , "engineVersions" => [ "101" ], "title" => "Cursed", "description" => "Join the grind", "minPlayers" => 10, "maxPlayers" => 30, "teamJoinAllowed" => JSON::PP::true };
  $self->addQueue($queue);
  $queue = { "name" => "EVONORMAL", "gameNames" => [ "EvolutionRTS v1" ], "mapNames" => [ "DeltaSiegeDry" ] , "engineVersions" => [ "101" ], "title" => "EvolutionRTS", "description" => "Join the grind", "minPlayers" => 10, "maxPlayers" => 30, "teamJoinAllowed" => JSON::PP::true };
  $self->addQueue($queue);
  $queue = { "name" => "MYGAME", "gameNames" => [ "My New game v1" ], "mapNames" => [ "DeltaSiegeDry" ] , "engineVersions" => [ "101" ], "title" => "My new game!", "description" => "Join the grind", "minPlayers" => 10, "maxPlayers" => 30, "teamJoinAllowed" => JSON::PP::true };
  $self->addQueue($queue);
  
  $queue = { "name" => "MANYGAMES", "gameNames" => [ "EvolutionRTS v1", "Balanced Annihilation V8.12", "Cursed 3" ], "mapNames" => [ "DeltaSiegeDry" ] , "engineVersions" => [ "101" ], "title" => "Bunch of games", "description" => "Join the grind", "minPlayers" => 10, "maxPlayers" => 30, "teamJoinAllowed" => JSON::PP::true };
  $self->addQueue($queue);
}

sub addQueue {	
	my ($self, $queue) = @_;
	
	queueLobbyCommand(['OPENQUEUE', encode_json($queue)]);
		
	$self->{tmpQueue} = $queue;
}

sub hLobbyFailed {
	my $self = getPlugin();
	
    # just logs error for now
    slog(join(' ', @_));
}

sub hLobbyOpenQueue {
	my $self = getPlugin();
	
    # log it
    slog(join(' ', @_), 3);

    my $obj = parseJsonCmd(@_);

	my $name = $obj->{name};
	
    my $queue = $self->{tmpQueue};
    $queue->{name} = $name;
    $queue->{users} = [];    
    $self->{queues}->{$name} = $queue;
}

sub hLobbyJoinQueueRequest {
	my $self = getPlugin();
	
    # log it
    slog(join(' ', @_), 3);

    my $obj = parseJsonCmd(@_);

    my $name = $obj->{name};
    my $userNames = $obj->{userNames};

    my $queue = $self->{queues}->{$name};
    push @{$queue->{users}}, $userNames;

	# accept everyone
	queueLobbyCommand(['JOINQUEUEACCEPT', encode_json({name => $name, userNames => $userNames})]);

	# ready check someplace else
	queueLobbyCommand(['READYCHECK', encode_json({name => $name, userNames => $userNames, "responseTime" => 5})]);
}

sub hLobbyQueueLeft {
	my $self = getPlugin();
	
    # log it
    slog(join(' ', @_), 3);
    
    my $obj = parseJsonCmd(@_);

    my $name = \$obj->{name};
    my $userName = $obj->{userName};
        
    my $queue = $self->{queues}->{$name};
    
    #$queue->
}

sub hLobbyReadyCheckResponse {
	my $self = getPlugin();
	
    # log it
    slog(join(' ', @_), 3);
    
	my $obj = parseJsonCmd(@_);
    
    my $name = $obj->{name};
    my $userName = $obj->{userName};
    my $response = $obj->{response};
    
    my $queue = $self->{queues}->{$name};
    
    # TODO: check if all people have responded
    my $userNames = [];
    
		my $result;
		if ($response eq "ready") {
			push $userNames, $userName;
			$result = "pass";
		} else {
			$result = "fail";
		}
    
    queueLobbyCommand(['READYCHECKRESULT', encode_json({"name" => $name, "userNames" => $userNames, "result" => $result})]);
    
    $self->spawnGame($queue, $userNames);
    
}

sub spawnGame {
	my ($self, $queue, $userNames) = @_;
	
	my $game = $queue->{gameNames}->[0];
	my $map = $queue->{mapNames}->[0];
	my $engine = $queue->{engineVersions}->[0];
	
	my $ip = "127.0.0.1";
	my $port = "40";	
	
	my $gameInstance = SpringAutoHostInterface->new(
        autoHostPort => $port,
        );
#	$gameInstance->
	
	foreach my $userName (@{$userNames}) {
        my $password = "randomGen";
        my $jsonStr = encode_json({"userName" => $userName, "ip" => $ip, 
		"port" => $port, "password" => $password, "engine" => $engine});		
		queueLobbyCommand(['CONNECTUSER', $jsonStr]);
	}
}

sub hLobbyRemoveUser {
	my $self = getPlugin();
	
    # log it
    slog(join(' ', @_), 3);
}

sub onUnload {
	my $self = getPlugin();
	slog("Unloading...", 3);
	while (my ($key, $queue) = each $self->{queues}) {
		slog("Closing queue {name:" . $queue->{name} . "}...", 3);
		queueLobbyCommand(['CLOSEQUEUE', encode_json({"name" => $queue->{name}})]);
	}
}

sub onLobbyConnected {
	my $self = shift;
	$self->init();
}

sub onLobbyDisconnected {
	my $self = getPlugin();
}

sub eventLoop() {
	my $self = getPlugin();
	# make sure it doesn't check too often
	
	# resolve ready checks
	
	# do matchmaking
}

1;
