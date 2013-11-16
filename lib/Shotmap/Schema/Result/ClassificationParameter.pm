use utf8;
package Shotmap::Schema::Result::ClassificationParameter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Shotmap::Schema::Result::ClassificationParameter

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<classification_parameters>

=cut

__PACKAGE__->table("classification_parameters");

=head1 ACCESSORS

=head2 classification_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 evalue_threshold

  data_type: 'double precision'
  is_nullable: 1

=head2 coverage_threshold

  data_type: 'float'
  is_nullable: 1

=head2 score_threshold

  data_type: 'float'
  is_nullable: 1

=head2 method

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 reference_database_name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=cut

__PACKAGE__->add_columns(
  "classification_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "evalue_threshold",
  { data_type => "double precision", is_nullable => 1 },
  "coverage_threshold",
  { data_type => "float", is_nullable => 1 },
  "score_threshold",
  { data_type => "float", is_nullable => 1 },
  "method",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "reference_database_name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
);

=head1 PRIMARY KEY

=over 4

=item * L</classification_id>

=back

=cut

__PACKAGE__->set_primary_key("classification_id");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-11-15 16:04:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:G9KaSDyNzilNHaLzp5zdzg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
