use utf8;
package Shotmap::Schema::Result::Orf;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Shotmap::Schema::Result::Orf

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<orfs>

=cut

__PACKAGE__->table("orfs");

=head1 ACCESSORS

=head2 orf_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 sample_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 read_alt_id

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 orf_alt_id

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 start

  data_type: 'integer'
  is_nullable: 1

=head2 stop

  data_type: 'integer'
  is_nullable: 1

=head2 frame

  data_type: 'enum'
  extra: {list => [0,1,2]}
  is_nullable: 1

=head2 strand

  data_type: 'enum'
  extra: {list => ["-","+"]}
  is_nullable: 1

=head2 seq

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "orf_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "sample_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "read_alt_id",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "orf_alt_id",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "start",
  { data_type => "integer", is_nullable => 1 },
  "stop",
  { data_type => "integer", is_nullable => 1 },
  "frame",
  { data_type => "enum", extra => { list => [0, 1, 2] }, is_nullable => 1 },
  "strand",
  { data_type => "enum", extra => { list => ["-", "+"] }, is_nullable => 1 },
  "seq",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</orf_id>

=back

=cut

__PACKAGE__->set_primary_key("orf_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<sample_id_orf_alt_id>

=over 4

=item * L</sample_id>

=item * L</orf_alt_id>

=back

=cut

__PACKAGE__->add_unique_constraint("sample_id_orf_alt_id", ["sample_id", "orf_alt_id"]);

=head2 C<sample_id_read_alt_id>

=over 4

=item * L</sample_id>

=item * L</read_alt_id>

=back

=cut

__PACKAGE__->add_unique_constraint("sample_id_read_alt_id", ["sample_id", "read_alt_id"]);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-11-15 16:04:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WUT01ZWEoZUaYQ9SLa8plg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
