# Package for distribution ubuntu version 18.04
package ubuntu::1804;
use base qw(blankdistro);

use strict;
use warnings;

use WeBWorK::Install::Utils;

# This is a list of WeBWorK versions for which the installer has
# been verified to work for this distro. 
my $ww_versions = ['2.13'];

sub get_ww_versions {
    return $ww_versions;
}

# A list of packages for various binaries that we need. 
my $binary_prerequisites = {
    mkdir => 'coreutils',
    mv => 'coreutils',
    gcc => 'gcc',
    make => 'make',
    tar => 'tar',
    gzip => 'gzip',
    unzip => 'unzip',
    dvipng => 'dvipng',
    curl => 'curl',
    perl => 'perl',
    netpbm => 'netpbm',  #provides giftopnm, ppmtopgm, pnmtops, pnmtopng, 
                        #and pgntopnm
    git => 'git',
    svn => 'subversion',
    cpanminus => 'cpanminus',

    mysql => 'mysql-client',
    mysql_server => 'mysql-server',
    ssh_server => 'openssh-server',

    apache2 => 'apache2',
    mod_mpm => 'apache2',
    mod_fcgid => 'libapache2-mod-fcgid',
    mod_perl => 'libapache2-mod-perl2',
    mod_apreq => 'libapache2-mod-apreq2',
    
    preview_latex => 'preview-latex-style',
    texlive => 'texlive-latex-base',
    texlive_recommended => 'texlive-latex-recommended',
    texlive_extra => 'texlive-latex-extra',
    texlive_fonts_recommended => 'texlive-fonts-recommended',
};

sub get_binary_prerequisites {
    return $binary_prerequisites;
}

# A list of perl modules that we need
my $perl_prerequisites = {
    'Apache2::Request' => 'libapache2-request-perl',
    'Apache2::Cookie' => 'libapache2-request-perl',
    'Apache2::ServerRec' => 'libapache2-mod-perl2',
    'Apache2::ServerUtil' => 'libapache2-mod-perl2',
    'Array::Utils' => 'CPAN',
    'Benchmark' => 'perl-modules',
    'Carp' => 'perl-base',
    'CGI' => 'perl-modules',
    'Crypt::SSLeay' => 'libcrypt-ssleay-perl',
    'Dancer' => 'libdancer-perl',
    'Dancer::Plugin::Database' => 'libdancer-plugin-database-perl',
    'Data::Dump' => 'libdata-dump-perl',    
    'Data::Dumper' => 'perl',
    'Data::UUID' => 'libossp-uuid-perl',
    'Date::Format' => 'libtimedate-perl',
    'Date::Parse' => 'libtimedate-perl',
    'DateTime' => 'libdatetime-perl',
    'DBD::mysql' => 'libdbd-mysql-perl',
    'DBI' => 'libdbi-perl',
    'Digest::MD5' => 'perl',
    'Email::Address' => 'libemail-sender-perl',
    'Email::Simple' => 'libemail-simple-perl',
    'Email::Sender::Simple' => 'libemail-sender-perl',
    'Email::Sender::Transport::SMTP' => 'libemail-sender-perl',
    'Errno' => 'perl-base',
    'Exception::Class' => 'libexception-class-perl',
    'ExtUtils::XSBuilder' => 'libextutils-xsbuilder-perl',
    'File::Copy' => 'perl-modules',
    'File::Find' => 'perl-modules',
    'File::Find::Rule' => 'libfile-find-rule-perl',
    'File::Path' => 'perl-modules',
    'File::Spec' => 'perl-modules',
    'File::stat' => 'perl-modules',
    'File::Temp' => 'perl-modules',
    'GD' => 'libgd-gd2-perl',
    'Getopt::Long' => 'perl-base',
    'Getopt::Std' => 'perl-modules',
    'HTML::Entities' => 'libhtml-parser-perl',
    'HTML::Scrubber' => 'libhtml-scrubber-perl',
    'HTML::Tagset' => 'libhtml-tagset-perl',
    'HTML::Template' => 'libhtml-template-perl',
    'IO::File' => 'libio-file-withpath-perl',
    'Iterator' => 'CPAN',
    'Iterator::Util' => 'CPAN',
    'JSON' => 'libjson-perl',
    'Locale::Maketext::Lexicon' => 'liblocale-maketext-lexicon-perl',
    'Locale::Maketext::Simple' => 'perl-modules',
    'LWP::Protocol::https' => 'liblwp-protocol-https-perl',
    'MIME::Base64' => 'libmime-tools-perl',
    'Net::IP' => 'libnet-ip-perl',
    'Net::LDAPS' => 'libnet-ldap-perl',
    'Net::OAuth' => 'libnet-oauth-perl',
    'Net::SMTP' => 'perl-modules',
    'Opcode' => 'perl',
    'PadWalker' => 'libpadwalker-perl',
    'Path::Class' => 'CPAN',
    'PHP::Serialization' => 'libphp-serialization-perl',
    'Pod::Usage' => 'perl-modules',
    'Pod::WSDL' => 'libpod-wsdl-perl',
    'Safe' => 'perl-modules',
    'Scalar::Util' => 'perl-base',
    'SOAP::Lite' => 'libsoap-lite-perl',
    'Socket' => 'perl-base',
    'SQL::Abstract' => 'libsql-abstract-perl',
    'Statistics::R::IO' => 'CPAN',
    'String::ShellQuote' => 'libstring-shellquote-perl',
    'Template' => 'libtemplate-perl',
    'Text::CSV' => 'libtext-csv-perl',
    'Text::Wrap' => 'perl-base',
    'Tie::IxHash' => 'libtie-ixhash-perl',
    'Time::HiRes' => 'perl',
    'Time::Zone' => 'libtimedate-perl',
    'URI::Escape' => 'liburi-perl',
    'UUID::Tiny' => 'libuuid-tiny-perl',
    'XML::Parser' => 'libxml-parser-perl',
    'XML::Parser::EasyTree' => 'CPAN',
    'XML::Writer' => 'libxml-writer-perl',
    'XMLRPC::Lite' => 'libsoap-lite-perl',
    'YAML' => 'libyaml-perl'
};

