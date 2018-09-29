package WeBWorK::Install::Database;

use WeBWorK::Install::Utils;

use File::Copy;

use Exporter 'import'; # gives you Exporter's import() method directly
@EXPORT = qw(database_exists connect_to_database change_storage_engine get_dsn create_database initialize_dbi); # symbols to export (I'm a bad person.)

sub initialize_dbi {

    require DBI;
}

sub database_exists {
  my ($root_password,$database,$server) = @_;
  my $dbh = DBI->connect("dbi:mysql:database=information_schema;host=$server", 'root', $root_password, { 'RaiseError' => 1 } );
  my $databases = $dbh->selectcol_arrayref('show databases');
  $dbh->disconnect();
  foreach(@$databases) {
    return 1 if $database eq $_;
  }
  return 0;
}

sub connect_to_database {
  my ( $server, $ww_db, $ww_user, $ww_pw ) = @_;
  eval {
    my $dbh = DBI->connect("dbi:mysql:database=$ww_db;host=$server", $ww_user, $ww_pw, { 'RaiseError' => 1 } );
  };
  if($@) {
    print_and_log("Something's wrong: $@");
    return 0;
  } else {
    print_and_log("Connected to $ww_db on $server as $ww_user...\n");
    return 1;
  }
}

sub change_storage_engine {
  my $my_cnf = shift; 
  my (undef,$dir,$file) = File::Spec->splitpath($my_cnf);
  my $engine = 'myisam';
  open(my $fh,'<',$my_cnf) or print_and_log("Couldn't find $my_cnf: $!");
  return unless $fh;
  copy($my_cnf,$dir."/".$file.".bak");
  my $string = do { local($/); <$fh> };
  close($fh);
  open(my $new,'>',$my_cnf);
  $string =~ s/\[mysqld\]/\[mysqld\]\n#\n# webwork wants this:\n#\n\ndefault-storage-engine = $engine\n/;
  print $new $string;
  print_and_log("Modified $my_cnf to set MyISAM to be default MySQL storage engine");
}


sub get_dsn {
    my ($database,$server) = @_;
    return "dbi:mysql:$database:$server";
}

#############################################################
#
# Create webwork database...
#
############################################################

sub create_database {
    my ( $server, $root_pw, $ww_db, $ww_user, $ww_pw ) = @_;
    my $dbh = DBI->connect( "dbi:mysql:database=mysql;host=$server", 'root', $root_pw );
    print_and_log("Connected to mysql as root...");
    $dbh->do("CREATE DATABASE IF NOT EXISTS $ww_db")
      or die "Could not create $ww_db database: $!\n";
    print_and_log("Created $ww_db database...");
    $dbh->do(
"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, LOCK TABLES ON $ww_db.* TO $ww_user\@localhost IDENTIFIED BY '$ww_pw'"
      )
      or (print_and_log("Could not grant privileges to $ww_user on $ww_db database: $!") && die);
      
    print_and_log("Granted privileges...");
    $dbh->disconnect();
}
