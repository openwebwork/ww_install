package centos::8;

use strict;
use warnings;

use WeBWorK::Install::Utils;

my $ww_versions = ['2.15'];

sub get_ww_versions {
    return $ww_versions;
}

# A list of packages for various binaries that we need. 
my $binary_prerequisites = {
    mkdir => 'coreutils',
    mv => 'coreutils',
    gcc => 'gcc',
    make => 'make',
    patch => 'patch',
    tar => 'tar',
    system_config => 'system-config-services',
    gzip => 'gzip',
    unzip => 'coreutils',
    dvipng => 'dvipng',
    curl => 'curl',
    perl => 'perl',
    netpbm => 'netpbm',  #provides giftopnm, ppmtopgm, pnmtops, pnmtopng, 
    netpbm_progs => 'netpbm-progs',               #and pgntopnm
    git => 'git',
    svn => 'subversion',

    mysql => 'mariadb',
    mysql_server => 'mariadb-server',
    ssh_server => 'openssh-server',

    apache2 => 'httpd',
    mod_mpm => 'httpd',
    mod_fcgid => 'mod_fcgid',
    mod_perl => 'mod_perl',
    mod_apreq => 'libapreq2',
    
    preview_latex => 'tex-preview',
    texlive => 'texlive-latex',
    texlive_appendix => 'texlive-appendix',
    texlive_preprint => 'texlive-preprint',
    texlive_epsf => 'texlive-epsf',
    };

sub get_binary_prerequisites {
    return $binary_prerequisites;
}

# A list of perl modules that we need
my $perl_prerequisites = {
    'Test::XML' => 'perl-Test-XML', # needed in centos 7 for cpan installs
    'Test::Simple' => 'perl-Test-Simple',
    'Test::Requires' => 'perl-Test-Requires',
    'Test::TCP' => 'perl-Test-TCP',
    'HTTP::Tiny' => 'perl-HTTP-Tiny', 
    'Plack'      => 'perl-Plack',
    'Apache2::Request' => 'perl-libapreq2',
    'Apache2::Cookie' => 'perl-libapreq2',
    'Apache2::ServerRec' => 'mod_perl',
    'Apache2::ServerUtil' => 'mod_perl',
    'Array::Utils' => 'CPAN',
    'Benchmark' => 'perl',
    'Carp' => 'perl',
    'CGI' => 'perl-CGI',
    'CPAN' => 'perl-CPAN',
    'CPANMinus' => 'perl-App-cpanminus',
    'Crypt::SSLeay' => 'perl-Crypt-SSLeay',
    'Dancer' => 'CPAN',
    'Dancer::Plugin::Database' => 'CPAN',
    'Data::Dump' => 'perl-Data-Dump',    
    'Data::Dumper' => 'perl-Data-Dumper',
    'Data::UUID' => 'perl-Data-UUID',
    'Date::Format' => 'perl-TimeDate',
    'Date::Parse' => 'perl-TimeDate',
    'DateTime' => 'perl-DateTime',
    'DBD::mysql' => 'perl-DBD-MySQL',
    'DBI' => 'perl-DBI',
    'Digest::MD5' => 'perl',
    'Email::Address' => 'perl-Email-Address',
    'Email::Simple' => 'perl-Email-Simple',
    'Email::Sender::Simple' => 'perl-Email-Sender',
    'Email::Sender::Transport::SMTP' => 'perl-Email-Sender',
    'Errno' => 'perl',
    'Exception::Class' => 'perl-Exception-Class',
    'ExtUtils::XSBuilder' => 'perl-ExtUtils-XSBuilder',
    'File::Copy' => 'perl',
    'File::Find' => 'perl',
    'File::Find::Rule' => 'perl-File-Find-Rule',
    'File::Path' => 'perl',
    'File::Spec' => 'perl',
    'File::stat' => 'perl',
    'File::Temp' => 'perl',
    'GD' => 'perl-GD',
    'GDGraph' => 'perl-GDGraph',
    'Getopt::Long' => 'perl',
    'Getopt::Std' => 'perl',
    'HTML::Entities' => 'perl-HTML-Parser',
    'HTML::Scrubber' => 'perl-HTML-Scrubber',
    'HTML::Tagset' => 'perl-HTML-Tagset',
    'HTML::Template' => 'perl-HTML-Template',
    'IO::File' => 'perl',
    'Iterator' => 'CPAN',
    'Iterator::Util' => 'CPAN',
    'JSON' => 'perl-JSON',
    'Locale::Maketext::Lexicon' => 'CPAN', #is availble for fedora
    'Locale::Maketext::Simple' => 'perl-Locale-Maketext-Simple',
    'LWP::Protocol::https' => 'CPAN', #need cpan for higher version
    'MIME::Base64' => 'perl', 
    'Net::IP' => 'perl-Net-IP',
    'Net::LDAPS' => 'perl-LDAP',
    'Net::OAuth' => 'perl-Net-OAuth',
    'Net::SMTP' => 'perl-Net-SMTP-SSL',
    'Opcode' => 'perl',
    'PadWalker' => 'perl-PadWalker',
    'Path::Class' => 'perl-Path-Class',
    'PHP::Serialization' => 'CPAN',
    'Pod::Usage' => 'perl',
    'Pod::WSDL' => 'CPAN',
    'Safe' => 'perl',
    'Scalar::Util' => 'perl',
    'SOAP::Lite' => 'perl-SOAP-Lite',
    'Socket' => 'perl',
    'SQL::Abstract' => 'CPAN',
    'Statistics::R::IO' => 'CPAN',
    'String::ShellQuote' => 'perl-String-ShellQuote',
    'Template' => 'CPAN',
    'Text::CSV' => 'perl-Text-CSV',
    'Text::Wrap' => 'perl',
    'Tie::IxHash' => 'perl-Tie-IxHash',
    'Time::HiRes' => 'perl-Time-HiRes',
    'Time::Zone' => 'perl-TimeDate',
    'URI::Escape' => 'perl',
    'UUID::Tiny' => 'CPAN',
    'XML::Parser' => 'perl-XML-Parser',
    'XML::Parser::EasyTree' => 'CPAN',
    'XML::Writer' => 'perl-XML-Writer',
    'XMLRPC::Lite' => 'perl-XMLRPC-Lite',
    'YAML' => 'perl-YAML',
};

