# --
# Copyright (C) 2012-2021 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_Znuny4OTRSCustomerViewDynamicFields;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    # SysConfig
    $Self->{Translation}->{'Dynamic fields shown in the ticket customer screen of the agent interface.'}
        = 'Dynamische Felder, die im Dialog zum Setzen des Ticket-Kunden in der Agenten-Oberfläche angezeigt werden sollen.';
    $Self->{Translation}->{'This configuration registers an OutputFilter module that adds the DynamicField block to the AgentTicketCustomer template.'}
        = 'Diese Konfiguration registriert ein OutputFilter-Modul, das den Block für dynamische Felder zum Template hinzufügt.';

    return 1;
}

1;
