#!/usr/bin/env perl

use strict;
use warnings;
use version;

use FindBin;
use lib "$FindBin::Bin/../lib"; 
use lib "$FindBin::Bin/../distros";
use cpan_config;
use Term::ReadPassword; 
use Linux::Distribution qw(distribution_name distribution_version);

#Core Perl Modules
use Config;
use CPAN;
use Cwd;

use Data::Dumper;
#use DateTime;

use File::Path qw(make_path remove_tree);
use File::Spec;
use File::Copy;
#use File::CheckTree;

use Getopt::Long;

use IPC::Cmd qw(can_run run);

use List::Util qw(max);

use Pod::Usage;

use Sys::Hostname;

use Term::UI;
use Term::ReadLine;

use User::pwent;

use IO::Handle qw();

use WeBWorK::Install::Utils;
use WeBWorK::Install::Database;

#non-core
#use DateTime::TimeZone; 

######################################################################
# Create a new Term::Readline object for interactivity
#Don't worry people with spurious warnings.
######################################################################
$Term::UI::VERBOSE = 0;
my $term = Term::ReadLine->new('');

use constant IPC_CMD_TIMEOUT =>
  6000;    #Sets maximum time system commands will be allowed to run
use constant IPC_CMD_VERBOSE => 1;    #Controls whether all output of a command
                                      #should be printed to STDOUT/STDERR

##################################################################
#
# Defaults - each of these values is passed as a default to 
# some config question
#
###################################################################

use constant WEBWORK2_REPO => 'https://github.com/openwebwork/webwork2.git';
use constant PG_REPO       => 'https://github.com/openwebwork/pg.git';
use constant OPL_REPO =>
  'https://github.com/openwebwork/webwork-open-problem-library.git';
use constant MATHJAX_REPO => "https://github.com/mathjax/MathJax.git";

use constant WW_PREFIX => '/opt/webwork/';
use constant ROOT_URL  => 'http://localhost';
use constant WW_URL    => '/webwork2';

use constant SMTP_SERVER => 'localhost';
use constant SMTP_SENDER => 'webwork@localhost';

use constant WW_DB     => 'webwork';
use constant WWDB_USER => 'webworkWrite';

use constant CHECKOUT_BRANCH => 0;
use constant WW_BRANCH => 'master';
use constant PG_BRANCH => 'master';

use constant SKIP_INSTALL_PREREQUISITES => 0;

#################################################################
#
# Prerequisites - keep in sync with webwork2/bin/check_modules.pl
#		- These lists are the masters which are used to check
#               - the packages installed by the distro files.  
#
################################################################

my @apacheBinaries = qw(
  apache2
  apachectl
);

my @applicationsList = qw(
  mv
  cp
  rm
  mkdir
  tar
  gzip
  curl
  latex
  pdflatex
  dvipng
  mysql
  giftopnm
  ppmtopgm
  pnmtops
  pnmtopng
  pngtopnm
  lwp-request
  mysql
  mysqldump
  svn
  git
);

my @apache2ModulesList = qw(
  Apache2::Request
  Apache2::Cookie
  Apache2::ServerRec
  Apache2::ServerUtil
  
);

my @apache2SharedModules  = qw(
  mpm_prefork
  fcgid_module
  perl_module
  apreq_module
);

my @modulesList = qw(
	Array::Utils
	Benchmark
	Carp
	CGI
	Class::Accessor
	Crypt::SSLeay
	Dancer
	Dancer::Plugin::Database
	Data::Dump
	Data::Dumper
	Data::UUID 
	Date::Format
	Date::Parse
	DateTime
	DBD::mysql
	DBI
	Digest::MD5
	Digest::SHA
	Email::Address
	Email::Simple;
	Email::Sender::Simple
	Email::Sender::Transport::SMTP
	Errno
	Exception::Class
	File::Copy
	File::Find
	File::Find::Rule
	File::Path
	File::Spec
	File::stat
	File::Temp
	GD
	Getopt::Long
	Getopt::Std
	HTML::Entities
	HTML::Scrubber
	HTML::Tagset
	HTML::Template
	IO::File
	Iterator
	Iterator::Util
	JSON
	Locale::Maketext::Lexicon
	Locale::Maketext::Simple
	LWP::Protocol::https
	MIME::Base64
	Net::IP
	Net::LDAPS
	Net::OAuth
	Net::SMTP
	Opcode
	PadWalker
	Path::Class
	PHP::Serialization
	Pod::Usage
	Pod::WSDL
	Safe
	Scalar::Util
	SOAP::Lite 
	Socket
	SQL::Abstract
	Statistics::R::IO
	String::ShellQuote
	Template
	Text::CSV
	Text::Wrap
	Tie::IxHash
	Time::HiRes
	Time::Zone
	URI::Escape
	UUID::Tiny
	XML::Parser
	XML::Parser::EasyTree
	XML::Writer
	XMLRPC::Lite
	YAML
);

sub get_os {
    my $os;
    if ( $^O eq "darwin" ) {
        $os->{type} = "unix";
        $os->{name} = "darwin";
        chomp( $os->{version} = `sw_vers -productVersion` );
        chomp( $os->{arch}    = `uname -m` );
        print_and_log("Great, you're on Mac running OS X $$os{version} on $$os{arch} hardware.\n");
    } elsif ( $^O eq "freebsd" ) {
        $os->{type} = "unix";
        $os->{name} = "freebsd";
        chomp( $os->{version} = `uname -r` );
        chomp( $os->{arch}    = `uname -m` );
        print_and_log("I see - rocking it on FreeBSD $$os{version} on $$os{arch} hardware.\n");
    } elsif ( $^O eq "linux" )
    {    #Now we're going to have to look more closely to get specific distro
        $os->{type}    = "linux";
        $os->{name}    = distribution_name();
        $os->{version} = distribution_version();
        chomp( $os->{arch} = `uname -m` );
        print_and_log("Linux, yay! That's my favorite. I see you're running $$os{name} "
          . "version $$os{version} on $$os{arch} hardware. This will be easy.\n\n");
    } elsif ( $^O eq "MSWin32" ) {
        print_and_log("Installing WeBWorK on Windows is, afaik, currently impossible.\n");
        print_and_log("If you get it working, please let us know. Good luck!\n");
    } else {
        $os->{type}    = $^O;
        $os->{name}    = distribution_name();
        $os->{version} = distribution_version();
        chomp( $os->{arch} = `uname -m` );
        print_and_log("I see you're running $$os{name} version $$os{version} on $$os{arch} hardware. This script is not set up to support your operating system.  Configuring the script for new operating system isnt too difficult.  It would be very helpful if you could send a report to webwork\@maa.org. We can help you get it working if it doesn't work, and if it does we would like to add it to the list of supported systems.\n");
    }

    #Package name is distro::version with any dots removed from version. 
    $os->{osPackage} = $os->{name}.'::'.$os->{version};
    $os->{osPackage} =~ s/\.//g;
    
    return $os;
}

sub get_os_package {
    my $os = shift;
    my $osPackage = $os->{osPackage};
    
    no strict 'refs';

    eval "require $osPackage";

    use strict;

    if ($@) {
	print_and_log("I see you're running $$os{name} version $$os{version} on $$os{arch} hardware.  There is no disto specific package for your operating system.  Often setting up such a package is as simple as copying over a simlar package from the distros folder.  The package you will have to create is ${osPackage} in the distros folder.  If you get your installation running please consider contributing your new distro package file to the git repository.\n");
	die "Couldn't load distro package: $@";
    }
    
    require blankdistro;

    #Check to see that the main data arrays are fully fleshed out when
    # comparied to the blank distro. 

    my $packageFile = $osPackage;
    $packageFile =~ s/::/\//g;
    $packageFile = '/distros/'.$packageFile.'.pm';

    my $blankbinary = blankdistro->get_binary_prerequisites();
    my $packagebinary = $osPackage->get_binary_prerequisites();

    foreach my $key (keys %$blankbinary) {
	if (!defined($packagebinary->{$key})) {
	    print_and_log("WeBWorK requires a package which provides $key, and this package is missing from your distro file $osPackage.  To continue the installation add this package to the \$binary_prerequisites hash in $packageFile.\n");
	    die("Missing package definition, can't continue.\n");
	}
    }

    my $blankperl = blankdistro->get_perl_prerequisites();
    my $packageperl = $osPackage->get_perl_prerequisites();
    
    foreach my $key (keys %$blankperl) {
	if (!defined($packageperl->{$key})) {
	    print_and_log("WeBWorK requires the perl package $key, and this package is missing from your distro file $osPackage.  To continue the installation add this package to the \$perl_prerequisites hash in $packageFile.\n");
	    die("Missing package definition, can't continue.\n");
	}
    }
 
    my $blankapache = blankdistro->get_apacheLayout();
    my $packageapache = $osPackage->get_apacheLayout();
    
    foreach my $key (keys %$blankapache) {
	if (!defined($packageapache->{$key})) {
	    print_and_log("WeBWorK requires information about apache relating to $key, and this missing from your distro file $osPackage.  To continue the installation add this information to the \$apacheyLayout hash in $packageFile.\n");
	    die("Missing apache layout, can't continue.\n");
	}
    }

    return;

}


######################################################
#
# Prerequisite Handling
#
#######################################################

