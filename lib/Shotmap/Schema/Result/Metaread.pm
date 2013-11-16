use utf8;
package Shotmap::Schema::Result::Metaread;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Shotmap::Schema::Result::Metaread

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<metareads>

=cut

__PACKAGE__->table("metareads");

=head1 ACCESSORS

=head2 read_id

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
  is_nullable: 0
  size: 256

=head2 seq

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "read_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "sample_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "read_alt_id",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "seq",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</read_id>

=back

=cut

__PACKAGE__->set_primary_key("read_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<sample_id_read_alt_id>

=over 4

=item * L</sample_id>

=item * L</read_alt_id>

=back

=cut

__PACKAGE__->add_unique_constraint("sample_id_read_alt_id", ["sample_id", "read_alt_id"]);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-11-15 16:04:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0UcDARmMcsKyZdUimObFmQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
