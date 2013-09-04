use utf8;
package Shotmap::Schema::Result::Familymember;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Shotmap::Schema::Result::Familymember

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<familymembers>

=cut

__PACKAGE__->table("familymembers");

=head1 ACCESSORS

=head2 member_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 famid

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 target_id

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 target_length

  data_type: 'integer'
  is_nullable: 1

=head2 searchdb_id

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "member_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "famid",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "target_id",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "target_length",
  { data_type => "integer", is_nullable => 1 },
  "searchdb_id",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</member_id>

=back

=cut

__PACKAGE__->set_primary_key("member_id");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-09-04 11:41:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:f+RwFUYIXUKwDW5BtdMRfQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