sub get_perl_prerequisites {
    return $perl_prerequisites;
}

# A hash containing information about the apache webserver
my $apacheLayout = {
    MPMDir       => '',
    MPMConfFile  => '/etc/httpd/conf.modules.d/00-mpm.conf',
    ServerRoot   => '/etc/httpd',
    DocumentRoot => '/var/www/html',
    ConfigFile   => '/etc/httpd/conf/httpd.conf',
    OtherConfig  => '/etc/httpd/conf.d',
    SSLConfig    => '',
    Modules      => '/etc/httpd/modules',
    ErrorLog     => '/var/log/httpd/error_log',
    AccessLog    => '/var/log/httpd/access_log',
    Binary       => '/usr/sbin/apachectl',
    User         => 'apache',
    Group        => 'apache',
};

sub get_apacheLayout {
    return $apacheLayout;
}

# A command for any distro specific stuff that needs to be done
# before installing prerequisites
sub prepreq_hook {

};

sub midpreq_hook {
    run_command(['cpan','Moo']); #moo needs tob e done with cpan not cpanm
};

# A command for updating the package sources
sub update_sources {
    run_command(['dnf', '-y', 'install', 'epel-release']);
};

# A command for updating the system
sub update_packages {
    run_command(['dnf', '-y', 'update']);
};

# A command for installing a package given a name
sub package_install {
    my $self = shift;
    my @packages = @_;
    run_command(['dnf','-y','install',@packages]);
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
    # For installing missing tex package.  We can safely use the fedora
    # package because its just a latex style file. 
    run_command(['curl', '-ksSO', 'http://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os/Packages/t/texlive-path-svn22045.3.05-19.fc32.noarch.rpm']);
    run_command(['rpm','-ivh','--replacepkgs','texlive-path-svn22045.3.05-19.fc32.noarch.rpm'])
    
}

# A command for checking if the required services are running and
# configuring them
sub configure_services {
    run_command(['systemctl','enable','mariadb']);
    run_command(['systemctl','start','mariadb']);
    run_command(['systemtcl','enable','httpd']);
    run_command(['systemctl','start','httpd']);
    run_command(['mysql_secure_installation']);
}

# A command for any distro specific stuff that needs to be done
# before the webwork config process begins
sub preconfig_hook {

}

# A command for any distro specific stuff that needs to be done
# after webwork has been configured
sub postconfig_hook {

}

# A comand for any distro specific stuff that needs to be done
# after webwork has been fully installed
sub postinstall_hook {

}


1;