sub get_perl_prerequisites {
    return $perl_prerequisites;
}

# A hash containing information about the apache webserver
my $apacheLayout = {
    MPMDir       => '',
    MPMConfFile  => '/etc/apache2/mods-available/mpm_prefork.conf',
    ServerRoot   => '/etc/apache2',
    DocumentRoot => '/var/www',
    ConfigFile   => '/etc/apache2/apache2.conf',
    OtherConfig  => '/etc/apache2/conf-enabled',
    SSLConfig    => '',
    Modules      => '/etc/apache2/mods-enabled',
    ErrorLog     => '/var/log/apache2/error.log',
    AccessLog    => '/var/log/apache2/access.log',
    Binary       => '/usr/sbin/apache2ctl',
    User         => 'www-data',
    Group        => 'www-data',
};

sub get_apacheLayout {
    return $apacheLayout;
}

# A command for updating the package sources
sub update_sources {
    run_command(['sed','-i','-e','s/^# deb \(.*\) partner/deb \1 partner/','/etc/apt/sources.list']);
    run_command(['sed','-i','-e','s/^# deb-src \(.*\) partner/deb-src \1 partner/','/etc/apt/sources.list']);
};

# A command for updating the system
sub update_packages {
    run_command(['apt-get','-y','update']);
    run_command(['apt-get','-y','upgrade']);
};
    
# A command for installing a package given a name
sub package_install {
    my $self = shift;
    my @packages = @_;
    run_command(['apt-get','install','-y','--allow-unauthenticated',@packages]);
};

# A command for installing a cpan package given a name
sub CPAN_install {
    my $self = shift;
    my @modules = @_;
    run_command(['cpanm',@modules]);
};

# A command for any distro specific stuff that needs to be done
# after installing prerequieists
sub postpreq_hook {

}

# A command for checking if the required services are running
# and configuring them
sub configure_services {
    run_command(['a2enmod','apreq2']);
    run_command(['a2enmod','fcgid']);
    run_command(['apache2ctl', 'restart']);

}

# A command for any distro specific stuff that needs to be done
# before the webwork config process begins
sub preconfig_hook {

}

# A command for any distro specific stuff that needs to be done
# after webwork has been configured
sub postconfig_hook {
  # As of the release of 2.12 the JSON::XS::Boolean package for
  # ubuntu was kind of borked.  So we use the PP boolean
  # implementation instead by setting an environment variable.

  print_and_log("Setting Perl to use JSON::PP in apache config file.\n");
  
  die $! if system(q|sed --follow-symlinks -i 's/\$ENV{WEBWORK_ROOT} = $webwork_dir;/\$ENV{WEBWORK_ROOT} = $webwork_dir;\n$ENV{PERL_JSON_BACKEND} = '"'JSON::PP';/" /etc/apache2/conf-enabled/webwork.conf|);

}

# A comand for any distro specific stuff that needs to be done
# after webwork has been fully installed
sub postinstall_hook {

}

1;
