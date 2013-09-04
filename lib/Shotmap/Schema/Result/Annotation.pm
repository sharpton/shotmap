use utf8;
package Shotmap::Schema::Result::Annotation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Shotmap::Schema::Result::Annotation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<annotations>

=cut

__PACKAGE__->table("annotations");

=head1 ACCESSORS

=head2 annotation_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 famid

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 annotation_string

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 annotation_type_id

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 annotation_type

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 searchdb_id

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "annotation_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "famid",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "annotation_string",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "annotation_type_id",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "annotation_type",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "searchdb_id",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</annotation_id>

=back

=cut

__PACKAGE__->set_primary_key("annotation_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<famid_searchdb_annotation_type_id>

=over 4

=item * L</famid>

=item * L</searchdb_id>

=item * L</annotation_type_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "famid_searchdb_annotation_type_id",
  ["famid", "searchdb_id", "annotation_type_id"],
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-09-04 11:41:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IwatCLob8wHj5JIfIHpgWA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
