# --
# Copyright (C) 2012-2018 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_Znuny4OTRSCustomerViewDynamicFields;

use strict;
use warnings;

sub Data {
    my $Self = shift;

    # SysConfig
    $Self->{Translation}->{'This configuration registers an OutputFilter module that adds the DynamicField block to the AgentTicketCustomer template.'} = 'Diese Konfiguration registriert ein OutputFilter-Modul, das den Block für dynamische Felder zum Template hinzufügt.';

    return 1;
}

1;
