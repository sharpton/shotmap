use utf8;
package Shotmap::Schema::Result::Family;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Shotmap::Schema::Result::Family

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<families>

=cut

__PACKAGE__->table("families");

=head1 ACCESSORS

=head2 internal_famid

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 famid

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 family_length

  data_type: 'integer'
  is_nullable: 1

=head2 family_size

  data_type: 'integer'
  is_nullable: 1

=head2 searchdb_id

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "internal_famid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "famid",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "family_length",
  { data_type => "integer", is_nullable => 1 },
  "family_size",
  { data_type => "integer", is_nullable => 1 },
  "searchdb_id",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</internal_famid>

=back

=cut

__PACKAGE__->set_primary_key("internal_famid");

=head1 UNIQUE CONSTRAINTS

=head2 C<famid_searchdb_id>

=over 4

=item * L</famid>

=item * L</searchdb_id>

=back

=cut

__PACKAGE__->add_unique_constraint("famid_searchdb_id", ["famid", "searchdb_id"]);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-09-04 11:41:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VP7y9hNijWEbIynxTYNpdg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
