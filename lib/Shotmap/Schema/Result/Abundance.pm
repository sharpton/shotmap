use utf8;
package Shotmap::Schema::Result::Abundance;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Shotmap::Schema::Result::Abundance

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<abundances>

=cut

__PACKAGE__->table("abundances");

=head1 ACCESSORS

=head2 abundance_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 sample_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 famid

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 abundance

  data_type: 'float'
  is_nullable: 0

=head2 relative_abundance

  data_type: 'float'
  is_nullable: 0

=head2 abundance_parameter_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 classification_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "abundance_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "sample_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "famid",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "abundance",
  { data_type => "float", is_nullable => 0 },
  "relative_abundance",
  { data_type => "float", is_nullable => 0 },
  "abundance_parameter_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "classification_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</abundance_id>

=back

=cut

__PACKAGE__->set_primary_key("abundance_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<fam_sample_type_id>

=over 4

=item * L</sample_id>

=item * L</famid>

=item * L</abundance_parameter_id>

=item * L</classification_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "fam_sample_type_id",
  [
    "sample_id",
    "famid",
    "abundance_parameter_id",
    "classification_id",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-11-15 16:04:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FglDAGh8/OqXUUVM8q+ECw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
