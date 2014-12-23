# --
# Kernel/Output/HTML/OutputFilterPreZnuny4OTRSCustomerViewDynamicFields.pm - adds the DynamicField block to the AgentTicketCustomer template
# Copyright (C) 2014 Znuny GmbH, http://znuny.com/
# --

package Kernel::Output::HTML::OutputFilterPreZnuny4OTRSCustomerViewDynamicFields;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Action} = $Param{Action} || '';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $DynamicFieldHTMLBlock = <<'HTML';
    [% RenderBlockStart("DynamicField") %]
                            <div class="Row Row_DynamicField_[% Data.Name | html %]">
                                [% Data.Label %]
                                <div class="Field">
                                   [% Data.Field %]
                                </div>
                                <div class="Clear"></div>
                            </div>
    [% RenderBlockEnd("DynamicField") %]
HTML

    # manipulate HTML content
    ${ $Param{Data} } =~ s{(<label\s(class="Mandatory"\s|)for="CustomerID".+?div\sclass="Clear"></div>)}{$1$DynamicFieldHTMLBlock}xms;

    return 1;
}

1;