sub install_prerequisites {
    my $options = shift;
    my $osPackage = $options->{osPackage};

    my $print_me = <<EOF;
We will start by installing the prerequisite packages and perl modules on your machine.  This process can take some time and you may ocassionally be asked a question.  The default answer is almost certainly correct.  
EOF
    
    my $ready = $term->ask_yn(
        print_me => $print_me,
        prompt   => 'Ready to install prerequisites?',
        default  => 'y',
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();
    die "Come back soon!" unless $ready;

    print_and_log("Updating system sources.\n");
    $osPackage->update_sources();
  
    print_and_log("Updating system packages.\n");
    $osPackage->update_packages();
    
    my $binary_preqs = $osPackage->get_binary_prerequisites();
    my $perl_preqs = $osPackage->get_perl_prerequisites();
    my @packages;
    my @cpanModules;

    foreach my $key (keys %$binary_preqs) {
	push @packages, $binary_preqs->{$key};
    }

    foreach my $key (keys %$perl_preqs) {
	if ($perl_preqs->{$key} eq 'CPAN') {
	    push @cpanModules, $key;
	} else {
	    push @packages, $perl_preqs->{$key};
	}
    }
    
    print_and_log('Installing the following system packages: '.
		  join(', ',@packages)."\n");
    $osPackage->package_install(@packages);

    $osPackage->midpreq_hook();

    print_and_log('Installing the following CPAN modules: '.
		  join(', ',@cpanModules)."\n");
    $osPackage->CPAN_install(@cpanModules);

    print_and_log("Setting up and enabling services.\n");
    $osPackage->configure_services();
    
    print_and_log("Done installing prerequisites.\n");
    
    return 1;
}

#####################################################
#
# Check if user is ready to install
#
####################################################

sub get_ready {
    
    my $print_me = <<EOF;
Welcome to the WeBWorK.  This installation script will ask you a few questions and then attempt to install 
WeBWorK on your system. To complete the installation
(a) You must be connected to the internet, and 
(b) You must have administrative privileges on this machine.
EOF
    my $ready = $term->ask_yn(
        print_me => $print_me,
        prompt   => 'Ready to install WeBWorK?',
        default  => 'y',
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    die "Come back soon!" unless $ready;
}

####################################################################
#
# Check if the user is root
#
# We probably need to be root. The effective user id of the user 
# running the script is held in the perl special variable $>.  In 
# particular, if $> = 0 user is root, works with sudo too.
#
####################################################################

sub check_root {
    if ( $> == 0 ) {
        print_and_log("Running as root....\n");
        return 1;
    } else {

        #my $term = Term::ReadLine->new('');
        my $print_me = <<EOF;
IMPORTANT: I see that you are not running this script as root. Some elevated system
privileges are needed to install WeBWorK.  If you run the script without sufficient privileges then
it will fail in ways that might be hard to track down.    
EOF
        my $prefix = $term->ask_yn(
            print_me => $print_me,
            prompt =>
'Are you sure you\'re running the script with the privileges you\'ll need to complete the installation?',
            default => 'n',
        );
	writelog($term->history_as_string()."\n");
	Term::UI::History->flush();
    }
}

sub get_selinux {
    my $enabled;
    my $disable;
    my $full_path = can_run('selinuxenabled');
    if($full_path) {
	my $cmd = [$full_path];
        $enabled = run(
          command => $cmd,
          verbose => IPC_CMD_VERBOSE,
          timeout => IPC_CMD_TIMEOUT
        );
     }
    if($enabled) {
	my $print_me=<<END;
################################################
#
# This machine appears to have SELinux
# enabled.  We strongly recommend disabling
# SELinux. If you choose not to disable
# SELinux then webwork will not work
# properly unless you can devise a 
# SELinux policy that allows it to do
# what it needs to function.
#
# If you choose to disable SELinux I
# will set it to permissive mode for
# this session and replace /etc/selinux/config
# with a config file that will disable
# SELinux permanently after a reboot.
#
#################################################
END
       $disable = $term->ask_yn(
  	    print_me => $print_me,
	    prompt => 'Disable SELinux?',
	    default => 'y',
        ); 
	writelog($term->history_as_string()."\n");
	Term::UI::History->flush();
	
	my $confirmed = confirm_answer($disable);
        get_selinux() unless $confirmed->{status};
    }
    disable_selinux() if $disable;
    print_and_log("Good, SELinux not enabled.\n") unless $enabled;
    print_and_log("You've been warned!\n") if $enabled && !$disable;
}

sub disable_selinux {
    print_and_log("You've chosen to disable SELinux. Good choice.\n"); 
    my $full_path = can_run('setenforce');
    my $cmd = [$full_path,"0"]; #set SELinux in permissive mode
    my $success = run_command($cmd);      
    copy('/etc/selinux/config','/etc/selinux/config.bak')
	or die "Couldn't make a backup of /etc/selinux/config: $!";
    copy('conf/webwork_selinux_config','/etc/selinux/config')
	or die "Couldn't copy conf/webwork_selinux_config to /etc/selinux/config: $!";
    print_and_log(<<END);
######################################################
#
# I have set SELinux to permissive mode for this session
# and replaced /etc/selinux/config with a config file that
# will permanently disable selinux.
#
# After this installation completes, you must reboot the
# machine to permanently disable SELinux
#
####################################################### 
END
}

sub get_wwadmin_user {
    my $envir    = shift;
    my $print_me = <<END;
###########################################################################
#
# The first decision is whether or not to create a webwork admin user. 
# The purpose ofdoing this would be to allow the webwork admin user to 
# edit the webwork system code (e.g. for updates) while restricting 
# that user from having write access to other files outside of his 
# home directory.  If the system administrator(s) and webwork
# application maintainer(s) are the same then there is no need to 
# create this user.
#
# If the maintainer of webwork (the webwork administrator) is not the 
# system administrator for the server, then you as a user with root 
# access must decide how to give the webwork admin sufficient privileges 
# to maintain webwork.  One approach, depending on your OS, is to give 
# that user root access by either addiing that user to the wheel group 
# or the sudoers file. This gives the webwork administrator complete
# access to the system, but if that's fine with you then it's fine with 
# me too.
#
# The approach offered here is to create a webwork admin user and group. 
# All of the webwork code will be owned by this user.  The only webwork 
# files that will be writable by other users are those that must be 
# writable by the webserver. For those files and directories we will 
# create a new webwork data group to which we will add the 
# webwork admin user and the webserver.
#
# If you choose not to create this user, the webwork code will be owned 
# by root. We will still give you the opportunity to create the webwork 
# data group. Members of this group will be able to do limited webwork 
# maintenance tasks, such as creating courses from the command line and 
# managing logs, but will not be able edit webwork system files or other
# files that are writable by the webserver.
#
##########################################################################
END
    my $answer    = undef;
    my $confirmed = undef;
    my $exists    = undef;
    my $ww_admin  = undef;

    my $prompt = "Shall I create a webwork admin user?";
    $answer = $term->get_reply(
        print_me => $print_me,
        prompt   => $prompt,
        choices  => [
            "Yes, let's do it",
            "No, the root user will administer webwork",
            "No, a separate webwork admin user already exists"
        ],
        default => "Yes, let's do it",
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    #has this been confirmed?
    $confirmed = confirm_answer($answer);
    if ( $answer eq "Yes, let's do it" && $confirmed->{status} ) {
        $ww_admin = create_wwadmin_user($envir);
        return $ww_admin if $ww_admin;
        get_wwadmin_user($envir);    #Try again if not
    } elsif ( $answer eq "No, the root user will administer webwork"
        && $confirmed->{status} )
    {
        print
"Sounds good. We will not create a separate webwork admin user. The root user will administer webwork.\n";
        return "root";
    } elsif ( $answer eq "No, a separate webwork admin user already exists"
        && $confirmed->{status} )
    {
        $ww_admin = $term->get_reply(
            print_me =>
'Please enter the username of the webwork admin user. Note that this user must already exist on the system.',
            prompt  => 'webwork admin username:',
            default => 'wwadmin',
        );
	writelog($term->history_as_string()."\n");
	Term::UI::History->flush();

	$confirmed = confirm_answer($ww_admin);
        $exists = user_exists( $envir, $ww_admin );
        if ( $confirmed->{status} && $exists ) {
            return $ww_admin;
        } elsif ( !$exists ) {
            print_and_log("Hey, silly goose, that user doesn't exist!\n");
            get_wwadmin_user($envir);
        } else {
            print_and_log("You didn't cofirm your last answer so let's try again.\n");
            get_wwadmin_user($envir);
        }
    } else {
        print_and_log("Let's try again.\n");
        get_wwadmin_user($envir);
    }
}

sub create_wwadmin_user {
    my $envir   = shift;
    my $wwadmin = $term->get_reply(
        print_me => "You chose to create a webwork admin user.",
        prompt   => "Please enter a username for the webwork admin user.",
        default  => "wwadmin",
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    my $exists_already = user_exists( $envir, $wwadmin );
    if ($exists_already) {
        print_and_log("Sorry, that user already exists. Try again.\n");
        get_wwadmin_user($envir);
    } else {

        my $wwadmin_pw = $term->get_reply(
            prompt =>
              "Please enter an initial password for the webwork admin user.",
            default => "wwadmin",
        );
	writelog($term->history_as_string()."\n");
	Term::UI::History->flush();

	my $wwadmin_shell = $term->get_reply(
            prompt =>
              "Please enter a default shell for the webwork admin user.",
            default => $ENV{SHELL},
        );
	writelog($term->history_as_string()."\n");
	Term::UI::History->flush();

	my $confirm = $term->ask_yn(
            prompt =>
"Shall I create a webwork admin user with username $wwadmin, initial password"
              . " $wwadmin_pw and default shell $wwadmin_shell?",
            default => 'y',
        );
	writelog($term->history_as_string()."\n");
	Term::UI::History->flush();

        if ($confirm) {

   #useradd  -s /usr/bin/bash -c "WeBWorK Administrator" -p $wwadmin_pw $wwadmin
   #TODO: FreeBSD, MacOSX don't have useradd!!!
            my $full_path = can_run("useradd");
            my $cmd       = [ $full_path, '-m', #create user home dir
              '-s', $wwadmin_shell, #set default shell
              '-c', '"WeBWorK Administrator"',  #comment
              '-p', $wwadmin_pw, #password
              $wwadmin
            ];
            my $success = run_command($cmd);
            if ($success) {
                print_and_log("Created webwork admin user $wwadmin ".
                              "with initial password $wwadmin_pw and ".
                              "default shell $wwadmin_shell.\n");
                return $wwadmin;
            } else {
                print_and_log("There was an error creating $wwadmin\n");
                get_wwadmin_user($envir);
            }
        } else {
            print_and_log("Let's try again.\n");
            get_wwadmin_user($envir);
        }
    }

}

sub get_wwdata_group {
    my ( $envir, $apache, $wwadmin ) = @_;
    my $print_me = <<END;
########################################################################
#
# Certain data directories need to be writable by the webserver.  These 
# are the webwork2/DATA, webwork2/htdocs/tmp, webwork2/logs, 
# webwork2/tmp, and the courses/ directories.
#
# It can be convenient to give WeBWorK system administrators access to these 
# directories as well, so they can permform administrative tasks such as 
# removing temporary files, creating and editing courses from the command 
# line, managing logs, and so on.
#
# While it can be convenient to allow the WeBWorK administrator(s) to 
# manipulate the webwork files writable by the webserver, we may not 
# want to give him or her rights to manipulate other files writable by 
# the webserver.
#
# We can accomplish this by adding a new webwork data group to the 
# system containing any WeBWorK administrators and also containing 
# the web server. We will then recursively give the directories listed 
# above permissions g+sw and files in those directories g+w.
# 
# If you choose not to create the webwork data group, the webwork 
# directories listed above will be put into the same group as the 
# webserver. We will then recursively give those directories permissions 
# g+sw and the files in those directories permissions g+w.
#
########################################################################
END
    my $answer    = undef;
    my $confirmed = undef;
    my $exists    = undef;
    my $group     = undef;

    my $prompt = "Shall I create a webwork data group? ";
    $answer = $term->get_reply(
        print_me => $print_me,
        prompt   => $prompt,
        choices  => [
            "Yes, let's do it",
            "No, we'll just use the webserver's group",
            "No, a separate webwork data group already exists"
        ],
        default => "Yes, let's do it",
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    #has this been confirmed?
    $confirmed = confirm_answer($answer);
    if ( $answer eq "Yes, let's do it" && $confirmed->{status} ) {
        $group = create_wwdata_group( $envir, $apache, $wwadmin );
        return $group if $group;
        get_wwdata_group( $envir, $apache, $wwadmin );    #Try again if not
    } elsif ( $answer eq "No, we'll just use the webserver's group"
        && $confirmed->{status} )
    {
        print
"Sounds good. We will not create a separate webwork data group. Instead we'lljust use the webserver's group.\n";
        return $apache->{Group};
    } elsif ( $answer eq "No, a separate webwork data group already exists"
        && $confirmed->{status} )
    {
        $group = $term->get_reply(
            print_me =>
'Please enter the group name of the webwork data group. Note that this group must already exist on the system.',
            prompt  => 'webwork data group name: ',
            default => 'wwdata',
        );
	writelog($term->history_as_string()."\n");
	Term::UI::History->flush();

	$confirmed = confirm_answer($group);
        $exists = group_exists( $envir, $group );
        if ( $confirmed->{status} && $exists ) {
            return $group;
        } elsif ( !$exists ) {
            print "Hey, silly goose, that user doesn't exist!\n";
            get_wwdata_group( $envir, $apache, $wwadmin );    #Try again if not;
        } else {
            print "You didn't cofirm your last answer so let's try again.\n";
            get_wwdata_group( $envir, $apache, $wwadmin );    #Try again if not
        }
    } else {
        print "Let's try again.\n";
        get_wwdata_group( $envir, $apache, $wwadmin );        #Try again if not
    }
}

#Create webwork data group and add webserver and wwadmin (if user is not root)
sub create_wwdata_group {
    my ( $envir, $apache, $wwadmin ) = @_;
    my $group = $term->get_reply(
        print_me => "You chose to create a webwork data group.",
        prompt   => "What would you like to call the group?",
        default  => "wwdata",
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    #does this group exist?
    my $already_exists = group_exists( $envir, $group );
    if ($already_exists) {
        print "Oops - that group already exists. Let's try this again.\n";
        get_wwdata_group( $envir, $apache, $wwadmin );    #Try again if not
    } else {

        #group doesn't exist so now confirm answer
        my $confirmed = confirm_answer($group);
        copy( "/etc/group", "/etc/group.bak" );
        open( my $in, "<", "/etc/group.bak" )
          or die "Can't open /etc/group.bak for reading: $!";
        open( my $out, ">", "/etc/group" )
          or die "Can't open /etc/group for writing: $!";
        my @gids;
        while (<$in>) {
            push @gids, ( split( ':', $_ ) )[2];
            print $out $_;
        }
        my $new_gid = max(@gids) + 1;
        if ( $wwadmin eq 'root' ) {
            print $out "$group:*:$new_gid:" . $apache->{User} . "\n";
        } else {
            print $out "$group:*:$new_gid:" . $apache->{User} . ",$wwadmin\n";
        }
        return $group;
    }
}

##############################################################
#
# Adjust file ownership and permissions
#
#############################################################
#change_grp($server_groupid, $webwork_courses_dir, "$webwork_dir/DATA", "$webwork_dir/htdocs/tmp", "$webwork_dir/logs", "$webwork_dir/tmp");
#change_permissions($server_groupid, "$webwork_courses_dir", "$webwork_dir/DATA", "$webwork_dir/htdocs/tmp", "$webwork_dir/logs", "$webwork_dir/tmp");

#chgrp -R wwdata DATA ../courses htdocs/tmp logs tmp
# chmod -R g+w DATA ../courses htdocs/tmp logs tmp
# find DATA/ ../courses/ htdocs/tmp logs/ tmp/ -type d -a ! -name CVS -exec chmod g+s {}

sub change_owner {
    my $owner     = shift;
    my @dirs      = @_;
    my $full_path = can_run('chown');
    
    my $cmd       = [ $full_path, '-R', $owner, @dirs ];
    my $success = run_command($cmd);
    if ($success) {
        print_and_log("Changed ownership of @dirs and below to $owner.\n");
    } else {
        print_and_log("There was an error changing ownership of @dirs to $owner.\n");
    }
    
}

# chmod -R g+w DATA ../courses htdocs/tmp logs tmp
# find DATA/ ../courses/ htdocs/tmp logs/ tmp/ -type d -a ! -name CVS -exec chmod g+s {}
sub change_data_dir_permissions {
    my ( $gid, $courses, $data, $htdocs_tmp, $logs, $tmp, $webwork3log ) = @_;
    my $chmod = can_run('chmod');
    my $cmd =
      [ $chmod, '-R', 'g+w', $courses, $data, $htdocs_tmp, $logs, $tmp ];
    my $chmod_success = run_command($cmd);
    if ($chmod_success) {
        print_and_log("Made the directories \n $courses,\n $data,\n $htdocs_tmp,\n".
                      " $logs,\n $tmp\n group writable.\n");
    } else {
        print_and_log("Could not make the directories group writable!\n");
    }
    my $find = can_run('find');
    $cmd = [
        $find,    $courses, $data,  $htdocs_tmp, $logs,  $tmp,
        '-type',  'd',      '-and', '!',         '(',    '-name',
        '".git"', '-prune', ')',    '-exec',     $chmod, 'g+s',
        '{}',     ';'
    ];
    my $find_success = run_command($cmd);;
    if ($find_success) {
        print_and_log("Added group sticky bit to \n $courses,\n $data,\n $htdocs_tmp,\n $logs,\n".
                      " $tmp\n and subdirectories (except .git's).\n");
    } else {
        print_and_log("Error. Could not add sticky bit.\n");
    }
}

sub change_webwork3_log_permissions {
    my $owner     = shift;
    my $webwork3log = shift;

    my $full_path = can_run('chown');
    my $cmd       = [ $full_path, '-R', $owner, $webwork3log ];
    my $success = run_command($cmd);
    if ($success) {
        print_and_log("Changed ownership of $webwork3log to $owner.\n");
    } else {
        print_and_log("There was an error changing ownership $webwork3log to $owner.\n");
    }

    $full_path = can_run('chmod');
     $cmd =
	 [ $full_path, '-R', 'g+w', $webwork3log ];
    my $chmod_success = run_command($cmd);
    if ($chmod_success) {
        print_and_log("Made the directory $webwork3log group writable.\n");
    } else {
        print_and_log("Could not make $webwork3log group writable!");
    }
}

sub reset_tex_hash {
    my $full_path = can_run('texhash');
    my $cmd = [ $full_path ];
    my $texhash_success = run_command($cmd);
    if ($texhash_success) {
        print_and_log("Successfully ran texhash.\n");
    } else {
        print_and_log("Could not run texhash!");
    }
}
    
####################################################################
#
# Environment Data
#
# What use is this information?
# - any reason to get the hostname?
# - maybe warn against perl versions that are too old; version specific perl bugs?
# - maybe process timezone separately?
####################################################################

sub check_environment {
    print_and_log(<<EOF);
###################################################################
#
# Getting basic information about your environment 
#
##################################################################
EOF

    my $envir;
    $envir->{host} = hostname;
    print_and_log("And your hostname is " . $envir->{host} ."\n");
    $envir->{perl} = $^V;
    print_and_log("You're running Perl " . $envir->{perl} . "\n");
    #my $timezone = DateTime::TimeZone->new( name => 'local' );
    #$envir->{timezone} = $timezone->name;
    #print_and_log("Your timezone is " . $envir->{timezone});
    $envir->{os}          = get_os();
    $envir->{passwd_file} = "/etc/passwd" if -e "/etc/passwd";
    $envir->{group_file}  = "/etc/group" if -e "/etc/group";

    #we're going to get a list of users and groups on the system
    #for use later when we create our own users and groups. Also
    #to double check information, such as user and group for apache
    $envir->{existing_users}  = get_existing_users($envir);
    $envir->{existing_groups} = get_existing_groups($envir);

    return $envir;
}

sub check_apache {
    my ( $envir ) = @_;

    print_and_log(<<EOF);
###################################################################
#
# Gathering information about Apache
#
##################################################################
EOF

    my $apache;
    $apache->{binary} =
      File::Spec->canonpath( can_run('apache2ctl') || can_run('apachectl') )
      or die "Can't find Apache!\n";

    open( HTTPD, $apache->{binary} . " -V |" ) or die "Can't do this: $!";
    print_and_log("Your apache start up script is at " . $apache->{binary}."\n");

    #Get some information from apache2 -V
    while (<HTTPD>) {
        if ( $_ =~ /apache.(\d\.\d\.\d+)/i ) {
            $apache->{version} = $1;
            print_and_log("Your apache version is " . $apache->{version}."\n");
        } elsif ( $_ =~ /HTTPD_ROOT\=\"((\/\w+)+)\"$/ ) {
            $apache->{root} = File::Spec->canonpath($1);
            print_and_log("Your apache server root is " . $apache->{root}."\n");
        } elsif ( $_ =~ /SERVER_CONFIG_FILE\=\"((\/)?(\w+\/)*(\w+\.?)+)\"$/ ) {
            $apache->{conf} = File::Spec->canonpath($1);
            my $is_absolute =
              File::Spec->file_name_is_absolute( $apache->{conf} );
            if ($is_absolute) {
                next;
            } else {
                $apache->{conf} = File::Spec->canonpath(
                    $apache->{root} . "/" . $apache->{conf} );
            }
            print_and_log("Your apache config file is " . $apache->{conf}."\n");
        }
    }
    close(HTTPD);

    return $apache; 
}

sub get_apache_user_group {
    my ( $apache, $envir, $apacheLayout ) = @_;

#Determining apache user/group is hard. Sometimes it's in the main conf file.
#Here we check that, but maybe we should check all conf files under /etc/apache2?
    #Make sure we didn't get a bogus user/group from httpd.conf
    my $os_name = $envir->{os}->{name};
    my %users   = map { $_ => 1 } @{ $envir->{existing_users} };
    my %groups  = map { $_ => 1 } @{ $envir->{existing_groups} };
    unless (($apache->{User} && 
	 $apache->{Group}) &&
	($users{$apache->{User}} &&
	$groups{$apache->{Group}})) {

	open( HTTPDCONF, $apache->{conf} ) or die "Can't do this: $!";
	
	while (<HTTPDCONF>) {
	    if (/^User/) {
		( undef, $apache->{User} ) = split;
	    } elsif (/^Group/) {
		( undef, $apache->{Group} ) = split;
	    }
	}
	close(HTTPDCONF);
	
    }

    print_and_log("Apache runs as user " . $apache->{User} ."\n");
    print_and_log("Apache runs in group " . $apache->{Group}."\n");
    return $apache;
}


sub enable_mpm_prefork {
    my ( $apache, $envir ) = @_;

    return if (version->parse($apache->{version}) < version->parse('2.4.00'));

    if (can_run('a2enmod')) {
	my $a2enmod_cmd = ['a2dismod','mpm_event'];
	my $success = run_command($a2enmod_cmd);

	$a2enmod_cmd = ['a2enmod','mpm_prefork'];
	$success = run_command($a2enmod_cmd);

	print_and_log("Enabled MPM Prefork\n");
    }
}

sub check_apache_modules {
    my ( $apache, $envir ) = @_;
    my %module_hash;

    open( HTTPD, $apache->{binary} . " -M |" ) or die "Can't do this: $!";

    # check to see if mpm and fcgid are installed
    while (<HTTPD>) {
	foreach my $module (@apache2SharedModules) {
	    if (/$module/) {
		$module_hash{$module} = 1;
	    }
	}
    }

    close(HTTPD);

    foreach my $module (@apache2SharedModules) {
	if (!$module_hash{$module}) {
	    print_and_log("*Apache module $module not enabled!\n");
            die;
	}
    }
}

####################################################################
#
# Check for perl modules
#
###################################################################
# do we really want to eval "use $module;"?

sub check_modules {
    my @modulesList = @_;

    print_and_log("\nChecking your \@INC for modules required by WeBWorK...\n");
    my @inc = @INC;
    print_and_log("\@INC=");
    print join( "\n", map( "     $_", @inc ) ), "\n\n";

    foreach my $module (@modulesList) {
        eval "use $module";
        if ($@) {
            my $file = $module;
            $file =~ s|::|/|g;
            $file .= ".pm";
            if ( $@ =~ /Can't locate $file in \@INC/ ) {
                print_and_log("** $module not found in \@INC\n");
		die("Missing module.  Sorry! Try adding this module to your distribution file in distros.");
            } else {
                print_and_log("** $module found, but failed to load: $@\n");
		die("Missing module.  Sorry!  Try adding this module to your distribution file in distros.");
            }
        } else {
            print_and_log("   $module found and loaded\n");
        }
    }
}

######################################################
#
# Check for prerequisites and get paths for binaries
#
######################################################

sub configure_externalPrograms {

    #Expects a list of applications
    my @applicationsList = @_;
    print_and_log("\nChecking your system for executables required by WeBWorK...\n");

    my $apps;
    foreach my $app (@applicationsList) {
        $apps->{$app} = File::Spec->canonpath( can_run($app) );
        if ( $apps->{$app} ) {
            print_and_log("   $app found at ${$apps}{$app}\n");
            if ( $app eq 'lwp-request' ) {
	      delete $apps->{$app};
	      $apps->{checkurl} = "$app" . ' -d -mHEAD';
	    } elsif ($app eq 'curl' ) {
	      # why did this get called curlCommand and not just
	      # curl like every other gd thing. 
	      $apps->{curlCommand} = $apps->{$app};
	      delete $apps->{$app}
	    }		
        } else {
            print_and_log("** $app not found in \$PATH\n");
            die;
        }
    }
    my ( undef, $netpbm_prefix, undef ) =
      File::Spec->splitpath( ${$apps}{giftopnm} );
    $$apps{gif2eps} =
        "$$apps{giftopnm}" . " | "
      . $$apps{ppmtopgm} . " | "
      . $$apps{pnmtops}
      . " -noturn 2>/dev/null";
    $$apps{png2eps} =
        "$$apps{pngtopnm}" . " | "
      . $$apps{ppmtopgm} . " | "
      . $$apps{pnmtops}
      . " -noturn 2>/dev/null";
    $$apps{gif2png} = "$$apps{giftopnm}" . " | " . "$$apps{pnmtopng}";

    return $apps;
}

sub get_webwork2_repo {
    my $default  = shift;
    my $print_me = <<END;
#########################################################################
#
# There are two bundles of code to download that comprise webwork: The 
# 'webwork2' code constitutes the web application, and the 'pg' code 
# which defines the language in which webwork problems are written and 
# is responsible for translating webwork problem for display on the web 
# or in print, answer checking, etc.
#
# We're about to download that code and the WeBWorK Open Problem 
# Library.  Most users will want to download the code from the standard 
# github repositories.  But some users will want to use their own custom
# repositories.  Here we ask where you would like to download webwork2, 
# pg, and the OPL from.  To accept the defaults, and download the code 
# from the standard repositories, just hit enter. Otherwise, enter your 
# custom urls.  
#
#########################################################################
END

    my $repo = $term->get_reply(
        print_me => $print_me,
        prompt   => 'Where would you like to download webwork2 from?',
        default => $default,    #constant defined at top
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();
 
    #has this been confirmed?
    my $confirmed = 0;
    $confirmed = confirm_answer($repo);
    if ($confirmed->{status}) {
        print_and_log("Got it, I'll download webwork2 from $repo.\n");
        return $repo;
    } else {
        get_webwork2_repo($default);
    }
}

sub get_pg_repo {
    my $default = shift;
    my $repo    = $term->get_reply(

        #print_me => $print_me,
        prompt => 'Where would you like to download pg from?',
        default => $default,    #constant defined at top
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    #has this been confirmed?
    my $confirmed = 0;
    $confirmed = confirm_answer($repo);
    if ($confirmed->{status}) {
        print_and_log("Got it, I'll download pg from $repo.\n");
        return $repo;
    } else {
        get_pg_repo($default);
    }
}

sub get_opl_repo {
    my $default = shift;
    my $repo    = $term->get_reply(
        #print_me => $print_me,
        prompt  => 'Where would you like to download the OPL from?',
        default => $default,
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    #has this been confirmed?
    my $confirmed = 0;
    $confirmed = confirm_answer($repo);
    if ($confirmed->{status}) {
        print_and_log("Got it, I'll download the OPL from $repo.\n");
        return $repo;
    } else {
        get_opl_repo($default);
    }

}

sub is_absolute {
  my $dir = shift;
  $dir = File::Spec->canonpath($dir);
  my $is_absolute = File::Spec->file_name_is_absolute($dir);
  if($is_absolute) {
    return { answer => $dir, status => 1 };
  } else {
    my $abs_dir = File::Spec->rel2abs($dir);
    my $fix = $term->get_reply(
       print_me => "I need an absolute path, but you gave me a relative path.",
       prompt => "How do you want me to fix this? ",
       choices => [ "Go back", "I really meant $abs_dir", "Quit" ],
     );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

   if( $fix eq "Go back") {
     return { answer => $dir, status => 0 };
   } elsif( $fix eq "I really meant $abs_dir" ) {
     return { answer => $abs_dir, status => 1 }
   } elsif( $fix eq 'Quit' ) {
     die "Exiting...";
   }

  }
}

sub check_path {
    chomp(my $given = shift);
    my $exists = -e $given;
    return { answer => $given, status=> 1} unless $exists;
    
    my $reply = $term->get_reply( 
	print_me => "Error! You gave me a path which already exists on the filesystem.",       
	choices => ['Enter new location',"Delete existing $given and use that location","Quit"],
	prompt => 'How would you like to proceed?',
	default => 'Enter new location',
	); 
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();
    if($reply eq 'Enter new location') {
	return { answer=> $given, status => 0 };
    } elsif($reply eq "Delete existing $given and use that location") {
	return { answer=> $given, status => 1 };
    } elsif($reply eq "Quit") {
	die "Quitting..."
    }
}

sub get_WW_PREFIX {
    my $default  = shift;
    my $dir = get_reply({
    print_me => <<END,
#################################################################
# Installation Prefix: Please enter the absolute path of the directory
# under which we should install the webwork software. A typical choice
# is /opt/webwork/. We will create four subdirectories under your PREFIX:
#
# PREFIX/webwork2 - for the core code for the web-applcation
# PREFIX/pg - for the webwork problem generating language PG
# PREFIX/libraries - for the Open Problem Library and other problem 
# libraries
# PREFIX/courses - for the individual webwork courses on your server
#
# Note that we will also set a new system wide environment variable 
# WEBWORK_ROOT to PREFIX/webwork2/
#################################################################
END
    prompt => 'Where should I install webwork?',
    default=>$default,
    checkers => [\&is_absolute,\&check_path, \&confirm_answer],
  });
      print "Got it, I'll create $dir and install webwork there.\n";
      return $dir;
}


sub get_root_url {
    my $default  = shift;
    my $print_me = <<END;
#################################################################
# Server root url: Please enter the url of your webwork server. If you
# are just installing it locally for testing, you probabably want
#
# http://localhost
#
# If you are installing it for production use, then you should use the
# url users will go to for access to the application, something like
#
# http://webwork.math.yourschool.edu
#
# This script does not currently configure SSL.  Obviously, if this
# is for production use you'll want to use SSL. However, for now just
# use http and after you get the application running then come back and
# hook up ssl.
#################################################################
END
    my $answer = $term->get_reply(
        print_me => $print_me,
        prompt   => 'Server root url:',
        default  => $default,
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    #has this been confirmed?
    my $confirmed = confirm_answer($answer);
    if ($confirmed->{status}) {
        print_and_log("Thanks, got it, I'll use \"$answer\" \n");
        return $answer;
    } else {
        get_root_url($default);
    }
}

sub get_webwork_url {
    my $default  = shift;
    my $print_me = <<END;
#################################################################
# Location of the webwork handler: Please enter the location of the
# webwork handler relative to the server root url. A typical 
# choice for this is 
#
# "/webwork2"
#
# which means that the application will be found at
#
# http://webwork.math.yourschool.edu/webwork2
#
# given a server root url of http://webwork.math.yourschool.edu
#
# You might be tempted to put webwork on the server root, in which
# case you would enter "/".  However, we don't recommend this.
# Unless you really know what you are doing, just trust us and
# use "/webwork2".
#################################################################
END
    my $prompt = "Relative location of webwork handler:";
    my $answer = $term->get_reply(
        print_me => $print_me,
        prompt   => $prompt,
        default  => $default,
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    #has this been confirmed?
    my $confirmed = confirm_answer($answer);
    if ($confirmed->{status}) {
        print_and_log("Thanks, got it, I'll use \"$answer\" \n");
        return $answer;
    } else {
        get_webwork_url($default);
    }
}

########################################################################
#
#Configure the %mail hash
#
########################################################################

sub get_smtp_server {
    my $default  = shift;
    my $print_me = <<END;
#################################################################
# SMTP Server:  Maybe something like 'mail.yourschool.edu'.  If
# you're not sure 'localhost' is a good choice. 
#################################################################
END
    my $prompt = "SMTP server:";
    my $answer = $term->get_reply(
        print_me => $print_me,
        prompt   => $prompt,
        default  => $default,
    );

    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    #has this been confirmed?
    my $confirmed = confirm_answer($answer);
    if ($confirmed->{status}) {
        print_and_log("Thanks, got it, I'll use \"$answer\" \n");
        return $answer;
    } else {
        get_smtp_server($default);
    }
}

sub get_smtp_sender {
    my $default  = shift;
    my $print_me = <<END;
########################################################################
#
# SMTP Sender:  Maybe something like 
#       'webwork\@yourserver.yourschool.edu'. 
# If you're not setting this up right now, 'webwork\@localhost' is fine.
#
#########################################################################
END
    my $prompt = "SMTP sender:";
    my $answer = $term->get_reply(
        print_me => $print_me,
        prompt   => $prompt,
        default  => $default,
    );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();

    #has this been confirmed?
    my $confirmed = confirm_answer($answer);
    if ($confirmed->{status}) {
        print_and_log("Thanks, got it, I'll use \"$answer\" \n");
        return $answer;
    } else {
        get_smtp_server($default);
    }
}

#####################################################################
#
#Configure the database
#
#####################################################################


sub get_database_password {
    my $print_me = <<END;
######################################################################
#
# Now we need a password to identify the webwork database user.  Note 
# that this password will be written into one of the (plain text) 
# config files in webwork2/conf/.  So, it's important for security 
# that this password not be the same as the mysql root password.
#
# If you created a new database and a new database user, then you can 
# enter any password you like here.
#
# If you are using an existing database and db user, then we are 
# expecting you to use the existing password for that user.
#
######################################################################
END
    my $prompt = "Please enter webwork database password:";
    my $answer = get_reply({
      print_me => $print_me,
      prompt => $prompt,
    });
}

sub get_database_username {
    my $default  = shift;
    my $print_me = <<END;
######################################################################
#
# Now we need new mysql user with the necessary privileges on the 
# webwork database. For maximum security, this user should have no 
# privileges on other tables.  So, 'root' is a bad choice. 
#
# If you created a new webwork database, we suggest creating a new 
# user for that database. In that case, we will give that user the 
# appropriate privileges. 
#
# If you are using an existing database, we are expecting you to 
# also use an existing database user here and we are expecting that 
# this database user has appropriate privileges on that database.
#
#####################################################################
END
    my $prompt = "webwork database username:";
    my $answer = get_reply({
        print_me => $print_me,
        prompt => $prompt,
        default => $default,
      });
}

sub get_mysql_root_password {

  print_and_log(<<END);
####################################################################
#
# Please enter the root mysql password. 
#
####################################################################

END
    my $password;
    while(1) {
      my $double_check;
      $password = read_password('MySQL root password: ');
      $double_check = read_password('Please confirm MySQL root password: ') if $password;
      if($password eq $double_check)  {
          print_and_log("MySQL root password confirmed.\n\n");
          last;
       } else {
          print_and_log("Sorry, the passwords you entered did not match.\n\n");
          redo;
        }
    }
    return $password;
}

sub get_storage_engine {
    my $print_me = <<END;
#############################################################
#  
#  The default engine for MySQL is InnoDB as of MySQL 5.5.5 
#  (MyISAM before 5.5.5) but (at least on some hardware) InnoDB 
#  seems to be 50-100 times slower than MyISAM. So we recommend
#  changing the default MySQL storange engine from InnoDB to 
#  MyISAM. Note that this change only applies to new tables, 
#  tables already constructed will continue to use InnoDB. 
#  But we haven't created any WeBWorK tables so we don't have 
#  to change the engine for any existing tables.  
#
##############################################################
END
    my $prompt = "Change default mysql storage engine to MyISAM?";
    my $engine= $term->ask_yn(
        print_me => $print_me,
        prompt => $prompt,
        default => 'y',
      );
    writelog($term->history_as_string()."\n");
    Term::UI::History->flush();
    
    my $confirmed = confirm_answer($engine);
    if($confirmed->{answer} && $confirmed->{status}) {
        change_storage_engine('/etc/mysql/my.cnf'); #this should be searched for
    } else {
        print_and_log("OK. We won't modify MySQL's default storage engine\n");
    }
}
# Is there an existing webwork db or would you like me to create one?

sub get_webwork_database {

    # start by initializing the database interface.  We wait until now because
    # it uses some of the installed prereqs.
    initialize_dbi();
    
    my $print_me = <<END;
#############################################################
#  We now need to designate a MySQL database and database user
#  for webwork.  First we need to know which server hosts your
#  MySQL database and the port through which we can access it.
#  The answer will be of the form 'serverName:port'. If your
#  MySQL server is on this machine, your server name is 
#  'localhost'.  You may omit the port number if your MySQL 
#  server is listening on the dfault port of 3306.
#############################################################
END
    my $prompt = "Please enter the MySQL server and port ";
    my $choices = [];
    my $default = 'localhost';
    my $server = get_reply({
        print_me => $print_me,
        prompt => $prompt,
        default => $default,
      });
    $print_me = <<END;
##############################################################
#
#  If you would like me to create a new database and user for 
#  webwork, you will need ot know the root mysql password.
#
#  If such a database and mysql user has already been created, 
#  you will need to know (a) the name of the database, (b) the 
#  name and password of the mysql user with the appropriate 
#  privileges on that database.
#
###############################################################
END
    $prompt = "Create a new database or use an existing one? ";
    $choices = ['Create a new database','Use an existing database'];
    $default = 'Create a new database';
    my $new_or_existing = get_reply({
        print_me => $print_me,
        prompt => $prompt,
        choices => $choices,
        default => $default
      });     
    if($new_or_existing eq 'Create a new database') {
      print_and_log(<<END);
###################################################################
#
# Great, we'll create a new mysql database for webwork. To do so
# we'll need the root mysql password.
#
###################################################################
END
      my $mysql_root_password = get_mysql_root_password();
      my $print_me =<<END;
######################################################################
#
# Thanks. I'll keep it secret. Please choose a name for the webwork 
# database. It can be anything that conforms to mysql's rules for 
# database names.  If you don't know those, just be sensible and 
# things will probably be ok. (Or look up the rules if you are 
# inclined to be unsensible.)  Also, you can't choose something 
# that is the name of an existing mysql database.
#
######################################################################
END
      my $prompt = "Name for the webwork database:";
      my $database = get_reply({
          print_me => $print_me,
          prompt => $prompt,
          default => WW_DB,
        });
      my $exists = database_exists($mysql_root_password,$database,$server);
      if($exists) {
        print_and_log("\n\nSorry, Charlie. That database already exists. Let's try".
          " this again.\n\n");
        sleep(2);
        get_webwork_database();
      } else {
        my $username = get_database_username(WWDB_USER);
        my $password = get_database_password();
        create_database( $server, $mysql_root_password, $database,
            $username, $password );
        return ($database,$server,$username,$password);
      }
    } elsif($new_or_existing eq 'Use an existing database') {
      my $print_me =<<END;
###################################################################
# Ok, we can use an existing database.
####################################################################
END
      my $prompt = "Name of the existing webwork database:";
      my $database = get_reply({
        print_me => $print_me,
        prompt => $prompt,
        default => WW_DB,
      });
      my $username = get_database_username(WWDB_USER);
      my $password = get_database_password();
      my $can_connect = connect_to_database($server,$database,$username,$password);
      return ($database,$server,$username,$password) if $can_connect;
      get_webwork_database(WW_DB);
    } else {
      get_webwork_database(WW_DB);
    }
}

#############################################################
#
# Put software in correct location, write configuration files
#
#############################################################

#####################################################################
#
# Create prefix path
#
######################################################################

sub create_prefix_path {
    my $dir = shift;
    remove_tree($dir,{ verbose => 1 }) if -e $dir;
    make_path($dir, {error => \my $err} );
         if (@$err) {
             for my $diag (@$err) {
                 my ($file, $message) = %$diag;
                 if ($file eq '') {
                     print_and_log("General error: $message\n");
                 }
                 else {
                     print_and_log("Problem creating $file: $message\n");
                 }
             }
         }
         else {
             print_and_log("Created $dir. No error encountered.\n");
         }
}

########################################################################
#
# Get the software, put it in the correct location
#
########################################################################

sub get_webwork {
    my ( $prefix, $apps, $wwadmin ) = @_;
    create_prefix_path($prefix);
    chdir $prefix or die "Can't chdir to $prefix";
    my $ww2_repo =
      get_webwork2_repo(WEBWORK2_REPO);   #WEBWORK2_REPO constant defined at top
    my $ww2_cmd = [$apps->{git},'clone',$ww2_repo];

    my $pg_repo = get_pg_repo(PG_REPO);    #PG_REPO constant defined at top
    my $pg_cmd = [$apps->{git},'clone',$pg_repo];

    my $opl_repo = get_opl_repo(OPL_REPO);    #OPL_REPO constant defined at top
    my $opl_cmd = [$apps->{git},'clone',$opl_repo];

    my $buffer;
    my $ww2_success = run_command($ww2_cmd);

    if ($ww2_success) {
        print_and_log("Fetched webwork2 successfully.\n");
        chdir "$prefix/webwork2";
	if (CHECKOUT_BRANCH) {
	    run_command(['git','checkout',WW_BRANCH]);
	}
        chdir $prefix;
    } else {
        print_and_log("Couldn't get webwork2!\n");
    }
    my $pg_success = run_command($pg_cmd);
    if ($pg_success) {
        print_and_log("Fetched pg successfully!\n");
	chdir "$prefix/pg";
	if (CHECKOUT_BRANCH) {
	    run_command(['git','checkout',PG_BRANCH]);
	}
	chdir $prefix;
    } else {
        print_and_log("Couldn't get pg!\n");
    }

    make_path( 'libraries', { owner => $wwadmin, group => $wwadmin } );
    make_path( 'courses',   { owner => $wwadmin, group => $wwadmin } );
    chdir "$prefix/libraries";

    my $opl_success = run_command($opl_cmd);;
    if ($opl_success) {
        print_and_log("Fetched OPL successfully\n");
    } else {
        print_and_log("Couldn't get OPL!\n");
    }
}

#############################################################
#
# Unpack jsMath fonts
#
#############################################################

sub unpack_jsMath_fonts {
    my $webwork_dir = shift;
    
    # check if jsMath even exists, since it doesn't anymore
    return if (!(-e "$webwork_dir/htdocs/jsMath/jsMath-fonts.tar.gz"));

    # cd /opt/webwork/webwork2/htdocs/jsMath
    chdir("$webwork_dir/htdocs/jsMath");
    system("tar vfxz jsMath-fonts.tar.gz");
    my $cmd = ["tar","vfxz","jsMath-fonts.tar.gz"];
    my $success = run_command($cmd);
    if ($success) {
        print_and_log("Unpacked jsMath fonts successfully!\n");
    } else {
        print_and_log("Could not unpack jsMath fonts! Maybe it doesn't matter.\n");
    }
    
}

sub get_MathJax {
    my $WW_PREFIX = shift;
    chdir($WW_PREFIX);

    my $full_path = can_run('git');
    #As of ww2.8, MathJax is no longer a git submodule.
    #pre-2.8 code: 
    #command: system("git submodule update --init");
    #my $cmd = [ $full_path, 'submodule', "update", "--init" ];

    my $cmd = [ $full_path, 'clone', MATHJAX_REPO];
    my $success = run_command($cmd);
    if ($success) {
        print_and_log("Downloaded MathJax to $WW_PREFIX/MathJax\n");
	# switch to MathJax 2 since MathJax 3 is not yet supported
	my $cmd2 = [ $full_path, 'checkout', 'legacy-v2' ];
	my $success2 = run_command($cmd2);
	if ($success2) {
	    print_and_log("Switched to MathJax v2\n");
	} else {
	    print_and_log("Could not checkout MathJax version 2.  You'll have to do this manually.\n");
	}
    } else {
        print_and_log("Could not download MathJax. You'll have to do this manually.\n");
    }
}

#copy("adminClasslist.lst","$prefix/courses/adminClasslist.lst");
#copy("defaultClasslist.lst","$prefix/courses/defaultClasslist.lst");
sub copy_classlist_files {
    my ( $webwork_dir, $courses_dir ) = @_;
    copy( "$webwork_dir/courses.dist/adminClasslist.lst",
        "$courses_dir/adminClasslist.lst" )
      or warn
"Couldn't copy $webwork_dir/courses.dist/adminClasslist.lst to $courses_dir."
      . " You'll have to copy this over manually: $!";
    print_and_log("Copied adminClasslist.lst to $courses_dir\n");
    copy( "$webwork_dir/courses.dist/defaultClasslist.lst", "$courses_dir" )
      or warn
"Couldn't copy $webwork_dir/courses.dist/defaultClasslist.lst to $courses_dir."
      . " You'll have to copy this over manually: $!";
    print_and_log("Copied defaultClasslist.lst file to $courses_dir\n");
}

sub symlink_model_course {
    my ( $webwork_dir, $courses_dir ) = @_;
    my $full_path = can_run('ln');
    my $dist_path =
      File::Spec->canonpath( $webwork_dir . '/courses.dist/modelCourse' );
    my $link_path = File::Spec->canonpath( $courses_dir . '/modelCourse' );
    my $cmd = [ $full_path, '-s', $dist_path, $link_path ];
    my $success = run_command($cmd);
    if ($success) {
        print_and_log("Symlinked $webwork_dir/courses.dist/modelCourse to $courses_dir/modelCourse\n");
    } else {
        print_and_log("Could not symlink $webwork_dir/courses.dist/modelCourse to $courses_dir/modelCourse. ".
                      "You'll have to do this manually: $!\n");
    }
}


#############################################################
#
#  Write config files
#
############################################################

sub write_database_conf {
    my $conf_dir = shift;
    copy( "$conf_dir/database.conf.dist", "$conf_dir/database.conf" )
      or die "Can't copy database.conf.dist to database.conf: $!";
}

sub write_site_conf {
    my (
        $WW_PREFIX,         $conf_dir,          $webwork_url,
        $server_root_url,   $apache,            $database_dsn,
        $database_username, $database_password, $apps,
	$mail
    ) = @_;
    open( my $in, "<", "$conf_dir/site.conf.dist" )
      or die "Can't open $conf_dir/site.conf.dist for reading: $!";
    open( my $out, ">", "$conf_dir/site.conf" )
      or die "Can't open $conf_dir/site.conf for writing: $!";
    while (<$in>) {
        if (/^\$webwork_url/) {
            print $out "\$webwork_url = \"$webwork_url\";\n";
        } elsif (/^\$server_root_url/) {
            print $out "\$server_root_url = \"$server_root_url\";\n";
        } elsif (/^\$server_userID/) {
            print $out "\$server_userID = \"" . $apache->{User} . "\";\n";
        } elsif (/^\$server_groupID/) {
            print $out "\$server_groupID = \"" . $apache->{Group} . "\";\n";
        } elsif (/^\$database_dsn/) {
            print $out "\$database_dsn = \"$database_dsn\";\n";
        } elsif (/^\$database_username/) {
            print $out "\$database_username = \"$database_username\";\n";
        } elsif (/^\$database_password/) {
            print $out "\$database_password = \'$database_password\';\n";
        } elsif (/^\$externalPrograms\{(\w+)\}/) {
	    next if ( $1 =~ /tth/ );
	    print $out "\$externalPrograms{$1} = \"$$apps{$1}\";\n";
	} elsif (/^\$pg_dir/) {
            print $out "\$pg_dir = \"$WW_PREFIX/pg\";\n";
        } elsif (/^\$webwork_courses_dir/) {
            print $out "\$webwork_courses_dir = \"$WW_PREFIX/courses\";\n";
        } elsif (/^\$mail\{smtpSender\}/) {
            print $out "\$mail{smtpSender} = \"$mail->{smtpSender}\";\n";
        } elsif (/^\$mail\{smtpServer\}/) {
            print $out "\$mail{smtpServer} = \"$mail->{smtpServer}\";\n";
        } else {
            print $out $_;
        }
    }
}

sub write_localOverrides_conf {
    my ( $WW_PREFIX, $conf_dir ) = @_;
    open( my $in, "<", "$conf_dir/localOverrides.conf.dist" )
      or die "Can't open $conf_dir/localOverrides.conf.dist for reading: $!";
    open( my $out, ">", "$conf_dir/localOverrides.conf" )
      or die "Can't open $conf_dir/localOverrides.conf for writing: $!";
    while (<$in>) {
        if (/^\$problemLibrary\{root\}/) {
            print $out "\$problemLibrary{version} = \"2.5\";\n";
            print $out
"\$problemLibrary{root} = \"$WW_PREFIX/libraries/webwork-open-problem-library/OpenProblemLibrary\";\n";
        } elsif (/^\$pg\{options\}\{displayMode\}/) {
            print $out "\$pg{options}{displayMode} = \"MathJax\";\n";
        } else {
            print $out $_;
        }
    }
}

sub write_webwork3_conf {
    my ( $WW_PREFIX, $DB_PWD, $conf_dir ) = @_;
    open( my $in, "<", "$conf_dir/webwork3.conf.dist" )
      or die "Can't open $conf_dir/localOverrides.conf.dist for reading: $!";
    open( my $out, ">", "$conf_dir/webwork3.conf" )
      or die "Can't open $conf_dir/webwork3.conf for writing: $!";
    while (<$in>) {
        if (/^webwork_dir/) {
            print $out "webwork_dir: \"${WW_PREFIX}/webwork2\"\n";
        } elsif (/^pg_dir/) {
            print $out "pg_dir: \"${WW_PREFIX}/pg\"\n";
	} elsif (/^\s+password/) {
            print $out "        password: '$DB_PWD'\n";
        } else {
            print $out $_;
        }
    }
}

sub write_webwork_apache2_config {
    my $webwork_dir = shift;
    my $config_file = shift;
    my $conf_dir    = "$webwork_dir/conf";
    open( my $in, "<", "$conf_dir/${config_file}.dist" )
      or die "Can't open $conf_dir/${config_file}.dist for reading: $!";
    open( my $out, ">", "$conf_dir/${config_file}" )
      or die "Can't open $conf_dir/${config_file} for writing: $!";
    while (<$in>) {
        next if /^\#/;
        if (/^my\s\$webwork_dir/) {
            print $out "my \$webwork_dir = \"$webwork_dir\";\n";
        } else {
            print $out $_;
        }
    }
}

sub edit_httpd_conf {
  my $apache = shift;
  my $httpd_conf = $apache->{conf};

  my (undef,$dir,$file) = File::Spec->splitpath($httpd_conf);

  my $print_me = <<END;
#######################################################################
#
# Next, I would like to increase apache's page timout value from 300
# to 1200. 
#
#######################################################################
END
  my $prompt = "Please enter a value for Timeout:";
  my $default = 1200;
  my $timeout = get_reply({
      print_me => $print_me,
      prompt => $prompt,
      default => $default,
    });

   
  #Make a backup copy of the apache config file
  copy($httpd_conf,$dir."/".$file.".bak")
    or die "Couldn't copy $httpd_conf to ".$dir.$file.".bak: $!\n";
  print_and_log("Backed up $httpd_conf to ".$dir.$file.".bak\n");

  #Open apache config file for reading 
  open(my $fh, '<',$httpd_conf)
    or die "Couldn't open $httpd_conf for reading: $!\n";
  #read it into a string
  my $string = do { local($/); <$fh> };
  close($fh);

  #Make replacements
  if ($string =~ /(Timeout\s+\d+)/s) {
   $string =~ s/$1/Timeout $timeout/;
  } else {
   $string .= "\nTimeout $timeout\n";
  }

  #Open apache config file for writing and write!
  open($fh, '>',$httpd_conf)
    or die "Couldn't open $httpd_conf for writing: $!\n";
  print $fh $string;
  print_and_log("Set Timeout $timeout in $httpd_conf\n");
  close($fh);
}


sub edit_mpm_conf {
  my $apache = shift;
  my $httpd_conf = $apache->{MPMConfFile} || $apache->{conf};

  my (undef,$dir,$file) = File::Spec->splitpath($httpd_conf);

  my $print_me = <<END;

###################################################################
#
# Now I would like to modify the prefork MPM
# settings MaxClients and MaxRequestsPerChild. By default I'll change 
# MaxClients from 150 to 20 and MaxRequestsPerChild from 0 to 50.
#
# For WeBWorK a rough rule of thumb is 5 MaxClients per 1 GB of 
# memory.  So, e.g., if you have 4GB of RAM you may want to use
# MaxClients 20.
# 
######################################################################
END
  my $prompt = "Please enter a value for prefork MaxClients/MaxRequestWorkers:";
  my $default = 20;
  my $max_clients = get_reply({
      print_me => $print_me,
      prompt => $prompt,
      default => $default,
    });

  $prompt = "Please enter a value for prefork MaxRequestsPerChild/MaxConnectionsPerChild:";
  $default = 50;
  my $max_requests_per_child = get_reply({
      prompt => $prompt,
      default => $default,
    });

  #Make a backup copy of the apache config file
  copy($httpd_conf,$dir."/".$file.".bak")
    or die "Couldn't copy $httpd_conf to ".$dir.$file.".bak: $!\n";
  print_and_log("Backed up $httpd_conf to ".$dir.$file.".bak\n");

  #Open apache config file for reading 
  open(my $fh, '<',$httpd_conf)
    or die "Couldn't open $httpd_conf for reading: $!\n";
  #read it into a string
  my $string = do { local($/); <$fh> };
  close($fh);

  my $clients_directive = 'MaxClients';
  my $request_directive = 'MaxRequestsPerChild';

  if (version->parse($apache->{version}) >= version->parse('2.4.00')) {
      $clients_directive = 'MaxRequestWorkers';
      $request_directive = 'MaxConnectionsPerChild';
  }

  if($string =~ /\<IfModule (mpm\_prefork\_module|prefork\.c)\>.*?($clients_directive\s+\d+).*?\<\/IfModule\>/s) {
    $string =~ s/$2/$clients_directive           $max_clients/;
  } else {
      $string .= "\n $clients_directive           $max_clients\n";
  }
  if($string =~ /\<IfModule (mpm\_prefork\_module|prefork\.c)\>.*?($request_directive\s*\d+).*?\<\/IfModule\>/s) {
    $string =~ s/$2/$request_directive $max_requests_per_child/;
  } else {
      $string .= "\n $request_directive           $max_requests_per_child\n";
  }

  #Open apache config file for writing and write!
  open($fh, '>',$httpd_conf)
    or die "Couldn't open $httpd_conf for writing: $!\n";
  print $fh $string;
  print_and_log("Set prefork $clients_directive $max_clients in $httpd_conf\n");
  print_and_log("Set prefork $request_directive $max_requests_per_child in $httpd_conf\n");
  close($fh);
}

##########################################################
#
#  Configure environment (symlink webwork-apache2.config,
#  set path, WEBWORK_ROOT
#
##########################################################

sub configure_shell {
    my ($WW_PREFIX, $wwadmin) = @_;

    #We want to configure the shell of the wwadmin user, root, and the user that logged in.
    #export PATH=$PATH:/opt/webwork/webwork2/bin
    #export WEBWORK_ROOT=/opt/webwork/webwork2
    
    my @users = ('root',$wwadmin);

    push(@users,$ENV{SUDO_USER}) if $ENV{SUDO_USER};
    
    my @unique = do { my %seen; grep { !$seen{$_}++ } @users };
    foreach(@unique) {
        #Remember that we used User::pwent which overrides the builtin pw* functions. 
        my $pw  = getpwnam($_);
        my $dir = $pw->dir;
        if (-f "$dir/.bashrc") {
            copy("$dir/.bashrc","$dir/.bashrc.bak");
            open(my $bashrc,'>>',"$dir/.bashrc" ) or warn "Couldn't open $dir/.bashrc: $!";
            print $bashrc "export PATH=\$PATH:$WW_PREFIX/webwork2/bin\n";
            print_and_log("Added 'export PATH=\$PATH:$WW_PREFIX/webwork2/bin' to $dir/.bashrc\n");
            print $bashrc "export WEBWORK_ROOT=$WW_PREFIX/webwork2\n";
            print_and_log("Added 'export WEBWORK_ROOT=$WW_PREFIX/webwork2' to $dir/.bashrc\n");
            close($bashrc);
        }
        $ENV{'WEBWORK_ROOT'}="$WW_PREFIX/webwork2";
    }
}

sub setup_opl {
    my $WW_PREFIX = shift;
    symlink(
        "$WW_PREFIX/libraries/webwork-open-problem-library/OpenProblemLibrary",
        "$WW_PREFIX/courses/modelCourse/templates/Library"
    );
    system("$WW_PREFIX/webwork2/bin/OPL-update");

    #$ cd /opt/webwork/courses/modelCourse/templates/
    #$ sudo ln -s /opt/webwork/libraries/NationalProblemLibrary Library
    #cd /opt/webwork/libraries/NationalProblemLibrary
    #$ NPL-update ## after write config files since must have $db_pass
}

#############################################################
#
# Create admin course
#
############################################################

sub create_admin_course {
    my $WW_PREFIX = shift;

    # cd /opt/webwork/courses
    chdir("$WW_PREFIX/courses");
    system(
"$WW_PREFIX/webwork2/bin/addcourse admin --db-layout=sql_single --users=$WW_PREFIX/courses/adminClasslist.lst --professors=admin"
    );
}


sub install_chromatic {
  my $pg_dir = shift;

  chdir("$pg_dir/lib/chromatic");

  my $color_dot_c = File::Spec->canonpath("$pg_dir/lib/chromatic/color.c");
  #should now check that this really exists 

  my $gcc = can_run('gcc')
    or die "Can't find gcc - please install it and try again.";

  #gcc -O3 color.c -o color
  chdir("$pg_dir/lib/chromatic/");

  my $cmd = ['gcc','-O3',$color_dot_c,'-o','color']; #should be an array reference

  my $success = run_command($cmd);
  if ($success) {
    print_and_log("Compiled $color_dot_c.\n"); 
  } else {
      print_and_log("Couldn't compile $color_dot_c.\n");
  }
}

#############################################################
#
# Restart apache and launch web-browser!
#
#############################################################

sub restart_apache {
    my $apache = shift;
    my $cmd = [ $apache->{binary}, 'restart' ];
    my $success = run_command($cmd);;
    if ($success) {
        print_and_log("Apache successfully restarted.\n");
    } else {
        print_and_log("Could not restart apache.\n");
    }
}

sub write_launch_browser_script {
    my ( $dir, $url ) = @_;

    #We want to open the browser as the user that logged in, not root if
    #using sudo. 
    my $username = $ENV{SUDO_USER} || $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);

   #Remember that we used User::pwent which overrides the builtin pw* functions.
    my $pw  = getpwnam($username);
    my $uid = $pw->uid;
    my $gid = $pw->gid;

    #Now we need to get back to starting dir
    chdir $dir;

    #Get preferred web browser
    my $browser =
         can_run('xdg-open')
	 || can_run('x-www-browser')
      || can_run('www-browser')
      || can_run('gnome-open')
      || can_run('firefox');
    return unless $browser;
    open( my $out, ">", "launch_browser.sh" )
      or die "Can't open launch_browser.sh: $!";
    print $out "#!/usr/bin/env bash\n\n";
    print $out "su -c \"$browser $url\" $username\n";
    close($out);
    chown $uid, $gid, "launch_browser.sh";
}

###############################################################
#
# Now we finally come to the actual installation procedure
#
###############################################################

#We'll use this later
my $installer_dir = getcwd();

#Check if user is ready to install webwork
get_ready();

#Check if user is running script as root
check_root();

#Deal with SELinux
get_selinux();

#Get os, host, perl version, timezone
my $envir = check_environment();
my %siteDefaults;
#$siteDefaults{timezone} = $envir->{timezone};

my $osPackage = $envir->{os}->{osPackage};

# get os package
get_os_package($envir->{os});

# run hooked code
$osPackage->prepreq_hook();

#Install Prerequisites
install_prerequisites({osPackage => $osPackage})
    unless SKIP_INSTALL_PREREQUISITES;

# run hooked code
$osPackage->postpreq_hook();

#Get apache version, path to config file, server user and group;
my $apache = check_apache( $envir );

#Put the information from the layout in the apache object;
my $layout = $osPackage->get_apacheLayout();

foreach my $key (keys %$layout) {
    $apache->{$key} = $layout->{$key};
}

#enable mpm prefork
enable_mpm_prefork($apache);

#check and see if our modules are enabled
check_apache_modules($apache,$envir);

#get the apache user and group, eithe from the layout or from the system
$apache = get_apache_user_group($apache,$envir);

my $server_userID  = $apache->{User};
my $server_groupID = $apache->{Group};

#Check perl prerequisites
print_and_log(<<EOF);
###################################################################
#
# Checking for required perl modules and external programs...
#
# #################################################################
EOF

no strict;

my @modules = @{$osPackage.'::modulesList'};

@modules = @modulesList unless @modules;

my @apacheModules = @{$osPackage.'::apache2ModulesList'};

@apacheModules = @apache2ModulesList unless @apacheModules;

use strict;

check_modules(@modules);

check_modules(@apacheModules);

#Check binary prerequisites
my $apps = configure_externalPrograms(@applicationsList);

#run hooked coe
$osPackage->preconfig_hook();



#Get directory root PREFIX, download software, and configure filesystem locations for webwork software
my $WW_PREFIX = get_WW_PREFIX(WW_PREFIX);    #constant defined at top

#== Top level determined from PREFIX ==
my $webwork_dir         = "$WW_PREFIX/webwork2";
my $pg_dir              = "$WW_PREFIX/pg";
my $webwork_courses_dir = "$WW_PREFIX/courses";
my $webwork_htdocs_dir  = "$webwork_dir/htdocs";
$ENV{WEBWORK_ROOT} = $webwork_dir;

print_and_log(<<EOF);
########################################################################
#
#  At this point we need to make some access control decisions. 
#  These decisions are important because they directly impact 
#  application and system security.  But, the right answers often 
#  depend on a mix of factors, such as
#  - institutional and/or departmental policies,
#  - the level of involvement and expertise of the application 
#    owner(s) and the system administrator(s)
#  - personal preferences and intended workflows 
#
#  Here we offer the option of creating a webwork admin user and 
#  a webwork data group, for four different access control options.  
#  If none of these four options fit your situation, then you should 
#  select one now with the intention of tweaking it manually after 
#  this script exits.
#
#  Let's first deal with the webwork admin user, and then the webwork 
#  data group.  
#
#########################################################################
EOF

my $wwadmin = get_wwadmin_user($envir);
my $wwdata = get_wwdata_group( $envir, $apache, $wwadmin );

#(3) $server_root_url   = "";  # e.g.  http://webwork.yourschool.edu
#$webwork_url         = "/webwork2";
#$server_root_url   = "";   # e.g.  http://webwork.yourschool.edu or localhost

my $server_root_url    = get_root_url(ROOT_URL);     #constant defined at top
my $webwork_url        = get_webwork_url(WW_URL);    #constant defined at top
my $webwork_htdocs_url = "/webwork2_files";

#Configure mail settings
#(4) $mail{smtpServer}            = 'mail.yourschool.edu';
#(5) $mail{smtpSender}            = 'webwork@yourserver.yourschool.edu';
my %mail;
$mail{smtpServer} = get_smtp_server(SMTP_SERVER);    #constant defined at top
$mail{smtpSender} = get_smtp_sender(SMTP_SENDER);    #constant defined at top

#(6) database root password
#(7) $database_dsn = "dbi:mysql:webwork";
#(8) $database_username = "webworkWrite";
#(9) $database_password = "";
require WeBWorK::Install::Database;

my ($ww_db,$database_server,$database_username,$database_password) = get_webwork_database(WW_DB);  #constant defined at top

my $database_dsn        = get_dsn($ww_db,$database_server);

get_storage_engine();

print_and_log(<<EOF);
#######################################################################
#
#  Now I'm going to download the webwork code.  This will take a couple
#  of minutes.
# 
######################################################################
EOF
get_webwork( $WW_PREFIX, $apps );

print_and_log(<<EOF);
#######################################################################
#
#
# Now we will download MathJax.
#
# This too may take awhile
#
# 
######################################################################
EOF
get_MathJax($WW_PREFIX);

print_and_log(<<EOF);
#######################################################################
#
# Now I'm going to copy some classlist files and the modelCourse/ dir 
# from webwork2/courses.dist to $webwork_courses_dir.  
#
# modelCourse/ will serve as a default template for WeBWorK courses 
# you create.
#   
######################################################################
EOF
copy_classlist_files( $webwork_dir, $webwork_courses_dir );

#Symlinking webwork2/courses.dist/modelCourse to courses/modelCourse is
#better than copying it over for updates.
#copy_model_course( $webwork_dir, $webwork_courses_dir );
symlink_model_course( $webwork_dir, $webwork_courses_dir );

print_and_log(<<EOF);
#######################################################################
#
#
# Alrighty, so far so good.  Let's see, where are we?  Oh, right: we've
# created the webwork database, downloaded all of the code, moved things
# around, and obtained all of the config information we need.  
#
# Not too much left to do.
#
# Next up: We'll write the config files
#
# 
######################################################################
EOF

# No longer necessary to copy database.conf.dist to database.conf
#write_database_conf("$webwork_dir/conf");

write_site_conf(
    $WW_PREFIX,         "$webwork_dir/conf", $webwork_url,
    $server_root_url,   $apache,             $database_dsn,
    $database_username, $database_password,  $apps,
    \%mail		
);

write_localOverrides_conf( $WW_PREFIX, "$webwork_dir/conf" );

my $apache_config_file;

if (version->parse($apache->{version}) >= version->parse('2.4.00')) {
    $apache_config_file = 'webwork.apache2.4-config';
} else {
    $apache_config_file = 'webwork.apache2-config';
}

write_webwork_apache2_config("$webwork_dir", $apache_config_file);

write_webwork3_conf($WW_PREFIX,$database_password, "$webwork_dir/conf") 
    if -e "$WW_PREFIX/webwork2/conf/webwork3.conf.dist";

print_and_log(<<EOF);
#######################################################################
#
# Well, that was easy.  Now I need to slightly modify the 
# configuration of your apache webserver.  Note that we will
# back up the apache config file before any modifications are
# made. 
#
# First, I'm going symlink webwork.apache2-config to your apache 
# conf.d dir as webwork.conf. This will have the effect of starting 
# webwork whenever the webserver is started.  This *must* be done
# to enable webwork, so sorry - no choice in this matter.
#
#######################################################################
EOF

unless ($apache->{OtherConfig}) {
  print_and_log("The OtherConfig location (defined in the distro file for this linux distribution) is empty. We can't continue.");
  die('$apache->{OtherConfig} is empty, can\'t continue');
}

my $ln = can_run('ln');
my $cmd = [$ln, '-s', "$webwork_dir/conf/$apache_config_file", "$apache->{OtherConfig}/webwork.conf"];
my $success = run_command($cmd);;

if ($success) {

    print_and_log("Added webwork's apache config file to apache.\n");

} else {
    print_and_log("Couldn't add webwork's apache config file to apache.\n");
}

edit_httpd_conf($apache);

edit_mpm_conf($apache);

print_and_log(<<EOF);
#######################################################################
#
# Sanity check: Let's make sure we can restart apache. 
# 
######################################################################
EOF

restart_apache($apache);

#run hooked coe
$osPackage->postconfig_hook();

print_and_log(<<EOF);
#######################################################################
#
# Kay. Now I'm going to set up the OPL.  This could take a few...
# 
######################################################################
EOF
setup_opl($WW_PREFIX);


print_and_log(<<EOF);
######################################################################
#
# Now I'm going to compile pg/lib/chromatic/color.c. When you get a
# chance you should check out Nandor Sieben's excellent graph theory
# problems that use this.
#
#####################################################################
EOF
install_chromatic($pg_dir);

print_and_log(<<EOF);
#######################################################################
#
# Creating admin course...
# 
######################################################################
EOF
create_admin_course($WW_PREFIX);

if ( $wwadmin ne 'root' ) {
    print_and_log(<<EOF);
#######################################################################
#
#  Now I'm going to change the ownship of $WW_PREFIX and everything 
#  under it to $wwadmin:$wwadmin with permissions u+rwX,go+rwX
#  
######################################################################
EOF

#chown -R $wwadmin:$wwadmin $WW_PREFIX
#chmod -R u+rwX,go+rX $WW_PREFIX
#doing this with sub rather than perl built in to make sure it's done recursively
    change_owner( "$wwadmin:$wwadmin", $WW_PREFIX );
    my $chmod = can_run('chmod');
    my $cmd = [ $chmod, '-R', 'u+rwX,go+rX', $WW_PREFIX ];
    my $success = run_command($cmd);;
    if ($success) {
        print_and_log("Changed the ownship of $WW_PREFIX and ".
                      "everything under it to $wwadmin:$wwadmin ".
                      "with permissions u+rwX,go+rwX\n");
    } else {
        print_and_log("Couldn't change ownership of $WW_PREFIX.\n");
    }
}

print_and_log(<<EOF);
#######################################################################
#
# Now I'm going to change the ownship and permissions of some 
# directories under $webwork_dir and $webwork_courses_dir that should 
# be web accessible. Faulty permissions is one of the most common cause 
# of problems, especially after upgrades. 
# 
######################################################################
EOF
change_owner(
    "$wwadmin:$wwdata",  $webwork_courses_dir,
    "$webwork_dir/DATA", "$webwork_dir/htdocs/tmp",
    "$webwork_dir/logs", "$webwork_dir/tmp"
);
change_data_dir_permissions(
    $wwdata,             "$webwork_courses_dir",
    "$webwork_dir/DATA", "$webwork_dir/htdocs/tmp",
    "$webwork_dir/logs", "$webwork_dir/tmp"
);

reset_tex_hash();

my $webwork3log = "$webwork_dir/webwork3/logs";

if (-e $webwork3log) {
    change_webwork3_log_permissions("$wwadmin:$wwdata",$webwork3log);
    #temporary hack until logs is in the git repo
}

print_and_log(<<EOF);
######################################################
#
# Hey! I'm done!  
#
#######################################################

Restarting apache...
EOF

restart_apache($apache);

print_and_log(<<EOF);
Check it out at $server_root_url/webwork2! You can login to the 
admin course with initial username and password 'admin'.  

Have fun! :-)
EOF

write_launch_browser_script( $installer_dir,
    'http://localhost' . $webwork_url );

configure_shell($WW_PREFIX,$wwadmin);

#run hooked code
$osPackage->postinstall_hook();

copy("webwork_install.log","$WW_PREFIX/webwork_install.log") if -f 'webwork_install.log';

__END__
==encoding utf8

=head1 NAME

ww_install.pl 

=head1 DESCRIPTION

ww_install.pl, a WeBWorK Installation Script

=head2 Goals

=over

=item *

Interactively install webwork on any machine on which the prerequisites are installed

=item

Do as much as possible for the user, finding paths, writing config files, etc.

=item

Try not use anything other than core perl modules, webwork modules, webwork prerequisite modules

=item

Eventually add option for --nointeractive  and options to specify command line options

=back

=head2 How it works

=over

=item 1

Check if running as root

=item 2

Have you downloaded webwork already?

--if so, where is webwork2/, pg/, courses/, libraries/?

--if not, do you want me to get the software for you via svn?

=item 3

Check prerequisites, using this opportunity to populate %externalPrograms hash, and gather
environment information: $server_userID, $server_groupID, hostname?, timezone?

=item 4

Initially ask user minimum set of config questions:

=over

=item *

Directory root PREFIX

=item *

Accept standard webwork layout below PREFIX? (later)

=item *

  $server_root_url = "";  # e.g.  http://webwork.yourschool.edu (default from hostname lookup in (2))

=item *

  $server_userID = "";  # e.g.  www-data (default from httpd.conf lookup in (2))

=item *

  $server_groupID = "";  # e.g.  wwdata (gets the default from httpd.conf lookup in (2))

=item *

  $mail{smtpServer} = 'mail.yourschool.edu';

=item *

  $mail{smtpSender} = 'webwork@yourserver.yourschool.edu';

=item *

  $mail{smtpTimeout} = 30;

=item *

database root password

=item *

$database_dsn = "dbi:mysql:webwork";

=item *

$database_username = "webworkWrite";

=item *

$database_password = "";

=item *

$siteDefaults{timezone} = "America/New_York";

=back

=item 5

Put software in correct locations

=item 6

Use gathered information to write site.conf file, localOverrides.conf, webwork.apache2-config, wwapache2ctl,

=item 7

Check and fix filesystem permissions in webwork2/ tree

=item 8

Create initial database user, initial mysql tables

=item 9

Create admin course

=item 10

Append include statement to httpd.conf to pick up webwork.apache2-config

=item 11

Restart apache, check for errors

=item 12

Do some testing!

=back

=head1 AUTHOR

Jason Aubrey <aubreyja@gmail.com>

=head1 COPYRIGHT AND DISCLAIMER

This program is Copyright 2013 by Jason Aubrey.  This program is
free software; you can redistribute it and/or modify it under the terms
of the Perl Artistic License or the GNU General Public License as
published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

If you do not have a copy of the GNU General Public License write to
the Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139,
USA.

=cut
