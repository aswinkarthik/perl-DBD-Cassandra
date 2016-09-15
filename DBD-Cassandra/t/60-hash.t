use v5.14;
use Test::More;

unless ($ENV{CASSANDRA_HOST}) {
    plan skip_all => "CASSANDRA_HOST not set";
}

plan tests => 3;

use DBI;
my $dbh= DBI->connect("dbi:Cassandra:host=$ENV{CASSANDRA_HOST};consistency=quorum", $ENV{CASSANDRA_USER}, $ENV{CASSANDRA_AUTH}, {RaiseError => 1, Warn => 1, PrintWarn => 0, PrintError => 0});
ok($dbh);

my $keyspace= "dbd_cassandra_tests";

ok(!eval {
    # Invalid: can't use prepared statements here
    $dbh->do('drop keyspace if exists ?', undef, $keyspace);
});

$dbh->do("drop keyspace if exists $keyspace");
$dbh->do("create keyspace $keyspace with replication={'class': 'SimpleStrategy', 'replication_factor': 1}");
$dbh->do("create table $keyspace.test_int (id bigint primary key, val text, id2 uuid)");
$dbh->do("insert into $keyspace.test_int (id, val, id2) values (?, ?, ?)", undef, 1, "test", "12345678-1234-1234-1234-123412341234");
my $row= $dbh->selectall_arrayref("select id, val, id2 from $keyspace.test_int where id=?", {Slice=>{},async=>1}, 1)->[0];
is_deeply($row, {
    id => 1,
    val => "test",
    id2 => "12345678-1234-1234-1234-123412341234",
});

$dbh->disconnect;