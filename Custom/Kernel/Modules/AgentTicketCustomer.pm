# --
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# $origin: Znuny - 4e84ea4bb19adae193fe08ab181211d0fc4b8a0a - Kernel/Modules/AgentTicketCustomer.pm
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AgentTicketCustomer;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );
# ---
# Znuny-CustomerViewDynamicFields
# ---
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    $Self->{DynamicFieldConfigs} = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $Config->{DynamicField} || {},
    );
# ---

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
# ---
# Znuny-CustomerViewDynamicFields
# ---
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
# ---

    my $Output;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$Self->{TicketID} ) {

        # error page
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No TicketID is given!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get config
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::$Self->{Action}");

    # check permissions
    if (
        !$TicketObject->TicketPermission(
            Type     => $Config->{Permission},
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID}
        )
        )
    {

        # error screen, don't show ticket
        return $LayoutObject->NoPermission(
            Message => $LayoutObject->{LanguageObject}->Translate( 'You need %s permissions!', $Config->{Permission} ),
            WithHeader => 'yes',
        );
    }

    # get ACL restrictions
    my %PossibleActions = ( 1 => $Self->{Action} );

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = $TicketObject->TicketAclActionData();

    # check if ACL restrictions exist
    if ( $ACL || IsHashRefWithData( \%AclAction ) ) {

        my %AclActionLookup = reverse %AclAction;

        # show error screen if ACL prohibits this action
        if ( !$AclActionLookup{ $Self->{Action} } ) {
            return $LayoutObject->NoPermission( WithHeader => 'yes' );
        }
    }

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    if ( $Self->{Subaction} eq 'Update' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # set customer id
        my $ExpandCustomerName1 = $ParamObject->GetParam( Param => 'ExpandCustomerName1' )
            || 0;
        my $ExpandCustomerName2 = $ParamObject->GetParam( Param => 'ExpandCustomerName2' )
            || 0;
        my $CustomerUserOption = $ParamObject->GetParam( Param => 'CustomerUserOption' )
            || '';
        $Param{CustomerUserID}       = $ParamObject->GetParam( Param => 'CustomerUserID' )       || '';
        $Param{CustomerID}           = $ParamObject->GetParam( Param => 'CustomerID' )           || '';
        $Param{SelectedCustomerUser} = $ParamObject->GetParam( Param => 'SelectedCustomerUser' ) || '';

        # use customer login instead of email address if applicable
        if ( $Param{SelectedCustomerUser} ne '' ) {
            $Param{CustomerUserID} = $Param{SelectedCustomerUser};
        }

        # get customer user object
        my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

        # Expand Customer Name
        if ($ExpandCustomerName1) {
# ---
# Znuny-CustomerViewDynamicFields
# ---
            # Not needed to be changed, since the 'ExpandCustomerName1' function is not being used.
# ---

            # search customer
            my %CustomerUserList = ();
            %CustomerUserList = $CustomerUserObject->CustomerSearch(
                Search => $Param{CustomerUserID},
            );

            # check if just one customer user exists
            # if just one, fillup CustomerUserID and CustomerID
            $Param{CustomerUserListCount} = 0;
            for my $KeyCustomerUser ( sort keys %CustomerUserList ) {
                $Param{CustomerUserListCount}++;
                $Param{CustomerUserListLast}     = $CustomerUserList{$KeyCustomerUser};
                $Param{CustomerUserListLastUser} = $KeyCustomerUser;
            }
            if ( $Param{CustomerUserListCount} == 1 ) {
                $Param{CustomerUserID} = $Param{CustomerUserListLastUser};
                my %CustomerUserData = $CustomerUserObject->CustomerUserDataGet(
                    User => $Param{CustomerUserListLastUser},
                );
                if ( $CustomerUserData{UserCustomerID} ) {
                    $Param{CustomerID} = $CustomerUserData{UserCustomerID};
                }

            }

            # if more the one customer user exists, show list
            # and clean CustomerID
            else {
                $Param{CustomerID}            = '';
                $Param{"CustomerUserOptions"} = \%CustomerUserList;
            }
            return $Self->Form(%Param);
        }

        # get customer user and customer id
        elsif ($ExpandCustomerName2) {
# ---
# Znuny-CustomerViewDynamicFields
# ---
            # Not needed to be changed, since the 'ExpandCustomerName2' function is not being used.
# ---
            my %CustomerUserData = $CustomerUserObject->CustomerUserDataGet(
                User => $CustomerUserOption,
            );
            my %CustomerUserList = $CustomerUserObject->CustomerSearch(
                UserLogin => $CustomerUserOption,
            );
            for my $KeyCustomerUser ( sort keys %CustomerUserList ) {
                $Param{CustomerUserID} = $KeyCustomerUser;
            }
            if ( $CustomerUserData{UserCustomerID} ) {
                $Param{CustomerID} = $CustomerUserData{UserCustomerID};
            }
            return $Self->Form(%Param);
        }

        my %Error;

        # check needed data
        if ( !$Param{CustomerUserID} ) {
            $Error{'CustomerUserIDInvalid'} = 'ServerError';
        }

# ---
# Znuny-CustomerViewDynamicFields
# ---
#         if (%Error) {
#             return $Self->Form( %Param, %Error );
#         }

        my %DynamicFieldValues;
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldConfigs} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # extract the dynamic field value form the web request
            $DynamicFieldValues{ $DynamicFieldConfig->{Name} } = $DynamicFieldBackendObject->EditFieldValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ParamObject        => $ParamObject,
                LayoutObject       => $LayoutObject,
            );
        }

        # convert dynamic field values into a structure for ACLs
        my %DynamicFieldACLParameters;
        DYNAMICFIELD:
        for my $DynamicField ( sort keys %DynamicFieldValues ) {
            next DYNAMICFIELD if !$DynamicField;
            next DYNAMICFIELD if !$DynamicFieldValues{$DynamicField};

            $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicField } = $DynamicFieldValues{$DynamicField};
        }
        $Param{DynamicField} = \%DynamicFieldACLParameters;

        my %DynamicFieldHTML;
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldConfigs} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $PossibleValuesFilter;

            my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ($IsACLReducible) {
                my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                );

                if ( IsHashRefWithData($PossibleValues) ) {

                    # convert possible values key => value to key => key for ACLs using a Hash slice
                    my %AclData = %{$PossibleValues};
                    @AclData{ keys %AclData } = keys %AclData;

                    # set possible values filter from ACLs
                    my $ACL = $TicketObject->TicketAcl(
                        %Param,
                        Action        => $Self->{Action},
                        TicketID      => $Self->{TicketID},
                        ReturnType    => 'Ticket',
                        ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data          => \%AclData,
                        UserID        => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $TicketObject->TicketAclData();

                        # convert filter key => key back to key => value
                        %{$PossibleValuesFilter} = map { $_ => $PossibleValues->{$_} }
                            keys %Filter;
                    }
                }
            }

            my $ValidationResult = $DynamicFieldBackendObject->EditFieldValueValidate(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $PossibleValuesFilter,
                ParamObject          => $ParamObject,
                Mandatory            =>
                    $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
            );

            if ( !IsHashRefWithData($ValidationResult) ) {
                return $LayoutObject->ErrorScreen(
                    Message => "Could validate field $DynamicFieldConfig->{Label}!",
                    Comment => 'Please contact the admin.',
                );
            }

            # propagate validation error to the error variable to be detected by the frontend
            if ( $ValidationResult->{ServerError} ) {
                $Error{ $DynamicFieldConfig->{Name} } = ' ServerError';
            }

            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $DynamicFieldBackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $PossibleValuesFilter,
                Mandatory            =>
                    $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                ServerError  => $ValidationResult->{ServerError}  || '',
                ErrorMessage => $ValidationResult->{ErrorMessage} || '',
                LayoutObject => $LayoutObject,
                ParamObject  => $ParamObject,
            );
        }

        if (%Error) {
            return $Self->Form(
                %Param,
                %Error,
                DynamicFieldHTML => \%DynamicFieldHTML,
            );
        }

        # set dynamic field values
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldConfigs} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Self->{TicketID},
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                UserID             => $Self->{UserID},
            );
        }
