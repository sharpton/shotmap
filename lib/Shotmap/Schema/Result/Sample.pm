use utf8;
package Shotmap::Schema::Result::Sample;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Shotmap::Schema::Result::Sample

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<samples>

=cut

__PACKAGE__->table("samples");

=head1 ACCESSORS

=head2 sample_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 project_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 sample_alt_id

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 metadata

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sample_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "project_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "sample_alt_id",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "metadata",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</sample_id>

=back

=cut

__PACKAGE__->set_primary_key("sample_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<project_id_sample_alt_id>

=over 4

=item * L</project_id>

=item * L</sample_alt_id>

=back

=cut

__PACKAGE__->add_unique_constraint("project_id_sample_alt_id", ["project_id", "sample_alt_id"]);

=head2 C<sample_alt_id>

=over 4

=item * L</sample_alt_id>

=back

=cut

__PACKAGE__->add_unique_constraint("sample_alt_id", ["sample_alt_id"]);

=head1 RELATIONS

=head2 project

Type: belongs_to

Related object: L<Shotmap::Schema::Result::Project>

=cut

__PACKAGE__->belongs_to(
  "project",
  "Shotmap::Schema::Result::Project",
  { project_id => "project_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-11-15 16:04:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KF7h6H7oQMI2TeDAkmuuuw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
