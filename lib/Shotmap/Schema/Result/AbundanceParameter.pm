use utf8;
package Shotmap::Schema::Result::AbundanceParameter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Shotmap::Schema::Result::AbundanceParameter

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<abundance_parameters>

=cut

__PACKAGE__->table("abundance_parameters");

=head1 ACCESSORS

=head2 abundance_parameter_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 abundance_type

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 normalization_type

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 rarefaction_depth

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 rarefaction_type

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=cut

__PACKAGE__->add_columns(
  "abundance_parameter_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "abundance_type",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "normalization_type",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "rarefaction_depth",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "rarefaction_type",
  { data_type => "varchar", is_nullable => 1, size => 256 },
);

=head1 PRIMARY KEY

=over 4

=item * L</abundance_parameter_id>

=back

=cut

__PACKAGE__->set_primary_key("abundance_parameter_id");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-11-15 16:04:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:36pKrswADvdM69j2LUEvmA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