# ---

        # update customer user data
        if (
            $TicketObject->TicketCustomerSet(
                TicketID => $Self->{TicketID},
                No       => $Param{CustomerID},
                User     => $Param{CustomerUserID},
                UserID   => $Self->{UserID},
            )
            )
        {

            # redirect
            return $LayoutObject->PopupClose(
                URL => "Action=AgentTicketZoom;TicketID=$Self->{TicketID}",
            );
        }
        else {

            # error?!
            return $LayoutObject->ErrorScreen();
        }
    }

    # show form
    else {
# ---
# Znuny-CustomerViewDynamicFields
# ---
#         return $Self->Form(%Param);

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Self->{TicketID},
            UserID        => $Self->{UserID},
            DynamicFields => 1,
        );

        my %DynamicFieldHTML;
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldConfigs} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $PossibleValuesFilter;

            my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ($IsACLReducible) {
                my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                );

                # check if field has PossibleValues property in its configuration
                if ( IsHashRefWithData($PossibleValues) ) {

                    # convert possible values key => value to key => key for ACLs using a Hash slice
                    my %AclData = %{$PossibleValues};
                    @AclData{ keys %AclData } = keys %AclData;

                    # set possible values filter from ACLs
                    my $ACL = $TicketObject->TicketAcl(
                        %Param,
                        Action        => $Self->{Action},
                        TicketID      => $Self->{TicketID},
                        ReturnType    => 'Ticket',
                        ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data          => \%AclData,
                        UserID        => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $TicketObject->TicketAclData();

                        # convert filter key => key back to key => value
                        %{$PossibleValuesFilter} = map { $_ => $PossibleValues->{$_} }
                            keys %Filter;
                    }
                }
            }

            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $DynamicFieldBackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $PossibleValuesFilter,
                Value                => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                Mandatory            =>
                    $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                LayoutObject => $LayoutObject,
                ParamObject  => $ParamObject,
            );
        }

        return $Self->Form(
            %Param,
            DynamicFieldHTML => \%DynamicFieldHTML,
        );
# ---
    }
}

sub Form {
    my ( $Self, %Param ) = @_;

    my $Output;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # print header
    $Output .= $LayoutObject->Header(
        Type => 'Small',
    );
    my $TicketCustomerID = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'CustomerID' ) || '';

    # print change form if ticket id is given
    my %CustomerUserData = ();
    if ( $Self->{TicketID} ) {

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # set JS data
        $LayoutObject->AddJSData(
            Key   => 'CustomerSearch',
            Value => {
                ShowCustomerTickets => $ConfigObject->Get('Ticket::Frontend::ShowCustomerTickets'),
            },
        );

        # get ticket data
        my %TicketData = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet( TicketID => $Self->{TicketID} );
        if ( $TicketData{CustomerUserID} || $Param{CustomerUserID} ) {
            %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
                User => $Param{CustomerUserID} || $TicketData{CustomerUserID},
            );
        }

        if ( $CustomerUserData{UserTitle} ) {
            $CustomerUserData{UserTitle} = $LayoutObject->{LanguageObject}->Translate( $CustomerUserData{UserTitle} );
        }

        $TicketCustomerID = $TicketData{CustomerID};
        $Param{SelectedCustomerUser} = $TicketData{CustomerUserID};

        $Param{Table} = $LayoutObject->AgentCustomerViewTable(
            Data   => \%CustomerUserData,
            Ticket => \%TicketData,
            Max    => $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
        );

        # show customer field as "FirstName Lastname" <MailAddress>
        if (%CustomerUserData) {
            $TicketData{CustomerUserID} = "\"$CustomerUserData{UserFullname} " . " <$CustomerUserData{UserEmail}>";
        }
        $LayoutObject->Block(
            Name => 'Customer',
            Data => { %TicketData, %Param, },
        );
    }
# ---
# Znuny-CustomerViewDynamicFields
# ---
    if ( scalar @{ $Self->{DynamicFieldConfigs} } >= 1) {
        $LayoutObject->Block(
            Name => 'ShowDynamicFields',
        );
    }

    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldConfigs} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # skip fields that HTML could not be retrieved
        next DYNAMICFIELD if !IsHashRefWithData(
            $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} }
        );

        # get the html strings form $Param
        my $DynamicFieldHTML = $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} };

        $LayoutObject->Block(
            Name => 'DynamicField',
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );

        $LayoutObject->Block(
            Name => 'DynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );
    }
# ---

    $Output
        .= $LayoutObject->Output(
        TemplateFile => 'AgentTicketCustomer',
        Data         => \%Param
        );
    $Output .= $LayoutObject->Footer(
        Type => 'Small',
    );
    return $Output;
}

1;
